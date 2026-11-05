import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_mask/easy_mask.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/fiscal_address.dart';
import 'package:praticos/models/nfse.dart';
import 'package:praticos/repositories/tenant/payment_settings_repository.dart';
import 'package:praticos/screens/order/new_order_form.dart' show FormRow;
import 'package:praticos/screens/widgets/app_form_field.dart';
import 'package:praticos/screens/widgets/picker_screen.dart';
import 'package:praticos/services/fiscal_lookup_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/utils/tax_id.dart';
import 'package:praticos/widgets/tax_id_form_field.dart';

/// Whether the customer screens show "Dados para nota" (the company has the
/// direct nota on, `settings/payments.nfseDirectEnabled`) and how the nota
/// goes out by itself (`settings/nfse.autoIssue`), which decides whether
/// the "Emitir nota sozinha" switch shows.
class CustomerInvoiceConfig {
  const CustomerInvoiceConfig({
    this.enabled = false,
    this.autoIssue = NfseDirectAutoIssue.never,
  });

  static const off = CustomerInvoiceConfig();

  final bool enabled;
  final NfseDirectAutoIssue autoIssue;

  /// The customer switch: only when the nota can go out by itself.
  bool get showAutoIssue =>
      enabled && autoIssue != NfseDirectAutoIssue.never;

  /// What the switch shows when the customer never touched it: off for
  /// "clientes escolhidos", on for "todas as OS".
  bool autoIssueOf(Customer customer) =>
      customer.autoIssueInvoice ?? autoIssue == NfseDirectAutoIssue.allOrders;
}

/// Reads [CustomerInvoiceConfig] for the current company. Anything that
/// fails (no company, rules deny `settings/nfse` to people without
/// financial access, no internet) reads as off / "Nunca".
Future<CustomerInvoiceConfig> loadCustomerInvoiceConfig({
  FirebaseFirestore? firestore,
}) async {
  final companyId = Global.companyAggr?.id;
  if (companyId == null) return CustomerInvoiceConfig.off;
  try {
    final payments = await PaymentSettingsRepository(
      firestore: firestore,
    ).watch(companyId).first.timeout(const Duration(seconds: 5));
    if (!payments.nfseDirectEnabled) return CustomerInvoiceConfig.off;
    var autoIssue = NfseDirectAutoIssue.never;
    try {
      final nfse = await (firestore ?? FirebaseFirestore.instance)
          .collection('companies')
          .doc(companyId)
          .collection('settings')
          .doc('nfse')
          .get()
          .timeout(const Duration(seconds: 5));
      autoIssue = NfseDirectAutoIssue.parse(nfse.data()?['autoIssue']);
    } catch (_) {}
    return CustomerInvoiceConfig(enabled: true, autoIssue: autoIssue);
  } catch (_) {
    return CustomerInvoiceConfig.off;
  }
}

/// The other customer that already has [taxId] (normalized), if any. A
/// CPF/CNPJ lives in one customer of the company (spec §4.5).
Customer? findCustomerWithTaxId(
  List<Customer> customers,
  String? taxId, {
  String? exceptId,
}) {
  final id = normalizeTaxId(taxId ?? '');
  if (id.isEmpty) return null;
  for (final c in customers) {
    if (c.id != null && c.id == exceptId) continue;
    if (normalizeTaxId(c.taxId ?? '') == id) return c;
  }
  return null;
}

/// Picker result for "Nenhum": the nota goes to the customer itself.
const String kNoInvoiceRecipient = '';

/// "Para quem vai a nota?": the other customers of the company, with
/// "Nenhum" first (the nota goes to [customer] itself) and the ✓ on the
/// current one. Returns the chosen customer, [kNoInvoiceRecipient] for
/// "Nenhum", or null when the user went back.
Future<Object?> pickInvoiceRecipient(
  BuildContext context, {
  required Customer customer,
  required List<Customer> customers,
}) {
  final l10n = context.l10n;
  final current = customer.invoiceRecipient?.id;
  final others = [
    for (final c in customers)
      if (c.id != null && c.id != customer.id) c,
  ];
  return pickOne<Object>(
    context,
    title: l10n.invoiceRecipientPickerTitle,
    subtitle: customer.name,
    previousTitle: customer.name,
    strongTitles: true,
    options: [
      PickerItem<Object>(
        key: const Key('invoiceRecipientNone'),
        value: kNoInvoiceRecipient,
        title: l10n.invoiceRecipientNone,
        selected: current == null,
      ),
      for (final c in others)
        PickerItem<Object>(
          key: Key('invoiceRecipient_${c.id}'),
          value: c,
          title: c.legalName?.trim().isNotEmpty == true
              ? c.legalName!
              : (c.name ?? ''),
          subtitle: [
            if (c.legalName?.trim().isNotEmpty == true &&
                c.legalName != c.name)
              c.name ?? '',
            if (c.taxId?.isNotEmpty ?? false) formatTaxId(c.taxId!),
          ].where((s) => s.isNotEmpty).join(' · '),
          selected: c.id == current,
        ),
    ],
  );
}

