import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/payments/widgets/receive_amount_field.dart';
import 'package:praticos/screens/payments/widgets/receive_date_row.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/utils/currency_input.dart';

/// "Did the customer pay?" block of the Receber screen.
///
/// Three states: open (amount already filled with what is missing, receipt
/// link, one blue "Confirmar recebimento" button, off with 0), paid
/// ("Tudo recebido", no button) and blocked (quote/canceled order, [blockedMessage]).
/// The payment method is never asked here.
class ReceiveBlock extends StatelessWidget {
  const ReceiveBlock({
    super.key,
    required this.isPaid,
    required this.controller,
    required this.onConfirm,
    this.blockedMessage,
    this.busy = false,
    this.receiptName,
    this.onAttachReceipt,
    this.onRemoveReceipt,
    this.onAmountChanged,
    this.paidDay,
    this.onPickDay,
  });

  final bool isPaid;

  /// Non-null when the order does not accept payments (quote, canceled).
  final String? blockedMessage;

  /// Amount being received; pre-filled with the remaining balance.
  final TextEditingController controller;
  final VoidCallback onConfirm;
  final bool busy;

  /// File name of the receipt picked for the payment about to be saved.
  final String? receiptName;

  /// Null hides "Anexar comprovante" (no attach permission).
  final VoidCallback? onAttachReceipt;
  final VoidCallback? onRemoveReceipt;
  final ValueChanged<String>? onAmountChanged;

  /// Day the money came in ("Quando"); null hides the row.
  final DateTime? paidDay;
  final VoidCallback? onPickDay;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondary.resolveFrom(context);

    if (blockedMessage != null) {
      return _Card(
        background: AppColors.secondaryFill.resolveFrom(context),
        child: Text(
          blockedMessage!,
          key: const Key('receiveBlocked'),
          style: AppTypography.callout.copyWith(color: secondary),
        ),
      );
    }

    if (isPaid) {
      return _Card(
        background: AppColors.secondaryFill.resolveFrom(context),
        child: Row(
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

    final onSoft = AppColors.onAccentSoft.resolveFrom(context);
    return _Card(
      background: AppColors.accentSoft.resolveFrom(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.receiveMissing,
            style: AppTypography.label.copyWith(color: onSoft),
          ),
          const SizedBox(height: AppSpacing.xs),
          ReceiveAmountField(
            controller: controller,
            onChanged: onAmountChanged,
            semanticLabel: context.l10n.receiveMissing,
            enabled: !busy,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            context.l10n.receiveAmountHint,
            key: const Key('receiveAmountHint'),
            style: AppTypography.label.copyWith(color: onSoft),
          ),
          if (paidDay != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ReceiveDateRow(day: paidDay!, onTap: busy ? null : onPickDay),
          ],
          const SizedBox(height: AppSpacing.md),
          if (receiptName != null)
            ReceiptChip(name: receiptName!, onRemove: onRemoveReceipt)
          else if (onAttachReceipt != null)
            CupertinoButton(
              key: const Key('receiveAttachReceipt'),
              padding: EdgeInsets.zero,
              minimumSize: const Size(
                AppSizes.minTouchTarget,
                AppSizes.minTouchTarget,
              ),
              onPressed: onAttachReceipt,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.paperclip,
                    size: 20,
                    color: AppColors.accentText.resolveFrom(context),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      context.l10n.receiveAttachReceipt,
                      style: AppTypography.callout.copyWith(
                        color: AppColors.accentText.resolveFrom(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final amount = parseCurrencyInput(value.text);
              final label = context.l10n.receiveConfirmButton;
              return SizedBox(
                width: double.infinity,
                height: AppSizes.primaryButtonHeight,
                child: CupertinoButton(
                  key: const Key('receiveConfirm'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  color: AppColors.accent.resolveFrom(context),
                  disabledColor: AppColors.accent
                      .resolveFrom(context)
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadii.button),
                  onPressed: busy || amount <= 0 ? null : onConfirm,
                  child: busy
                      ? CupertinoActivityIndicator(
                          color: AppColors.onAccent.resolveFrom(context),
                        )
                      : Text(
                          label,
                          style: AppTypography.bodyStrong.copyWith(
                            color: AppColors.onAccent.resolveFrom(context),
                          ),
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, required this.background});

  final Widget child;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.blockMargin,
        vertical: AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.block),
      ),
      child: child,
    );
  }
}

/// Receipt picked but not saved yet: name and an "x" to take it out.
class ReceiptChip extends StatelessWidget {
  const ReceiptChip({super.key, required this.name, this.onRemove});

  final String name;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final onSoft = AppColors.onAccentSoft.resolveFrom(context);
    return Row(
      key: const Key('receiveReceiptChip'),
      children: [
        Icon(CupertinoIcons.paperclip, size: 20, color: onSoft),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            name,
            style: AppTypography.callout.copyWith(color: onSoft),
          ),
        ),
        CupertinoButton(
          key: const Key('receiveRemoveReceipt'),
          padding: EdgeInsets.zero,
          minimumSize: const Size(
            AppSizes.minTouchTarget,
            AppSizes.minTouchTarget,
          ),
          onPressed: onRemove,
          child: Semantics(
            label: context.l10n.receiveRemoveReceipt,
            child: Icon(
              CupertinoIcons.xmark_circle_fill,
              size: 22,
              color: onSoft,
            ),
          ),
        ),
      ],
    );
  }
}
