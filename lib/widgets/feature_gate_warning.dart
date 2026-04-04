import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/subscription.dart';
import 'package:praticos/services/feature_gate_service.dart';

/// Banner de aviso exibido quando o usuário está próximo do limite (>= 80%).
///
/// Mostra um banner amarelo com ícone de alerta, quantidade restante,
/// e um botão opcional de upgrade.
///
/// Uso:
/// ```dart
/// FeatureGateWarning(
///   result: FeatureGateService.canAddPhoto(subscription),
///   onUpgrade: () => Navigator.pushNamed(context, '/plans'),
/// )
/// ```
class FeatureGateWarning extends StatelessWidget {
  /// Resultado da verificação do feature gate.
  final FeatureGateResult result;

  /// Callback quando o botão de upgrade é pressionado.
  /// Se null, o botão de upgrade não é exibido.
  final VoidCallback? onUpgrade;

  /// Se deve mostrar o banner mesmo quando não está próximo do limite.
  /// Por padrão, o widget é invisível se não está no limite.
  final bool alwaysShow;

  const FeatureGateWarning({
    super.key,
    required this.result,
    this.onUpgrade,
    this.alwaysShow = false,
  });

  @override
  Widget build(BuildContext context) {
    // Não mostra se não está próximo do limite (a menos que alwaysShow)
    if (!result.isNearLimit && !alwaysShow) {
      return const SizedBox.shrink();
    }

    // Não mostra se está no limite (deve usar FeatureGateLimitModal)
    if (result.isAtLimit) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final featureName = _getFeatureName(result.featureType, l10n);
    final remaining = result.remaining;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemYellow.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: CupertinoColors.systemYellow.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Ícone de alerta
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: CupertinoColors.systemYellow.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.exclamationmark_triangle_fill,
              color: CupertinoColors.systemOrange,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),

          // Texto de aviso
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _buildWarningTitle(remaining, featureName, l10n),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _buildWarningSubtitle(result, l10n),
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel.darkColor,
                  ),
                ),
              ],
            ),
          ),

          // Botão de upgrade (se callback fornecido)
          if (onUpgrade != null) ...[
            const SizedBox(width: 8),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: CupertinoColors.systemOrange,
              borderRadius: BorderRadius.circular(6),
              onPressed: onUpgrade,
              child: Text(
                l10n.upgrade,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getFeatureName(FeatureType type, dynamic l10n) {
    switch (type) {
      case FeatureType.photo:
        return l10n.photos;
      case FeatureType.formTemplate:
        return l10n.formTemplates;
      case FeatureType.collaborator:
        return l10n.collaborators;
    }
  }

  String _buildWarningTitle(int remaining, String featureName, dynamic l10n) {
    if (remaining <= 0) {
      return l10n.featureGateLimitReached(featureName);
    }
    return l10n.featureGateNearLimit(remaining, featureName);
  }

  String _buildWarningSubtitle(FeatureGateResult result, dynamic l10n) {
    final suggestedPlan = result.suggestedUpgrade;
    if (suggestedPlan != null) {
      final planName = _getPlanDisplayName(suggestedPlan);
      return l10n.featureGateUpgradeSuggestion(planName);
    }
    return l10n.featureGateUsageInfo(result.currentUsage, result.limit);
  }

  String _getPlanDisplayName(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return 'Free';
      case SubscriptionPlan.starter:
        return 'Starter';
      case SubscriptionPlan.pro:
        return 'Pro';
      case SubscriptionPlan.business:
        return 'Business';
    }
  }
}

/// Widget builder que exibe o warning apenas quando apropriado.
///
/// Uso:
/// ```dart
/// FeatureGateWarningBuilder(
///   result: () => FeatureGateService.canAddPhoto(subscription),
///   onUpgrade: () => Navigator.pushNamed(context, '/plans'),
///   child: PhotoGrid(),
/// )
/// ```
class FeatureGateWarningBuilder extends StatelessWidget {
  /// Função que retorna o resultado do feature gate.
  final FeatureGateResult Function() resultBuilder;

  /// Callback quando o botão de upgrade é pressionado.
  final VoidCallback? onUpgrade;

  /// Widget filho que sempre é exibido.
  final Widget child;

  /// Padding entre o warning e o child.
  final EdgeInsets? warningPadding;

  const FeatureGateWarningBuilder({
    super.key,
    required this.resultBuilder,
    this.onUpgrade,
    required this.child,
    this.warningPadding,
  });

  @override
  Widget build(BuildContext context) {
    final result = resultBuilder();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (result.isNearLimit)
          Padding(
            padding: warningPadding ?? const EdgeInsets.only(bottom: 12),
            child: FeatureGateWarning(
              result: result,
              onUpgrade: onUpgrade,
            ),
          ),
        child,
      ],
    );
  }
}
