import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/payments/widgets/receive_amount_field.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/utils/currency_input.dart';

/// Opens the discount sheet. Returns the discount to give, or null when the
/// user cancels.
Future<double?> showReceiveDiscountSheet(
  BuildContext context, {
  required double currentTotal,
  required double maxDiscount,
}) {
  return showCupertinoModalPopup<double>(
    context: context,
    builder: (_) => ReceiveDiscountSheet(
      currentTotal: currentTotal,
      maxDiscount: maxDiscount,
    ),
  );
}

/// Sheet to give a discount: "Cancelar" on the left, the new total told
/// before confirming, one blue button that follows the typed amount.
class ReceiveDiscountSheet extends StatefulWidget {
  const ReceiveDiscountSheet({
    super.key,
    required this.currentTotal,
    required this.maxDiscount,
  });

  final double currentTotal;

  /// Largest discount allowed (what is still missing to receive).
  final double maxDiscount;

  @override
  State<ReceiveDiscountSheet> createState() => _ReceiveDiscountSheetState();
}

class _ReceiveDiscountSheetState extends State<ReceiveDiscountSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final format = FormatService();
    final secondary = AppColors.textSecondary.resolveFrom(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        key: const Key('receiveDiscountSheet'),
        width: double.infinity,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface.resolveFrom(context),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadii.block),
          ),
        ),
        child: SafeArea(
          top: false,
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) {
              final amount = parseCurrencyInput(value.text);
              final valid = amount > 0 && amount <= widget.maxDiscount;
              final tooBig = amount > widget.maxDiscount;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CupertinoButton(
                        key: const Key('receiveDiscountCancel'),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(context.l10n.cancel),
                      ),
                      Expanded(
                        child: Text(
                          context.l10n.receiveGiveDiscount,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyStrong.copyWith(
                            color: AppColors.text.resolveFrom(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 80),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.pageMargin,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ReceiveAmountField(controller: _controller, autofocus: true),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          tooBig
                              ? context.l10n.discountCannotExceedBalance
                              : context.l10n.receiveDiscountNewTotal(
                                  format.formatCurrency(widget.currentTotal),
                                  format.formatCurrency(
                                      widget.currentTotal - amount),
                                ),
                          key: const Key('receiveDiscountHint'),
                          style: AppTypography.callout.copyWith(
                            color: tooBig
                                ? AppColors.danger.resolveFrom(context)
                                : secondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        SizedBox(
                          width: double.infinity,
                          height: AppSizes.primaryButtonHeight,
                          child: CupertinoButton(
                            key: const Key('receiveDiscountConfirm'),
                            padding: EdgeInsets.zero,
                            color: AppColors.accent.resolveFrom(context),
                            disabledColor: AppColors.accent
                                .resolveFrom(context)
                                .withValues(alpha: 0.5),
                            borderRadius:
                                BorderRadius.circular(AppRadii.button),
                            onPressed: valid
                                ? () => Navigator.of(context).pop(amount)
                                : null,
                            child: Text(
                              context.l10n.receiveDiscountButton(
                                format.formatCurrency(amount),
                              ),
                              style: AppTypography.bodyStrong.copyWith(
                                color: AppColors.onAccent.resolveFrom(context),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