/// "Dados para nota" of a customer: CPF/CNPJ (a CNPJ fills the legal name
/// and the address from the Receita), legal name, address with CEP (the
/// CEP fills street, district and city), the nota's e-mail, "Nota fiscal
/// para" (only when filled) and "Emitir nota sozinha" (only when the nota
/// can go out by itself).
///
/// Edits [customer] only on save (the [Form]'s `onSaved`), except the
/// recipient and the switch, which apply right away. [onChanged] runs on
/// every edit (the form's "dirty"); [onTaxIdChanged] with the normalized
/// CPF/CNPJ.
class CustomerInvoiceFields extends StatefulWidget {
  const CustomerInvoiceFields({
    super.key,
    required this.customer,
    required this.config,
    this.lookup,
    this.loadCustomers,
    this.onChanged,
    this.onTaxIdChanged,
    this.initialTaxId,
  });

  final Customer customer;

  /// What the CPF/CNPJ field starts with; defaults to the customer's.
  final String? initialTaxId;
  final CustomerInvoiceConfig config;

  /// Defaults to [FiscalLookupService]. Test seam.
  final FiscalLookupService? lookup;

  /// The company's customers, for "Nota fiscal para". Without it the row
  /// does not open the picker.
  final Future<List<Customer>> Function()? loadCustomers;
  final VoidCallback? onChanged;
  final ValueChanged<String>? onTaxIdChanged;

  /// Something to show when the group opens: the customer has any of it.
  static bool hasData(Customer c) {
    bool filled(String? v) => v != null && v.trim().isNotEmpty;
    final a = c.fiscalAddress;
    return filled(c.taxId) ||
        filled(c.legalName) ||
        filled(c.invoiceEmail) ||
        c.invoiceRecipient != null ||
        (a != null && (filled(a.postalCode) || filled(a.street)));
  }

  @override
  State<CustomerInvoiceFields> createState() => _CustomerInvoiceFieldsState();
}

enum _Lookup { idle, busy, found, notFound }

class _CustomerInvoiceFieldsState extends State<CustomerInvoiceFields> {
  late final FiscalLookupService _lookup =
      widget.lookup ?? FiscalLookupService();

  late final _legalName = TextEditingController(
    text: widget.customer.legalName ?? '',
  );
  late final _postalCode = TextEditingController(
    text: _maskedPostalCode(widget.customer.fiscalAddress?.postalCode),
  );
  late final _street = TextEditingController(text: _address?.street ?? '');
  late final _number = TextEditingController(text: _address?.number ?? '');
  late final _complement = TextEditingController(
    text: _address?.complement ?? '',
  );
  late final _district = TextEditingController(text: _address?.district ?? '');
  late final _city = TextEditingController(text: _address?.cityName ?? '');
  late final _state = TextEditingController(text: _address?.state ?? '');
  late final _email = TextEditingController(
    text: widget.customer.invoiceEmail ?? '',
  );

  FiscalAddress? get _address => widget.customer.fiscalAddress;

  /// IBGE code of the city, from a lookup (or the saved address). Typing
  /// another city drops it.
  late String? _cityCode = _address?.cityCode;
  late String? _cityCodeName = _address?.cityName;

  /// Values the lookups wrote, by field: a later lookup may replace them,
  /// never what the person typed.
  final Map<TextEditingController, String> _filled = {};

  _Lookup _taxIdLookup = _Lookup.idle;
  _Lookup _postalCodeLookup = _Lookup.idle;
  String? _lookedUpCnpj;
  String? _lookedUpPostalCode;

  List<TextEditingController> get _controllers => [
    _legalName,
    _postalCode,
    _street,
    _number,
    _complement,
    _district,
    _city,
    _state,
    _email,
  ];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  static String _maskedPostalCode(String? digits) {
    if (digits == null || digits.length != 8) return digits ?? '';
    return '${digits.substring(0, 5)}-${digits.substring(5)}';
  }

  void _edited() {
    widget.onChanged?.call();
    if (mounted) setState(() {});
  }

