import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/fiscal_address.dart';
import 'package:praticos/models/nfse.dart' hide NfseDirectAutoIssue;
import 'package:praticos/services/customer_directory.dart';
import 'package:praticos/screens/nfse/direct/fiscal_emitter_screen.dart';
import 'package:praticos/screens/nfse/direct/nfse_direct_texts.dart';
import 'package:praticos/screens/order/new_order_form.dart';
import 'package:praticos/screens/widgets/app_form_field.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/picker_screen.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/fiscal_lookup_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/nfse_direct_api_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/utils/tax_id.dart';

/// "CNPJ 00.000.000/0001-00" or "CPF 000.000.000-00".
String nfseTaxIdLine(AppLocalizations l10n, String taxId) {
  final digits = normalizeTaxId(taxId);
  return digits.length == 11
      ? l10n.nfseDirectCpfLine(formatTaxId(digits))
      : l10n.nfseDirectCnpjLine(formatTaxId(digits));
}

/// Why an emitter cannot issue now, in plain words (server's
/// `emitterProblem`).
String nfseEmitterProblemText(AppLocalizations l10n, String problem) =>
    switch (problem) {
      'certificate' => l10n.nfseDirectProblemCertificate,
      'certificateExpired' => l10n.nfseDirectCertExpired,
      'notEnabledInCity' => l10n.nfseDirectProblemNotEnabled,
      'service' => l10n.nfseDirectProblemService,
      _ => l10n.nfseDirectProblemSetup,
    };

/// "Emitir nota fiscal" with the NFS-e direct (spec §4.6): one nota for one
/// order (or several orders of one customer), from top to bottom:
///
/// - "Emitir por": the emitter the server marked (last used for the
///   customer, else the default); tapping opens the picker when there is
///   more than one.
/// - "Para": the customer's "Nota fiscal para", else the customer itself;
///   tapping sends this nota to another customer (only this one). What the
///   recipient lacks (document, address, e-mail) is asked right there and
///   saved on that customer where it is empty.
/// - The value by today's rule, the description (open field, the edit is
///   only for this nota) and the MEI warning, which never blocks.
///
/// ✓ issues it: the government answers in about half a second, so the
/// sheet pops with the nota already issued (or `creating` when there was no
/// clear answer). A refusal opens what fixes it.
class NfseDirectIssueSheet extends StatefulWidget {
  const NfseDirectIssueSheet({
    super.key,
    required this.orderIds,
    this.service,
    this.loadCustomers,
    this.lookup,
    this.canSetUp,
  });

  final List<String> orderIds;

  /// Test seam; defaults to [NfseDirectApiService.instance].
  final NfseDirectApiService? service;

  /// Customers for "Para"; defaults to the company's directory.
  final Future<List<Customer>> Function()? loadCustomers;

  /// CEP lookup; defaults to [FiscalLookupService].
  final FiscalLookupService? lookup;

  /// Who may open the emitter's setup; defaults to "manages the company".
  final bool? canSetUp;

  static Future<NfseInvoice?> show(
    BuildContext context, {
    required List<String> orderIds,
    NfseDirectApiService? service,
    Future<List<Customer>> Function()? loadCustomers,
    FiscalLookupService? lookup,
    bool? canSetUp,
  }) => FormSheet.show<NfseInvoice>(
    context,
    (_) => NfseDirectIssueSheet(
      orderIds: orderIds,
      service: service,
      loadCustomers: loadCustomers,
      lookup: lookup,
      canSetUp: canSetUp,
    ),
  );

  @override
  State<NfseDirectIssueSheet> createState() => _NfseDirectIssueSheetState();
}

class _NfseDirectIssueSheetState extends State<NfseDirectIssueSheet> {
  final _format = FormatService();
  final _description = TextEditingController();
  final _taxId = TextEditingController();
  final _legalName = TextEditingController();
  final _email = TextEditingController();
  final _postalCode = TextEditingController();
  final _street = TextEditingController();
  final _number = TextEditingController();
  final _complement = TextEditingController();
  final _district = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  String? _cityCode;
  String? _cityCodeName;
  String? _lookedUpPostalCode;
  bool _lookingUpPostalCode = false;

  NfseDirectPreview? _preview;
  String? _loadError;
  bool _loading = false;
  bool _submitting = false;

