import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Top of the Receber screen when there is nothing to receive: "Tudo
/// recebido", or [blockedMessage] for a quote or canceled order.
class ReceiveBlock extends StatelessWidget {
  const ReceiveBlock({super.key, this.blockedMessage});

  /// Non-null when the order does not accept payments (quote, canceled).
  final String? blockedMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.blockMargin,
        vertical: AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.secondaryFill.resolveFrom(context),
        borderRadius: BorderRadius.circular(AppRadii.block),
      ),
      child: blockedMessage != null
          ? Text(
              blockedMessage!,
              key: const Key('receiveBlocked'),
              style: AppTypography.callout.copyWith(
                color: AppColors.textSecondary.resolveFrom(context),
              ),
            )
          : Row(
              key: const Key('receiveAllDone'),
              children: [
                const StatusDot(color: AppColors.success, size: 10),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    context.l10n.receiveAllDone,
                    style: AppTypography.highlight.copyWith(
                      color: AppColors.text.resolveFrom(context),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