  /// Writes [value] where the field is empty or still has what an earlier
  /// lookup wrote.
  void _fill(TextEditingController field, String? value) {
    if (value == null || value.isEmpty) return;
    final current = field.text.trim();
    if (current.isNotEmpty && current != _filled[field]) return;
    field.text = value;
    _filled[field] = value;
  }

  void _fillAddress(FiscalAddress a) {
    if (a.postalCode != null) {
      _fill(_postalCode, _maskedPostalCode(a.postalCode));
      _lookedUpPostalCode = a.postalCode;
    }
    _fill(_street, a.street);
    _fill(_number, a.number);
    _fill(_complement, a.complement);
    _fill(_district, a.district);
    if (a.cityName != null &&
        (_city.text.trim().isEmpty || _city.text.trim() == _filled[_city])) {
      _fill(_city, a.cityName);
      _cityCode = a.cityCode;
      _cityCodeName = a.cityName;
    }
    _fill(_state, a.state);
  }

  Future<void> _onTaxId(String taxId) async {
    widget.onTaxIdChanged?.call(taxId);
    widget.onChanged?.call();
    final isCnpj = taxId.length == 14 && isValidCnpj(taxId);
    if (!isCnpj) {
      if (_taxIdLookup != _Lookup.idle) {
        setState(() => _taxIdLookup = _Lookup.idle);
      }
      return;
    }
    if (taxId == _lookedUpCnpj) return;
    _lookedUpCnpj = taxId;
    setState(() => _taxIdLookup = _Lookup.busy);
    final info = await _lookup.lookupCnpj(taxId);
    if (!mounted || _lookedUpCnpj != taxId) return;
    setState(() {
      if (info == null) {
        _taxIdLookup = _Lookup.notFound;
        return;
      }
      _taxIdLookup = _Lookup.found;
      _fill(_legalName, info.legalName);
      _fillAddress(info.address);
      final email = info.email;
      final main = widget.customer.email?.trim() ?? '';
      if (email != null && email != main.toLowerCase()) _fill(_email, email);
    });
    widget.onChanged?.call();
  }

