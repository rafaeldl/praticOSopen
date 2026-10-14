import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_charge.dart';
import 'package:praticos/repositories/tenant/tenant_customer_repository.dart';
import 'package:praticos/screens/order/new_order_form.dart';
import 'package:praticos/screens/payments/asaas_error_text.dart';
import 'package:praticos/screens/widgets/app_form_field.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
import 'package:praticos/screens/widgets/picker_screen.dart';
import 'package:praticos/services/asaas_api_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/utils/currency_input.dart';
import 'package:praticos/utils/order_payment_math.dart';
import 'package:praticos/utils/tax_id.dart';

enum ChargeFormError {
  customerRequired,
  valueRequired,
  valueExceedsBalance,
  taxIdRequired,
  taxIdInvalid,
}

/// Client-side checks before calling the API. The server validates again.
ChargeFormError? validateChargeInput({
  required bool hasCustomer,
  required double value,
  required double remainingBalance,
  required bool needsTaxId,
  required String taxIdInput,
}) {
  if (!hasCustomer) return ChargeFormError.customerRequired;
  if (value <= 0) return ChargeFormError.valueRequired;
  if (value > remainingBalance + OrderPaymentMath.centTolerance) {
    return ChargeFormError.valueExceedsBalance;
  }
  if (needsTaxId) {
    final id = normalizeTaxId(taxIdInput);
    if (id.isEmpty) return ChargeFormError.taxIdRequired;
    if (!isValidTaxId(id)) return ChargeFormError.taxIdInvalid;
  }
  return null;
}

/// Same texts as [validateTaxIdInput] for the tax id errors.
String chargeFormErrorText(AppLocalizations l10n, ChargeFormError error) {
  switch (error) {
    case ChargeFormError.customerRequired:
      return l10n.asaasErrorCustomerRequired;
    case ChargeFormError.valueRequired:
      return l10n.valueMustBeGreaterThanZero;
    case ChargeFormError.valueExceedsBalance:
      return l10n.asaasErrorExceedsBalance;
    case ChargeFormError.taxIdRequired:
      return l10n.asaasErrorTaxIdRequired;
    case ChargeFormError.taxIdInvalid:
      return l10n.invalidTaxId;
  }
}

/// Creates an Asaas charge for an order. Pops with the created [OrderCharge].
///
/// On any error the screen stays open and pops nothing. A NETWORK_ERROR does
/// not mean the charge was not created: the order's charge card watches
/// Firestore and shows it if the server got the request.
class CreateChargeScreen extends StatefulWidget {
  const CreateChargeScreen({
    super.key,
    required this.order,
    required this.remainingBalance,
    this.service,
    this.customerTaxIdLoader,
  });

  final Order order;
  final double remainingBalance;

  /// Test seam; defaults to [AsaasApiService.instance].
  final AsaasApiService? service;

  /// Test seam; defaults to reading `taxId` from the customer document.
  final Future<String?> Function()? customerTaxIdLoader;

  @override
  State<CreateChargeScreen> createState() => _CreateChargeScreenState();
}

class _CreateChargeScreenState extends State<CreateChargeScreen> {
  static const _minInstallments = 2;
  static const _maxInstallments = 12;

  final _formatService = FormatService();

  /// Asaas only charges in BRL, whatever the app locale.
  final _brlFormatter = CurrencyTextInputFormatter.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  late final TextEditingController _valueController;
  String _taxIdInput = '';

  ChargeMode _mode = ChargeMode.single;
  int _installmentCount = _minInstallments;
  late DateTime _dueDate;
  String? _knownTaxId;
  bool _loadingTaxId = false;
  bool _submitting = false;

  AsaasApiService get _service => widget.service ?? AsaasApiService.instance;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Also true for an old invalid tax id: the server would reject it.
  bool get _needsTaxId => !_loadingTaxId && !_hasValidTaxId(_knownTaxId);

  static bool _hasValidTaxId(String? taxId) =>
      (taxId ?? '').isNotEmpty && isValidTaxId(taxId!);

  @override
  void initState() {
    super.initState();
    final today = _today();
    _dueDate = DateTime(today.year, today.month, today.day + 3);
    _valueController = TextEditingController(
      text: widget.remainingBalance > 0
          ? _brlFormatter.formatDouble(widget.remainingBalance)
          : '',
    );
    _valueController.addListener(_onValueChanged);

    _knownTaxId = widget.order.customer?.taxId;
    if (!_hasValidTaxId(_knownTaxId) && widget.order.customer?.id != null) {
      _loadingTaxId = true;
      _loadCustomerTaxId();
    }
  }

  @override
  void dispose() {
    _valueController.removeListener(_onValueChanged);
    _valueController.dispose();
    super.dispose();
  }

  void _onValueChanged() => setState(() {});

  Future<void> _loadCustomerTaxId() async {
    String? taxId;
    try {
      final loader = widget.customerTaxIdLoader ?? _loadTaxIdFromCustomer;
      taxId = await loader();
    } catch (_) {
      taxId = null;
    }
    if (!mounted) return;
    setState(() {
      _knownTaxId = taxId;
      _loadingTaxId = false;
    });
  }

