import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/order/new_order_form.dart';
import 'package:praticos/screens/payments/widgets/receipt_file_picker.dart';
import 'package:praticos/screens/payments/widgets/receive_amount_field.dart';
import 'package:praticos/screens/payments/widgets/receive_date_row.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
import 'package:praticos/services/customer_receipt_service.dart'
    show PickedReceiptFile;
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/utils/currency_input.dart';

/// What was filled in [ReceivePaymentSheet]. The screen saves it; after a
/// failure it passes the draft back so nothing is typed twice.
class ReceiveDraft {
  const ReceiveDraft({
    required this.amount,
    required this.paidDay,
    this.receipt,
  });

  final double amount;
  final DateTime paidDay;
  final PickedReceiptFile? receipt;
}

/// "Recebido de João": how much, when and the receipt of a payment that
/// already happened. Starts with [max] (or [initial]), never takes more, and
/// says under the field what the amount does ([preview]). Pops with a
/// [ReceiveDraft]; saving is up to the screen.
class ReceivePaymentSheet extends StatefulWidget {
  const ReceivePaymentSheet({
    super.key,
    required this.title,
    required this.max,
    required this.preview,
    this.initial,
    this.canAttach = true,
    this.pickReceipt,
    this.note,
  });

  final String title;

  /// What is open on the orders being paid.
  final double max;

  /// Sentence for a valid amount; null shows the "só uma parte" hint.
  final String? Function(double amount) preview;
  final ReceiveDraft? initial;

  /// False hides "Comprovante" (no attach permission).
  final bool canAttach;

  /// Overrides the camera/gallery/files picker (tests).
  final Future<PickedReceiptFile?> Function(BuildContext context)? pickReceipt;

  /// Under the rows ("A cobrança aberta se ajusta sozinha…").
  final String? note;

  static Future<ReceiveDraft?> show(
    BuildContext context, {
    required String title,
    required double max,
    required String? Function(double amount) preview,
    ReceiveDraft? initial,
    bool canAttach = true,
    Future<PickedReceiptFile?> Function(BuildContext context)? pickReceipt,
    String? note,
  }) {
    return FormSheet.show<ReceiveDraft>(
      context,
      (_) => ReceivePaymentSheet(
        title: title,
        max: max,
        preview: preview,
        initial: initial,
        canAttach: canAttach,
        pickReceipt: pickReceipt,
        note: note,
      ),
    );
  }

  @override
  State<ReceivePaymentSheet> createState() => _ReceivePaymentSheetState();
}

class _ReceivePaymentSheetState extends State<ReceivePaymentSheet> {
  late final String _initialText = ReceiveAmountField.textFor(
    _startAmount(widget),
  );
  late final TextEditingController _amount = TextEditingController(
    text: _initialText,
  );
  final FocusNode _focus = FocusNode();
  late DateTime _paidDay = widget.initial?.paidDay ?? DateTime.now();
  late PickedReceiptFile? _receipt = widget.initial?.receipt;

  /// The saved amount no longer fits (the balance went down): back to [max].
  static double _startAmount(ReceivePaymentSheet sheet) {
    final amount = sheet.initial?.amount;
    return amount == null || amount > sheet.max ? sheet.max : amount;
  }

  @override
  void initState() {
    super.initState();
    _amount.addListener(_changed);
    _focus.addListener(_changed);
  }

