import 'package:flutter/cupertino.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Top of the Receber screens: who owes ("Elias"), how much of what
/// ("A receber · 6 OS") and the amount, the only money in large type.
class ReceiveSummary extends StatelessWidget {
  const ReceiveSummary({
    super.key,
    required this.title,
    required this.label,
    required this.amount,
    this.detail,
    this.titleKey,
  });

  final String title;
  final String label;
  final String amount;

  /// Small line under the amount ("total R$ 1.250 · desconto R$ 50").
  final String? detail;
  final Key? titleKey;

  @override
  Widget build(BuildContext context) {
    final text = AppColors.text.resolveFrom(context);
    final secondary = AppColors.textSecondary.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageMargin,
        AppSpacing.sm,
        AppSpacing.pageMargin,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              key: titleKey,
              style: AppTypography.title.copyWith(color: text),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            key: const Key('receiveSummaryLabel'),
            style: AppTypography.callout.copyWith(color: secondary),
          ),
          Text(
            amount,
            key: const Key('receiveSummaryAmount'),
            style: AppTypography.title.copyWith(
              color: text,
              fontFeatures: AppTypography.tabular,
            ),
          ),
          if (detail != null)
            Text(
              detail!,
              key: const Key('receiveSubtitle'),
              style: AppTypography.label.copyWith(
                color: secondary,
                fontFeatures: AppTypography.tabular,
              ),
            ),
        ],
      ),
    );
  }
}
