import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_charge.dart';
import 'package:praticos/repositories/tenant/tenant_customer_repository.dart';
import 'package:praticos/screens/payments/asaas_error_text.dart';
import 'package:praticos/services/asaas_api_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/utils/currency_input.dart';
import 'package:praticos/utils/order_payment_math.dart';
import 'package:praticos/utils/tax_id.dart';
import 'package:praticos/widgets/tax_id_form_field.dart';

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

  void _pickInstallments() {
    final value = parseCurrencyInput(_valueController.text);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(sheetContext.l10n.chargeInstallments),
        actions: [
          for (var count = _minInstallments; count <= _maxInstallments; count++)
            CupertinoActionSheetAction(
              onPressed: () {
                setState(() => _installmentCount = count);
                Navigator.pop(sheetContext);
              },
              child: Text(sheetContext.l10n.chargeInstallmentOption(
                count,
                _formatService.formatBrl(value / count),
              )),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: Text(sheetContext.l10n.cancel),
        ),
      ),
    );
  }

  void _pickDueDate() {
    var selected = _dueDate;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) => Container(
        height: 300,
        color: CupertinoColors.systemBackground.resolveFrom(popupContext),
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final value = parseCurrencyInput(_valueController.text);

    return CupertinoPageScaffold(
      backgroundColor:
          CupertinoColors.systemGroupedBackground.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.createChargeTitle),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              header: Text(l10n.chargeValue.toUpperCase()),
              footer: Text(l10n.chargeBalanceHint(
                  _formatService.formatBrl(widget.remainingBalance))),
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: CupertinoTextField(
                    key: const Key('chargeValueField'),
                    controller: _valueController,
                    enabled: !_submitting,
                    keyboardType: TextInputType.number,
                    inputFormatters: [_brlFormatter],
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6.resolveFrom(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              footer: Text(_mode == ChargeMode.single
                  ? l10n.chargeSingleHint
                  : l10n.chargeInstallmentsHint),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: CupertinoSlidingSegmentedControl<ChargeMode>(
                      groupValue: _mode,
                      onValueChanged: (mode) {
                        if (mode != null && !_submitting) {
                          setState(() => _mode = mode);
                        }
                      },
                      children: {
                        ChargeMode.single: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(l10n.chargeModeSingle),
                        ),
                        ChargeMode.cardInstallments: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(l10n.chargeModeInstallments),
                        ),
                      },
                    ),
                  ),
                ),
                if (_mode == ChargeMode.cardInstallments)
                  CupertinoListTile(
                    key: const Key('chargeInstallmentsTile'),
                    title: Text(l10n.chargeInstallments),
                    additionalInfo: Text(l10n.chargeInstallmentOption(
                      _installmentCount,
                      _formatService.formatBrl(value / _installmentCount),
                    )),
                    trailing: const CupertinoListTileChevron(),
                    onTap: _submitting ? null : _pickInstallments,
                  ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              children: [
                CupertinoListTile(
                  key: const Key('chargeDueDateTile'),
                  title: Text(l10n.chargeDueDate),
                  additionalInfo: Text(_formatService.formatDate(_dueDate)),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _submitting ? null : _pickDueDate,
                ),
              ],
            ),
            if (_needsTaxId)
              CupertinoListSection.insetGrouped(
                footer: Text(l10n.chargeTaxIdHint),
                children: [
                  TaxIdFormField(
                    key: const Key('chargeTaxIdField'),
                    required: true,
                    onChanged: (id) => _taxIdInput = id,
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  key: const Key('generateChargeButton'),
                  onPressed: (_submitting || _loadingTaxId) ? null : _submit,
                  child: _submitting
                      ? const CupertinoActivityIndicator(
                          color: CupertinoColors.white)
                      : Text(l10n.chargeGenerate),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