  @override
  void dispose() {
    _amount.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  int _cents(double value) => (value * 100).round();

  Future<void> _pickDay() async {
    _focus.unfocus();
    final day = await pickPaymentDay(context, _paidDay);
    if (day != null && mounted) setState(() => _paidDay = day);
  }

  Future<void> _attach() async {
    _focus.unfocus();
    final picked = await (widget.pickReceipt ?? pickReceiptFile)(context);
    if (picked != null && mounted) setState(() => _receipt = picked);
  }

  void _save() {
    Navigator.of(context).pop(
      ReceiveDraft(
        amount: parseCurrencyInput(_amount.text),
        paidDay: _paidDay,
        receipt: _receipt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = FormatService().currencyFormat;
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final amount = parseCurrencyInput(_amount.text);
    final tooMuch = _cents(amount) > _cents(widget.max);
    final canSave = amount > 0 && !tooMuch;
    final preview = canSave
        ? widget.preview(amount) ?? l10n.receiveCustomerPartHint
        : null;

    return FormSheet(
      key: const Key('receivePaymentSheet'),
      title: widget.title,
      canSave: canSave,
      missingHint: tooMuch
          ? l10n.receiveCustomerTooMuchChosen(
              FormatService().formatCurrency(widget.max),
            )
          : l10n.receiveCustomerZero,
      dirty: _amount.text != _initialText || _receipt != null,
      onSave: _save,
      children: [
        FormFieldsCard(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.lg,
                0,
              ),
              child: Text(
                l10n.receiveCustomerAmountLabel,
                style: AppTypography.label.copyWith(color: secondary),
              ),
            ),
            Semantics(
              label: l10n.receiveCustomerAmountLabel,
              child: CupertinoTextField(
                key: const Key('receiveAmountField'),
                controller: _amount,
                focusNode: _focus,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  CurrencyTextInputFormatter.currency(
                    locale: format.locale,
                    symbol: format.currencySymbol,
                    decimalDigits: 2,
                  ),
                ],
                placeholder: ReceiveAmountField.textFor(0),
                placeholderStyle: AppTypography.title.copyWith(
                  color: secondary,
                  fontFeatures: AppTypography.tabular,
                ),
                clearButtonMode: OverlayVisibilityMode.editing,
                clearButtonSemanticLabel: l10n.clear,
                // The numeric keyboard has no return key.
                suffix: _focus.hasFocus
                    ? CupertinoButton(
                        key: const Key('receiveKeyboardDone'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        minimumSize: const Size(
                          AppSizes.minTouchTarget,
                          AppSizes.minTouchTarget,
                        ),
                        onPressed: _focus.unfocus,
                        child: Text(
                          l10n.ok,
                          style: AppTypography.bodyStrong.copyWith(
                            color: AppColors.accentText.resolveFrom(context),
                          ),
                        ),
                      )
                    : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                decoration: null,
                style: AppTypography.title.copyWith(
                  color: AppColors.text.resolveFrom(context),
                  fontFeatures: AppTypography.tabular,
                ),
                cursorColor: AppColors.accent.resolveFrom(context),
              ),
            ),
          ],
        ),
        if (preview != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.blockMargin + AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.blockMargin + AppSpacing.lg,
              0,
            ),
            child: Text(
              preview,
              key: const Key('receiveAmountHint'),
              style: AppTypography.label.copyWith(color: secondary),
            ),
          ),
        FormCard(
          note: widget.note,
          children: [
            FormRow(
              key: const Key('receiveDateRow'),
              icon: CupertinoIcons.calendar,
              title: l10n.receiveWhen,
              value: paymentDayLabel(l10n, _paidDay),
              onTap: _pickDay,
            ),
            if (_receipt != null)
              FormRow(
                key: const Key('receiveReceiptChip'),
                icon: CupertinoIcons.paperclip,
                title: l10n.receipt,
                subtitle: _receipt!.name,
                showChevron: false,
                trailing: CupertinoButton(
                  key: const Key('receiveRemoveReceipt'),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(
                    AppSizes.minTouchTarget,
                    AppSizes.minTouchTarget,
                  ),
                  onPressed: () => setState(() => _receipt = null),
                  child: Semantics(
                    label: l10n.receiveRemoveReceipt,
                    child: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      size: 22,
                      color: secondary,
                    ),
                  ),
                ),
              )
            else if (widget.canAttach)
              FormRow(
                key: const Key('receiveAttachReceipt'),
                icon: CupertinoIcons.paperclip,
                title: l10n.receipt,
                value: l10n.receiveAttach,
                onTap: _attach,
              ),
          ],
        ),
      ],
    );
  }
}