  Future<void> _onPostalCode(String text) async {
    _edited();
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) {
      if (_postalCodeLookup != _Lookup.idle) {
        setState(() => _postalCodeLookup = _Lookup.idle);
      }
      return;
    }
    if (digits == _lookedUpPostalCode) return;
    _lookedUpPostalCode = digits;
    setState(() => _postalCodeLookup = _Lookup.busy);
    final address = await _lookup.lookupPostalCode(digits);
    if (!mounted || _lookedUpPostalCode != digits) return;
    setState(() {
      if (address == null) {
        _postalCodeLookup = _Lookup.notFound;
        return;
      }
      _postalCodeLookup = _Lookup.idle;
      // A new CEP is another place: its street, district and city win
      // over what an earlier lookup (or nothing) wrote.
      _fill(_street, address.street);
      _fill(_district, address.district);
      _city.text = address.cityName ?? _city.text;
      _filled[_city] = _city.text;
      _cityCode = address.cityCode;
      _cityCodeName = address.cityName;
      _state.text = address.state ?? _state.text;
      _filled[_state] = _state.text;
    });
    widget.onChanged?.call();
  }

  void _save() {
    final c = widget.customer;
    String? text(TextEditingController t) {
      final v = t.text.trim();
      return v.isEmpty ? null : v;
    }

    c.legalName = text(_legalName);
    c.invoiceEmail = text(_email);
    final postalCode = _postalCode.text.replaceAll(RegExp(r'\D'), '');
    final city = text(_city);
    final address = FiscalAddress(
      postalCode: postalCode.isEmpty ? null : postalCode,
      street: text(_street),
      number: text(_number),
      complement: text(_complement),
      district: text(_district),
      cityName: city,
      cityCode: city != null && city == _cityCodeName ? _cityCode : null,
      state: text(_state)?.toUpperCase(),
    );
    final empty = address.toJson().values.every((v) => v == null);
    c.fiscalAddress = empty ? null : address;
  }

  Future<void> _pickRecipient() async {
    final load = widget.loadCustomers;
    if (load == null) return;
    List<Customer> customers;
    try {
      customers = await load();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final picked = await pickInvoiceRecipient(
      context,
      customer: widget.customer,
      customers: customers,
    );
    if (picked == null || !mounted) return;
    setState(() {
      widget.customer.invoiceRecipient = picked is Customer
          ? picked.toAggr()
          : null;
    });
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = widget.customer;
    final recipient = c.invoiceRecipient;
    final mainEmail = c.email?.trim() ?? '';
    return FormField<void>(
      onSaved: (_) => _save(),
      builder: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: TaxIdFormField(
              initialValue: widget.initialTaxId ?? c.taxId,
              onChanged: _onTaxId,
              onSaved: (v) => c.taxId = v,
            ),
          ),
          ?_lookupLine(
            key: const Key('invoiceTaxIdLookup'),
            state: _taxIdLookup,
            busy: l10n.invoiceTaxIdLooking,
            found: l10n.invoiceTaxIdFound,
            notFound: l10n.invoiceTaxIdNotFound,
          ),
          AppFormField(
            key: const Key('invoiceLegalName'),
            label: l10n.invoiceLegalName,
            controller: _legalName,
            placeholder: l10n.invoiceLegalNamePlaceholder,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => _edited(),
          ),
          AppFormField(
            key: const Key('invoicePostalCode'),
            label: l10n.invoicePostalCode,
            controller: _postalCode,
            placeholder: l10n.invoicePostalCodePlaceholder,
            keyboardType: TextInputType.number,
            inputFormatters: [TextInputMask(mask: '99999-999')],
            onChanged: _onPostalCode,
          ),
          ?_lookupLine(
            key: const Key('invoicePostalCodeLookup'),
            state: _postalCodeLookup,
            busy: l10n.invoicePostalCodeLooking,
            found: null,
            notFound: l10n.invoicePostalCodeNotFound,
          ),
          AppFormField(
            key: const Key('invoiceStreet'),
            label: l10n.invoiceStreet,
            controller: _street,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => _edited(),
          ),
          AppFormField(
            key: const Key('invoiceNumber'),
            label: l10n.invoiceNumber,
            controller: _number,
            keyboardType: TextInputType.text,
            onChanged: (_) => _edited(),
          ),
          AppFormField(
            key: const Key('invoiceComplement'),
            label: l10n.invoiceComplement,
            controller: _complement,
            placeholder: l10n.optional,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => _edited(),
          ),
          AppFormField(
            key: const Key('invoiceDistrict'),
            label: l10n.invoiceDistrict,
            controller: _district,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => _edited(),
          ),
          AppFormField(
            key: const Key('invoiceCity'),
            label: l10n.invoiceCity,
            controller: _city,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => _edited(),
          ),
          AppFormField(
            key: const Key('invoiceState'),
            label: l10n.invoiceState,
            controller: _state,
            placeholder: l10n.invoiceStatePlaceholder,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [LengthLimitingTextInputFormatter(2)],
            onChanged: (_) => _edited(),
          ),
          AppFormField(
            key: const Key('invoiceEmail'),
            label: l10n.invoiceEmailLabel,
            controller: _email,
            placeholder: mainEmail.isEmpty ? l10n.emailPlaceholder : mainEmail,
            hint: mainEmail.isEmpty ? null : l10n.invoiceEmailFallback,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => _edited(),
          ),
          if (recipient != null)
            FormRow(
              key: const Key('invoiceRecipientRow'),
              title: l10n.invoiceRecipientLabel,
              value: recipient.name,
              onTap: widget.loadCustomers == null ? null : _pickRecipient,
            ),
          if (widget.config.showAutoIssue)
            FormRow(
              key: const Key('invoiceAutoIssueRow'),
              title: l10n.invoiceAutoIssue,
              subtitle: l10n.invoiceAutoIssueHint,
              showChevron: false,
              trailing: CupertinoSwitch(
                key: const Key('invoiceAutoIssueSwitch'),
                value: widget.config.autoIssueOf(c),
                onChanged: (on) {
                  setState(() => c.autoIssueInvoice = on);
                  widget.onChanged?.call();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget? _lookupLine({
    required Key key,
    required _Lookup state,
    required String busy,
    required String? found,
    required String notFound,
  }) {
    final text = switch (state) {
      _Lookup.idle => null,
      _Lookup.busy => busy,
      _Lookup.found => found,
      _Lookup.notFound => notFound,
    };
    if (text == null) return null;
    final secondary = AppColors.textSecondary.resolveFrom(context);
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageMargin,
        0,
        AppSpacing.pageMargin,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state == _Lookup.busy)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.sm),
              child: CupertinoActivityIndicator(),
            ),
          Expanded(
            child: Text(
              text,
              style: AppTypography.label.copyWith(color: secondary),
            ),
          ),
        ],
      ),
    );
  }
}