  /// Orders embed an older CustomerAggr without taxId; the customer document
  /// is the source of truth.
  Future<String?> _loadTaxIdFromCustomer() async {
    final companyId = widget.order.company?.id ?? Global.companyAggr?.id;
    final customerId = widget.order.customer?.id;
    if (companyId == null || customerId == null) return null;
    final customer =
        await TenantCustomerRepository().getSingle(companyId, customerId);
    return customer?.taxId;
  }

  Future<void> _submit() async {
    // Synchronous guard: no second request while one is in flight.
    if (_submitting) return;

    final value = parseCurrencyInput(_valueController.text);
    final error = validateChargeInput(
      hasCustomer: widget.order.customer?.id != null,
      value: value,
      remainingBalance: widget.remainingBalance,
      needsTaxId: _needsTaxId,
      taxIdInput: _taxIdInput,
    );
    if (error != null) {
      _showMessage(chargeFormErrorText(context.l10n, error));
      return;
    }
    final orderId = widget.order.id;
    if (orderId == null) {
      _showMessage(context.l10n.asaasErrorGeneric);
      return;
    }

    setState(() => _submitting = true);
    String? failure;
    try {
      final charge = await _service.createCharge(
        orderId,
        value: value,
        mode: _mode,
        installmentCount:
            _mode == ChargeMode.cardInstallments ? _installmentCount : null,
        dueDate: _dueDate,
        customerTaxId: _needsTaxId ? normalizeTaxId(_taxIdInput) : null,
      );
      if (!mounted) return;
      Navigator.pop(context, charge);
      return;
    } on AsaasApiException catch (e) {
      // NETWORK_ERROR → noInternetConnection. No fake result: the charge may
      // exist server-side and will show up in the order's charge card.
      if (mounted) failure = asaasErrorText(context.l10n, e);
    } catch (_) {
      if (mounted) failure = context.l10n.asaasErrorGeneric;
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    if (failure != null) _showMessage(failure);
  }

  /// "Escolher" screen for the card installments: "Não" (single charge,
  /// Pix/boleto/card) or 2x..12x on the card.
  Future<void> _pickInstallments() async {
    final l10n = context.l10n;
    final value = parseCurrencyInput(_valueController.text);
    final current =
        _mode == ChargeMode.single ? 1 : _installmentCount;
    final picked = await pickOne<int>(
      context,
      title: l10n.chargeSplitQuestion,
      selected: current,
      options: [
        PickerItem(
          key: const ValueKey('charge_split_none'),
          value: 1,
          title: l10n.chargeSplitNo,
          subtitle: l10n.chargeSingleHint,
        ),
        for (var count = _minInstallments; count <= _maxInstallments; count++)
          PickerItem(
            key: ValueKey('charge_split_$count'),
            value: count,
            title: l10n.chargeInstallmentOption(
              count,
              _formatService.formatBrl(value / count),
            ),
          ),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (picked == 1) {
        _mode = ChargeMode.single;
      } else {
        _mode = ChargeMode.cardInstallments;
        _installmentCount = picked;
      }
    });
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

  void _showMessage(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        content: Text(message),
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

  /// What still blocks the "✓" (null when the link can be created).
  ChargeFormError? _currentError() => validateChargeInput(
        hasCustomer: widget.order.customer?.id != null,
        value: parseCurrencyInput(_valueController.text),
        remainingBalance: widget.remainingBalance,
        needsTaxId: _needsTaxId,
        taxIdInput: _taxIdInput,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final value = parseCurrencyInput(_valueController.text);
    final error = _currentError();
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final name = widget.order.customer?.name;

    return FormSheet(
      key: const Key('createChargeSheet'),
      title: l10n.chargeLinkTitle,
      canSave: !_loadingTaxId && error == null,
      missingHint:
          _loadingTaxId || error == null ? null : chargeFormErrorText(l10n, error),
      dirty: _taxIdInput.isNotEmpty,
      busy: _submitting,
      onSave: _submit,
      children: [
        FormFieldsCard(
          children: [
            AppFormField(
              key: const Key('chargeValueField'),
              label: l10n.chargeValue,
              controller: _valueController,
              keyboardType: TextInputType.number,
              inputFormatters: [_brlFormatter],
              hint: l10n.chargeBalanceHint(
                _formatService.formatBrl(widget.remainingBalance),
              ),
            ),
            if (_needsTaxId)
              AppFormField(
                key: const Key('chargeTaxIdField'),
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
          note: (name ?? '').isEmpty
              ? l10n.chargeLinkIntroNoName
              : l10n.chargeLinkIntro(name!),
          children: [
            FormRow(
              key: const Key('chargeDueDateTile'),
              icon: CupertinoIcons.calendar,
              title: l10n.chargeDueDate,
              trailing: Text(
                _formatService.formatDate(_dueDate),
                style: AppTypography.body.copyWith(color: secondary),
              ),
              onTap: _submitting ? null : _pickDueDate,
            ),
            FormRow(
              key: const Key('chargeInstallmentsTile'),
              icon: CupertinoIcons.creditcard,
              title: l10n.chargeSplitOnCard,
              trailing: Text(
                _mode == ChargeMode.single
                    ? l10n.chargeSplitNo
                    : l10n.chargeInstallmentOption(
                        _installmentCount,
                        _formatService.formatBrl(value / _installmentCount),
                      ),
                style: AppTypography.body.copyWith(color: secondary),
              ),
              onTap: _submitting ? null : _pickInstallments,
            ),
          ],
        ),
      ],
    );
  }
}
