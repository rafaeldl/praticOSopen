import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/customer_charge.dart';
import 'package:praticos/repositories/tenant/tenant_customer_repository.dart';
import 'package:praticos/screens/order/new_order_form.dart';
import 'package:praticos/screens/payments/asaas_error_text.dart';
import 'package:praticos/screens/payments/create_charge_screen.dart'
    show ChargeFormError, chargeFormErrorText, validateChargeInput;
import 'package:praticos/screens/widgets/app_form_field.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
import 'package:praticos/services/asaas_api_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/utils/currency_input.dart';
import 'package:praticos/utils/payment_allocation.dart';
import 'package:praticos/utils/tax_id.dart';

/// "Mandar cobrança" from "Receber de João": one Asaas link for several
/// orders of the customer. Asaas has no line items, so the server stores how
/// much of the link goes to each order (oldest first) and cancels the open
/// links it replaces. Pops with the created [CustomerCharge].
///
/// One payment (Pix, boleto or card at sight): splitting on the card stays
/// in the single-order charge.
class CreateCustomerChargeScreen extends StatefulWidget {
  const CreateCustomerChargeScreen({
    super.key,
    required this.customer,
    required this.balances,
    required this.initialValue,
    this.service,
    this.customerTaxIdLoader,
  });

  final CustomerAggr customer;

  /// Orders the link covers, oldest first (the chosen ones).
  final List<OpenBalance> balances;

  final double initialValue;

  /// Test seam; defaults to [AsaasApiService.instance].
  final AsaasApiService? service;

  /// Test seam; defaults to reading `taxId` from the customer document.
  final Future<String?> Function()? customerTaxIdLoader;

  @override
  State<CreateCustomerChargeScreen> createState() =>
      _CreateCustomerChargeScreenState();
}

class _CreateCustomerChargeScreenState
    extends State<CreateCustomerChargeScreen> {
  final _format = FormatService();

  /// Asaas only charges in BRL, whatever the app locale.
  final _brl = CurrencyTextInputFormatter.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  late final TextEditingController _value;
  late DateTime _dueDate;
  late final double _owed = totalOpen(widget.balances);
  String _taxIdInput = '';
  String? _knownTaxId;
  bool _loadingTaxId = true;
  bool _submitting = false;

  AsaasApiService get _service => widget.service ?? AsaasApiService.instance;

  bool get _needsTaxId =>
      !_loadingTaxId &&
      !((_knownTaxId ?? '').isNotEmpty && isValidTaxId(_knownTaxId!));

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    final today = _today();
    _dueDate = DateTime(today.year, today.month, today.day + 3);
    final initial = widget.initialValue > 0 && widget.initialValue <= _owed
        ? widget.initialValue
        : _owed;
    _value = TextEditingController(text: _brl.formatDouble(initial))
      ..addListener(_changed);
    _loadTaxId();
  }

  @override
  void dispose() {
    _value.removeListener(_changed);
    _value.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  Future<void> _loadTaxId() async {
    String? taxId;
    try {
      taxId = await (widget.customerTaxIdLoader ?? _readTaxId)();
    } catch (_) {
      taxId = null;
    }
    if (!mounted) return;
    setState(() {
      _knownTaxId = taxId;
      _loadingTaxId = false;
    });
  }

  Future<String?> _readTaxId() async {
    final companyId = Global.companyAggr?.id;
    final customerId = widget.customer.id;
    if (companyId == null || customerId == null) return null;
    final customer = await TenantCustomerRepository().getSingle(
      companyId,
      customerId,
    );
    return customer?.taxId;
  }

  ChargeFormError? _error() => validateChargeInput(
    hasCustomer: widget.customer.id != null,
    value: parseCurrencyInput(_value.text),
    remainingBalance: _owed,
    needsTaxId: _needsTaxId,
    taxIdInput: _taxIdInput,
  );

  Future<void> _submit() async {
    if (_submitting || _error() != null) return;
    setState(() => _submitting = true);
    String failure;
    try {
      final charge = await _service.createCustomerCharge(
        widget.customer.id!,
        orderIds: [for (final b in widget.balances) b.orderId],
        value: parseCurrencyInput(_value.text),
        dueDate: _dueDate,
        customerTaxId: _needsTaxId ? normalizeTaxId(_taxIdInput) : null,
      );
      if (!mounted) return;
      Navigator.pop(context, charge);
      return;
    } on AsaasApiException catch (e) {
      // NETWORK_ERROR: the link may exist on the server; "Receber de João"
      // watches Firestore and shows it if it does.
      failure = asaasErrorText(context.l10n, e);
    } catch (_) {
      failure = context.l10n.asaasErrorGeneric;
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        content: Text(failure),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.l10n.ok),
          ),
        ],
      ),
    );
  }

  void _pickDueDate() {
    var selected = _dueDate;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) => Container(
        height: 300,
        color: AppColors.surface.resolveFrom(popupContext),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: CupertinoButton(
                  onPressed: () {
                    setState(() => _dueDate = selected);
                    Navigator.pop(popupContext);
                  },
                  child: Text(popupContext.l10n.confirm),
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _dueDate,
                  minimumDate: _today(),
                  onDateTimeChanged: (date) =>
                      selected = DateTime(date.year, date.month, date.day),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final error = _error();
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final name = (widget.customer.name ?? '').trim();
    final numbers = [
      for (final b in widget.balances) '${b.orderNumber ?? '?'}',
    ].join(', ');

    return FormSheet(
      key: const Key('createCustomerChargeSheet'),
      title: l10n.chargeLinkTitle,
      canSave: !_loadingTaxId && error == null,
      // An empty CPF/CNPJ is already explained by the field's own hint.
      missingHint:
          _loadingTaxId ||
              error == null ||
              error == ChargeFormError.taxIdRequired
          ? null
          : chargeFormErrorText(l10n, error),
      dirty: _taxIdInput.isNotEmpty,
      busy: _submitting,
      onSave: _submit,
      children: [
        FormFieldsCard(
          children: [
            AppFormField(
              key: const Key('customerChargeValueField'),
              label: l10n.chargeValue,
              controller: _value,
              keyboardType: TextInputType.number,
              inputFormatters: [_brl],
              hint: l10n.receiveCustomerChargeOwedHint(
                _format.formatBrl(_owed),
              ),
            ),
            if (_needsTaxId)
              AppFormField(
                key: const Key('customerChargeTaxIdField'),
                label: l10n.cpfCnpj,
                hint: l10n.chargeTaxIdHint,
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.characters,
                onChanged: (text) =>
                    setState(() => _taxIdInput = normalizeTaxId(text)),
              ),
          ],
        ),
        FormCard(
          note: l10n.receiveCustomerChargeIntro(
            name.isEmpty ? l10n.customerWithoutName : name,
            widget.balances.length,
            numbers,
          ),
          children: [
            FormRow(
              key: const Key('customerChargeDueDate'),
              icon: CupertinoIcons.calendar,
              title: l10n.chargeDueDate,
              trailing: Text(
                _format.formatDate(_dueDate),
                style: AppTypography.body.copyWith(color: secondary),
              ),
              onTap: _submitting ? null : _pickDueDate,
            ),
          ],
        ),
      ],
    );
  }
}