  /// Changed in this sheet (null: what the server marked).
  String? _emitterId;
  String? _recipientCustomerId;
  bool _descriptionEdited = false;

  /// The government refused the recipient's data: every field shows, not
  /// only the missing ones.
  bool _askAll = false;

  NfseDirectApiService get _service =>
      widget.service ?? NfseDirectApiService.instance;

  late final FiscalLookupService _lookup =
      widget.lookup ?? FiscalLookupService();

  List<TextEditingController> get _recipientFields => [
    _taxId,
    _legalName,
    _email,
    _postalCode,
    _street,
    _number,
    _complement,
    _district,
    _city,
    _state,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _description.dispose();
    for (final field in _recipientFields) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loadError = null;
      _loading = true;
    });
    try {
      final preview = await _service.previewInvoice(
        widget.orderIds,
        emitterId: _emitterId,
        recipientCustomerId: _recipientCustomerId,
      );
      if (!mounted) return;
      if (!_descriptionEdited) _description.text = preview.description;
      _fillRecipient(preview.recipient);
      setState(() {
        _preview = preview;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = nfseDirectErrorText(context.l10n, e);
      });
    }
  }

  /// What the recipient already has fills the fields that are empty.
  void _fillRecipient(NfseDirectPreviewRecipient r) {
    void fill(TextEditingController field, String? value) {
      if (field.text.trim().isEmpty && (value ?? '').isNotEmpty) {
        field.text = value!;
      }
    }

    if (r.taxId != null) fill(_taxId, formatTaxId(r.taxId!));
    fill(_legalName, r.legalName);
    fill(_email, r.email);
    final a = r.address;
    if (a != null) {
      fill(_postalCode, a.postalCode);
      fill(_street, a.street);
      fill(_number, a.number);
      fill(_complement, a.complement);
      fill(_district, a.district);
      if (_city.text.trim().isEmpty && (a.cityName ?? '').isNotEmpty) {
        _city.text = a.cityName!;
        _cityCode = a.cityCode;
        _cityCodeName = a.cityName;
      }
      fill(_state, a.state);
    }
  }

  bool _asked(NfseDirectPreview preview, String field) =>
      _askAll || preview.missing.contains(field);

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  String _text(TextEditingController field) => field.text.trim();

  bool get _addressComplete =>
      _text(_postalCode).replaceAll(RegExp(r'\D'), '').length == 8 &&
      _text(_street).isNotEmpty &&
      _text(_number).isNotEmpty &&
      _text(_district).isNotEmpty &&
      _text(_state).length == 2 &&
      _addressCityCode != null;

  /// IBGE code of the typed city: only while it is the city the CEP found.
  String? get _addressCityCode {
    final code = _cityCode;
    if (code == null || !RegExp(r'^\d{7}$').hasMatch(code)) return null;
    return _text(_city) == _cityCodeName ? code : null;
  }

  /// What still blocks the ✓, in plain words; null when it can go.
  String? _missing(NfseDirectPreview preview) {
    final l10n = context.l10n;
    if (preview.invoicedOrders.isNotEmpty) {
      final numbers = [
        for (final o in preview.orders)
          if (preview.invoicedOrders.containsKey(o.orderId))
            '${o.orderNumber ?? ''}',
      ].join(', ');
      return l10n.nfseAlreadyIssued(numbers);
    }
    if (preview.value <= 0) return l10n.nfseNothingToIssue;
    final problem = preview.emitter.problem;
    if (problem != null) {
      return l10n.nfseDirectIssueCannot(nfseEmitterProblemText(l10n, problem));
    }
    if (_asked(preview, 'taxId') &&
        !isValidTaxId(normalizeTaxId(_taxId.text))) {
      return l10n.nfseTaxIdMissing;
    }
    if (_asked(preview, 'address') && !_addressComplete) {
      return _text(_city).isNotEmpty && _addressCityCode == null
          ? l10n.nfseDirectIssueCityByPostalCode
          : l10n.nfseDirectIssueAddressMissing;
    }
    if (_asked(preview, 'email') && !_emailPattern.hasMatch(_text(_email))) {
      return l10n.nfseDirectIssueEmailMissing;
    }
    return null;
  }

  bool get _dirty =>
      _descriptionEdited ||
      _emitterId != null ||
      _recipientCustomerId != null ||
      _typedRecipient;

  bool get _typedRecipient {
    final r = _preview?.recipient;
    if (r == null) return false;
    String digits(String? v) => normalizeTaxId(v ?? '');
    return digits(_taxId.text) != digits(r.taxId) ||
        _text(_email) != (r.email ?? '') ||
        _text(_postalCode).replaceAll(RegExp(r'\D'), '') !=
            (r.address?.postalCode ?? '') ||
        _text(_street) != (r.address?.street ?? '');
  }

  Future<void> _onPostalCode(String text) async {
    setState(() {});
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8 || digits == _lookedUpPostalCode) return;
    _lookedUpPostalCode = digits;
    setState(() => _lookingUpPostalCode = true);
    final address = await _lookup.lookupPostalCode(digits);
    if (!mounted || _lookedUpPostalCode != digits) return;
    setState(() {
      _lookingUpPostalCode = false;
      if (address == null) return;
      if ((address.street ?? '').isNotEmpty) _street.text = address.street!;
      if ((address.district ?? '').isNotEmpty) {
        _district.text = address.district!;
      }
      _city.text = address.cityName ?? _city.text;
      _cityCode = address.cityCode;
      _cityCodeName = address.cityName;
      _state.text = address.state ?? _state.text;
    });
  }

  Future<void> _pickEmitter() async {
    final preview = _preview;
    if (preview == null || preview.emitters.length < 2) return;
    final l10n = context.l10n;
    final picked = await pickOne<String>(
      context,
      title: l10n.nfseDirectIssueEmitterQuestion,
      selected: preview.emitter.id,
      strongTitles: true,
      options: [
        for (final e in preview.emitters)
          PickerItem<String>(
            key: Key('nfseDirectEmitterOption_${e.id}'),
            value: e.id,
            title: e.legalName,
            subtitle: e.problem != null
                ? nfseEmitterProblemText(l10n, e.problem!)
                : _emitterLine(l10n, e),
          ),
      ],
    );
    if (picked == null || picked == preview.emitter.id || !mounted) return;
    _emitterId = picked;
    await _load();
  }

  Future<List<Customer>> _customers() {
    final load =
        widget.loadCustomers ??
        () => FirestoreCustomerDirectory().watchCustomers().first.timeout(
          const Duration(seconds: 5),
        );
    return load();
  }

  Future<void> _pickRecipient() async {
    final preview = _preview;
    if (preview == null) return;
    final l10n = context.l10n;
    List<Customer> customers;
    try {
      customers = await _customers();
    } catch (_) {
      if (mounted) await _alert(l10n.nfseDirectErrorUnavailable);
      return;
    }
    if (!mounted) return;
    final picked = await pickOne<String>(
      context,
      title: l10n.nfseDirectIssueRecipientQuestion,
      subtitle: l10n.nfseDirectIssueRecipientOnlyThis,
      selected: preview.recipient.customerId,
      strongTitles: true,
      options: [
        for (final c in customers)
          if (c.id != null)
            PickerItem<String>(
              key: Key('nfseDirectRecipientOption_${c.id}'),
              value: c.id!,
              title: c.legalName?.trim().isNotEmpty == true
                  ? c.legalName!
                  : (c.name ?? ''),
              subtitle: [
                if (c.legalName?.trim().isNotEmpty == true &&
                    c.legalName != c.name)
                  c.name ?? '',
                if (c.taxId?.isNotEmpty ?? false) nfseTaxIdLine(l10n, c.taxId!),
              ].where((s) => s.isNotEmpty).join(' · '),
            ),
      ],
    );
    if (picked == null || picked == preview.recipient.customerId || !mounted) {
      return;
    }
    // Another customer: its own data, not what was typed for the other one.
    for (final field in _recipientFields) {
      field.clear();
    }
    _cityCode = null;
    _cityCodeName = null;
    _lookedUpPostalCode = null;
    _askAll = false;
    _recipientCustomerId = picked;
    await _load();
  }

  String? _nonEmpty(TextEditingController field) {
    final value = _text(field);
    return value.isEmpty ? null : value;
  }

  Future<void> _submit() async {
    final preview = _preview;
    if (_submitting || preview == null || _missing(preview) != null) return;
    setState(() => _submitting = true);
    final askTaxId = _asked(preview, 'taxId');
    final askAddress = _asked(preview, 'address');
    final askEmail = _asked(preview, 'email');
    final description = _description.text.trim();
    try {
      final invoice = await _service.issueInvoice(
        widget.orderIds,
        emitterId: _emitterId ?? preview.emitter.id,
        description: _descriptionEdited && description.isNotEmpty
            ? description
            : null,
        recipientCustomerId: _recipientCustomerId,
        taxId: askTaxId ? normalizeTaxId(_taxId.text) : null,
        legalName: askTaxId ? _nonEmpty(_legalName) : null,
        email: askEmail ? _nonEmpty(_email) : null,
        address: askAddress
            ? FiscalAddress(
                postalCode: _text(_postalCode).replaceAll(RegExp(r'\D'), ''),
                street: _text(_street),
                number: _text(_number),
                complement: _nonEmpty(_complement),
                district: _text(_district),
                cityCode: _addressCityCode,
                cityName: _text(_city),
                state: _text(_state).toUpperCase(),
              )
            : null,
      );
      if (!mounted) return;
      Navigator.pop(context, invoice);
    } on NfseDirectApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      await _showError(e);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      await _alert(nfseDirectErrorText(context.l10n, e));
    }
  }

  /// Opens what fixes the refusal: the recipient's fields, the emitter, or
  /// just the sentence.
  Future<void> _showError(NfseDirectApiException e) async {
    final l10n = context.l10n;
    final refusal = e.refusal;
    if (e.code != 'NFSE_REFUSED' || refusal == null) {
      if (e.code == 'RECIPIENT_TAX_ID_REQUIRED') setState(() => _askAll = true);
      await _alert(nfseDirectErrorText(l10n, e));
      return;
    }
    final text =
        refusal.text(Localizations.localeOf(context).languageCode) ??
        l10n.nfseDirectRefusedGeneric;
    switch (refusal.group) {
      case NfseRefusalGroup.customerData:
        setState(() => _askAll = true);
        await _alert('$text\n\n${l10n.nfseDirectRefusedFixRecipient}');
      case NfseRefusalGroup.emitterSetup:
      case NfseRefusalGroup.certificate:
        final admin =
            widget.canSetUp ?? AuthorizationService.instance.canManageCompany;
        final open = await _alert(
          admin ? text : '$text\n\n${l10n.nfseNotReadyOther}',
          action: admin ? l10n.nfseSetupAction : null,
        );
        final emitterId = _preview?.emitter.id;
        if (open != true || !mounted || emitterId == null) return;
        await Navigator.of(context, rootNavigator: true).push<void>(
          CupertinoPageRoute<void>(
            builder: (_) => FiscalEmitterScreen(emitterId: emitterId),
          ),
        );
        if (mounted) await _load();
      case NfseRefusalGroup.other:
        await _alert(text);
    }
  }

  /// Alert with OK, or Cancel + [action] (true when [action] was tapped).
  Future<bool?> _alert(String text, {String? action}) =>
      showCupertinoDialog<bool>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          content: Text(text, key: const Key('nfseDirectIssueAlert')),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: action == null,
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                action == null
                    ? dialogContext.l10n.ok
                    : dialogContext.l10n.cancel,
              ),
            ),
            if (action != null)
              CupertinoDialogAction(
                key: const Key('nfseDirectIssueAlertAction'),
                isDefaultAction: true,
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(action),
              ),
          ],
        ),
      );

  String _emitterLine(AppLocalizations l10n, NfseDirectEmitterOption e) => [
    e.isMei ? l10n.nfseDirectRegimeMei : l10n.nfseDirectRegimeSimples,
    nfseTaxIdLine(l10n, e.taxId),
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final preview = _preview;
    final missing = preview == null ? null : _missing(preview);
    return FormSheet(
      key: const Key('nfseDirectIssueSheet'),
      title: l10n.nfseRowTitle,
      canSave: preview != null && !_loading && missing == null,
      missingHint: missing,
      dirty: _dirty,
      busy: _submitting,
      busyText: context.l10n.nfseIssuingProgress,
      onSave: _submit,
      children: preview == null
          ? [
              if (_loadError != null)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.pageMargin),
                  child: Column(
                    children: [
                      Text(
                        _loadError!,
                        key: const Key('nfseDirectIssueLoadError'),
                        textAlign: TextAlign.center,
                        style: AppTypography.body.copyWith(
                          color: AppColors.text.resolveFrom(context),
                        ),
                      ),
                      CupertinoButton(
                        onPressed: _load,
                        child: Text(l10n.tryAgain),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox(height: 200, child: LoadingState()),
            ]
          : _buildPreview(preview),
    );
  }

  List<Widget> _buildPreview(NfseDirectPreview preview) {
    final l10n = context.l10n;
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final emitter = preview.emitter;
    final recipient = preview.recipient;
    final several = preview.emitters.length > 1;
    final recipientName =
        recipient.legalName ?? recipient.name ?? l10n.customerWithoutName;
    final recipientLines = [
      if (recipient.taxId != null) nfseTaxIdLine(l10n, recipient.taxId!),
      if (recipient.viaInvoiceRecipient)
        l10n.nfseDirectIssueViaRecipient(
          preview.customerName ?? l10n.customerWithoutName,
        ),
    ];
    return [
      FormCard(
        children: [
          FormRow(
            key: const Key('nfseDirectIssueEmitter'),
            title: l10n.nfseDirectIssueBy,
            subtitle: [
              emitter.legalName,
              if (emitter.problem != null)
                nfseEmitterProblemText(l10n, emitter.problem!)
              else
                _emitterLine(l10n, emitter),
            ].join('\n'),
            showChevron: several,
            onTap: several && !_submitting ? _pickEmitter : null,
          ),
          FormRow(
            key: const Key('nfseDirectIssueRecipient'),
            title: l10n.nfseDirectIssueTo,
            subtitle: [recipientName, ...recipientLines].join('\n'),
            onTap: _submitting ? null : _pickRecipient,
          ),
        ],
      ),
      if (preview.meiWarning != NfseMeiWarning.none) _meiWarning(preview),
      ..._buildRecipientFields(preview, recipientName),
      _valueCard(preview),
      FormFieldsCard(
        children: [
          AppFormField(
            key: const Key('nfseDirectIssueDescription'),
            label: l10n.nfseDescriptionLabel,
            controller: _description,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() => _descriptionEdited = true),
          ),
        ],
      ),
      if (preview.complementaryInfo.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageMargin,
          ),
          child: Text(
            l10n.nfseDirectIssueComplementary(preview.complementaryInfo),
            key: const Key('nfseDirectIssueComplementary'),
            style: AppTypography.callout.copyWith(color: secondary),
          ),
        ),
      if (_emailLine(preview) case final line?)
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageMargin,
          ),
          child: Text(
            line,
            key: const Key('nfseDirectIssueEmailLine'),
            style: AppTypography.callout.copyWith(color: secondary),
          ),
        ),
    ];
  }

  /// Whether the nota goes to the customer's e-mail (issue #611). When the
  /// sheet asks for the e-mail, the field already says where it goes.
  String? _emailLine(NfseDirectPreview preview) {
    final l10n = context.l10n;
    if (!preview.emailToCustomer) return l10n.nfseDirectIssueEmailOff;
    final email = preview.recipient.email;
    if (_asked(preview, 'email') || email == null) return null;
    return l10n.nfseDirectIssueEmailGoesTo(email);
  }

  Widget _meiWarning(NfseDirectPreview preview) {
    final over = preview.meiWarning == NfseMeiWarning.over;
    final color = (over ? AppColors.danger : AppColors.warning).resolveFrom(
      context,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMargin),
      child: Row(
        key: const Key('nfseDirectIssueMeiWarning'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs + 2),
            child: StatusDot(color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              over
                  ? context.l10n.nfseDirectMeiOver
                  : context.l10n.nfseDirectMeiNear,
              style: AppTypography.callout.copyWith(
                color: AppColors.text.resolveFrom(context),
                fontWeight: over ? FontWeight.w600 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Document, address and e-mail the recipient lacks (all of them after
  /// the government refused its data). Saved on that customer where empty.
  List<Widget> _buildRecipientFields(
    NfseDirectPreview preview,
    String recipientName,
  ) {
    final askTaxId = _asked(preview, 'taxId');
    final askAddress = _asked(preview, 'address');
    final askEmail = _asked(preview, 'email');
    if (!askTaxId && !askAddress && !askEmail) return const [];
    final l10n = context.l10n;
    Widget field(
      String key,
      TextEditingController controller,
      String label, {
      String? placeholder,
      TextInputType? keyboard,
      TextCapitalization caps = TextCapitalization.words,
      ValueChanged<String>? onChanged,
    }) => AppFormField(
      key: Key('nfseDirectIssueField_$key'),
      label: label,
      controller: controller,
      placeholder: placeholder,
      keyboardType: keyboard,
      textCapitalization: caps,
      onChanged: onChanged ?? (_) => setState(() {}),
    );
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageMargin,
          AppSpacing.md,
          AppSpacing.pageMargin,
          0,
        ),
        child: Text(
          l10n.nfseDirectIssueRecipientDataIntro(recipientName),
          key: const Key('nfseDirectIssueRecipientIntro'),
          style: AppTypography.callout.copyWith(
            color: AppColors.textSecondary.resolveFrom(context),
          ),
        ),
      ),
      FormFieldsCard(
        children: [
          if (askTaxId) ...[
            field(
              'taxId',
              _taxId,
              l10n.cpfCnpj,
              keyboard: TextInputType.text,
              caps: TextCapitalization.characters,
            ),
            field(
              'legalName',
              _legalName,
              l10n.invoiceLegalName,
              placeholder: l10n.invoiceLegalNamePlaceholder,
              caps: TextCapitalization.characters,
            ),
          ],
          if (askAddress) ...[
            field(
              'postalCode',
              _postalCode,
              l10n.invoicePostalCode,
              placeholder: l10n.invoicePostalCodePlaceholder,
              keyboard: TextInputType.number,
              caps: TextCapitalization.none,
              onChanged: _onPostalCode,
            ),
            if (_lookingUpPostalCode)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  l10n.invoicePostalCodeLooking,
                  style: AppTypography.callout.copyWith(
                    color: AppColors.textSecondary.resolveFrom(context),
                  ),
                ),
              ),
            field('street', _street, l10n.invoiceStreet),
            field(
              'number',
              _number,
              l10n.invoiceNumber,
              caps: TextCapitalization.characters,
            ),
            field(
              'complement',
              _complement,
              l10n.invoiceComplement,
              caps: TextCapitalization.sentences,
            ),
            field('district', _district, l10n.invoiceDistrict),
            field('city', _city, l10n.invoiceCity),
            field(
              'state',
              _state,
              l10n.invoiceState,
              placeholder: l10n.invoiceStatePlaceholder,
              caps: TextCapitalization.characters,
            ),
          ],
          if (askEmail)
            field(
              'email',
              _email,
              l10n.invoiceEmailLabel,
              keyboard: TextInputType.emailAddress,
              caps: TextCapitalization.none,
            ),
        ],
      ),
    ];
  }

  Widget _valueCard(NfseDirectPreview preview) {
    final l10n = context.l10n;
    final several = preview.orders.length > 1;
    final hasDiscount = preview.orders.any((o) => o.discount > 0);
    final notes = [
      if (preview.hasProducts) l10n.nfseOnlyServicesNote,
      if (hasDiscount && preview.hasProducts) l10n.nfseDiscountNote,
    ];
    return FormCard(
      note: notes.isEmpty ? null : notes.join(' '),
      children: [
        ConstrainedBox(
          key: const Key('nfseDirectIssueValue'),
          constraints: const BoxConstraints(minHeight: 54),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: AppSpacing.md,
              children: [
                Text(
                  l10n.nfseValueLabel,
                  style: AppTypography.body.copyWith(
                    color: AppColors.text.resolveFrom(context),
                  ),
                ),
                Text(
                  _format.formatBrl(preview.value),
                  style: AppTypography.bodyStrong.copyWith(
                    color: AppColors.text.resolveFrom(context),
                    fontFeatures: AppTypography.tabular,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (several)
          for (final o in preview.orders)
            FormRow(
              title: l10n.nfseOrderLine(
                '${o.orderNumber ?? ''}',
                _format.formatBrl(o.value),
              ),
              showChevron: false,
            ),
      ],
    );
  }
}
