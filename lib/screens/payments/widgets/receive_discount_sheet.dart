import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
import 'package:praticos/screens/widgets/money_field.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Opens the discount sheet. Returns the discount to give, or null when the
/// user closes it.
Future<double?> showReceiveDiscountSheet(
  BuildContext context, {
  required double currentTotal,
  required double maxDiscount,
}) {
  return FormSheet.show<double>(
    context,
    (_) => ReceiveDiscountSheet(
      currentTotal: currentTotal,
      maxDiscount: maxDiscount,
    ),
  );
}

/// Sheet to give a discount: "X" and "✓" at the top (✓ gray until the amount
/// fits), the amount in a white card and the new total told under it.
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
  double _amount = 0;

  bool get _tooBig => _amount > widget.maxDiscount;
  bool get _valid => _amount > 0 && !_tooBig;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = FormatService();
    return FormSheet(
      key: const Key('receiveDiscountSheet'),
      title: l10n.receiveGiveDiscount,
      canSave: _valid,
      dirty: _amount > 0,
      onSave: () => Navigator.of(context).pop(_amount),
      children: [
        FormFieldsCard(
          children: [
            MoneyField(
              key: const Key('receiveDiscountField'),
              label: l10n.discount,
              autofocus: true,
              onChanged: (v) => setState(() => _amount = v),
            ),
          ],
        ),
        // Told only once there is an amount ("passa de X para X" says
        // nothing).
        if (_amount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.blockMargin + AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.blockMargin + AppSpacing.lg,
              0,
            ),
            child: Text(
              _tooBig
                  ? l10n.discountCannotExceedBalance
                  : l10n.receiveDiscountNewTotal(
                      format.formatCurrency(widget.currentTotal),
                      format.formatCurrency(widget.currentTotal - _amount),
                    ),
              key: const Key('receiveDiscountHint'),
              style: AppTypography.label.copyWith(
                color: _tooBig
                    ? AppColors.danger.resolveFrom(context)
                    : AppColors.textSecondary.resolveFrom(context),
              ),
            ),
          ),
      ],
    );
  }
}
