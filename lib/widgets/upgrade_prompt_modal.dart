import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';

/// Modal reutilizável para promover upgrade de plano
///
/// Exibe uma mensagem contextual sobre a feature limitada e oferece
/// opções para fazer upgrade ou dispensar.
class UpgradePromptModal extends StatelessWidget {
  /// Nome da feature que atingiu o limite
  final String featureName;

  /// Limite atual do plano (ex: "30 fotos/mês")
  final String currentLimit;

  /// Benefício do upgrade (ex: "200 fotos/mês")
  final String upgradeBenefit;

  /// Callback quando usuário clica em "Fazer upgrade"
  final VoidCallback onUpgrade;

  /// Callback quando usuário clica em "Talvez depois"
  final VoidCallback? onDismiss;

  const UpgradePromptModal({
    super.key,
    required this.featureName,
    required this.currentLimit,
    required this.upgradeBenefit,
    required this.onUpgrade,
    this.onDismiss,
  });

  /// Exibe o modal de upgrade
  static Future<void> show({
    required BuildContext context,
    required String featureName,
    required String currentLimit,
    required String upgradeBenefit,
    required VoidCallback onUpgrade,
    VoidCallback? onDismiss,
  }) {
    return showCupertinoModalPopup(
      context: context,
      builder: (ctx) => UpgradePromptModal(
        featureName: featureName,
        currentLimit: currentLimit,
        upgradeBenefit: upgradeBenefit,
        onUpgrade: () {
          Navigator.of(ctx).pop();
          onUpgrade();
        },
        onDismiss: () {
          Navigator.of(ctx).pop();
          onDismiss?.call();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return CupertinoActionSheet(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.lock_fill,
            color: CupertinoColors.systemOrange,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(l10n.upgradePlanTitle),
        ],
      ),
      message: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(
              l10n.featureLimitReached(featureName),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            _buildLimitComparison(context),
          ],
        ),
      ),
      actions: [
        CupertinoActionSheetAction(
          onPressed: onUpgrade,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.arrow_up_circle_fill,
                color: CupertinoColors.activeBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.upgradeNow,
                style: const TextStyle(
                  color: CupertinoColors.activeBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: onDismiss ?? () => Navigator.of(context).pop(),
        child: Text(l10n.maybeLater),
      ),
    );
  }

  Widget _buildLimitComparison(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      l10n.currentPlan,
                      style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentLimit,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.arrow_right,
                color: CupertinoColors.systemGreen,
                size: 20,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      l10n.withUpgrade,
                      style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      upgradeBenefit,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.systemGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
