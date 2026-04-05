import "package:praticos/services/analytics_service.dart";
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show LinearProgressIndicator, AlwaysStoppedAnimation;
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/subscription.dart';
import 'package:praticos/services/feature_gate_service.dart';

/// Modal exibido quando o usuário atinge 100% do limite de uma feature.
///
/// Apresenta um CupertinoActionSheet com:
/// - Ícone contextual para o tipo de feature
/// - Uso atual vs limite
/// - Sugestão de plano com novo limite
/// - Botões: Fazer upgrade / Talvez depois
///
/// Uso:
/// ```dart
/// FeatureGateLimitModal.show(
///   context,
///   result: FeatureGateService.canAddPhoto(subscription),
///   onUpgrade: () => Navigator.pushNamed(context, '/plans'),
/// );
/// ```
class FeatureGateLimitModal {
  /// Exibe o modal de limite atingido.
  static Future<bool> show(
    BuildContext context, {
    required FeatureGateResult result,
    VoidCallback? onUpgrade,
  }) async {
    AnalyticsService.instance.logUpgradeModalShown(trigger: "${result.featureType.name}_limit");
    if (!result.isAtLimit) return true;

    final didUpgrade = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => _FeatureGateLimitSheet(
        result: result,
        onUpgrade: onUpgrade,
      ),
    );

    return didUpgrade ?? false;
  }

  /// Verifica e exibe o modal se necessário.
  /// Retorna true se pode continuar (não está no limite ou usuário fez upgrade).
  static Future<bool> checkAndShow(
    BuildContext context, {
    required FeatureGateResult result,
    VoidCallback? onUpgrade,
  }) async {
    if (!result.isAtLimit) return true;
    return show(context, result: result, onUpgrade: onUpgrade);
  }
}

class _FeatureGateLimitSheet extends StatelessWidget {
  final FeatureGateResult result;
  final VoidCallback? onUpgrade;

  const _FeatureGateLimitSheet({
    required this.result,
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final featureName = _getFeatureName(result.featureType, l10n);
    final currentPlanName = _getPlanDisplayName(result.currentPlan);
    final suggestedPlan = result.suggestedUpgrade;
    final suggestedPlanName =
        suggestedPlan != null ? _getPlanDisplayName(suggestedPlan) : null;

    return CupertinoActionSheet(
      title: Column(
        children: [
          // Ícone contextual
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: CupertinoColors.systemRed.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getFeatureIcon(result.featureType),
              size: 32,
              color: CupertinoColors.systemRed,
            ),
          ),
          Text(
            l10n.featureGateLimitModalTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      message: Column(
        children: [
          const SizedBox(height: 8),
          Text(
            l10n.featureGateLimitModalMessage(featureName, currentPlanName),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Indicador de uso
          _buildUsageIndicator(context, featureName, l10n),
          const SizedBox(height: 16),
          // Sugestão de upgrade
          if (suggestedPlan != null && suggestedPlanName != null)
            _buildUpgradeSuggestion(
              context,
              suggestedPlan,
              suggestedPlanName,
              featureName,
              l10n,
            ),
        ],
      ),
      actions: [
        if (suggestedPlanName != null && onUpgrade != null)
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context, true);
              onUpgrade!();
            },
            child: Text(
              l10n.featureGateUpgradeButton(suggestedPlanName),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(context, false),
        child: Text(l10n.maybeLater),
      ),
    );
  }

  Widget _buildUsageIndicator(
    BuildContext context,
    String featureName,
    dynamic l10n,
  ) {
    final percentage = (result.usagePercentage * 100).clamp(0, 100).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.featureGateLimitModalUsage(
                  result.currentUsage,
                  result.limit,
                  featureName,
                ),
                style: TextStyle(
                  fontSize: 15,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Barra de progresso
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: result.usagePercentage.clamp(0.0, 1.0),
                backgroundColor: CupertinoColors.systemGrey4.resolveFrom(context),
                valueColor: AlwaysStoppedAnimation<Color>(
                  percentage >= 100
                      ? CupertinoColors.systemRed
                      : CupertinoColors.systemOrange,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$percentage%',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: percentage >= 100
                  ? CupertinoColors.systemRed
                  : CupertinoColors.systemOrange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeSuggestion(
    BuildContext context,
    SubscriptionPlan suggestedPlan,
    String suggestedPlanName,
    String featureName,
    dynamic l10n,
  ) {
    final newLimits = SubscriptionLimits.forPlan(suggestedPlan);
    final newLimit = _getLimitForFeature(newLimits, result.featureType);
    final newLimitText = newLimit == -1 ? l10n.unlimitedLabel : '$newLimit';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.activeBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: CupertinoColors.activeBlue.withValues(alpha: 0.3),
        ),
      ),
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
            l10n.featureGateUpgradeNewLimit(newLimitText, featureName),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.activeBlue,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFeatureIcon(FeatureType type) {
    switch (type) {
      case FeatureType.photo:
        return CupertinoIcons.camera_fill;
      case FeatureType.formTemplate:
        return CupertinoIcons.doc_text_fill;
      case FeatureType.collaborator:
        return CupertinoIcons.person_2_fill;
    }
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

  int _getLimitForFeature(SubscriptionLimits limits, FeatureType type) {
    switch (type) {
      case FeatureType.photo:
        return limits.photosPerMonth;
      case FeatureType.formTemplate:
        return limits.formTemplates;
      case FeatureType.collaborator:
        return limits.collaborators;
    }
  }
}

/// Helper para verificar limite antes de uma ação.
///
/// Uso:
/// ```dart
/// final canProceed = await FeatureGateCheck.photos(
///   context,
///   subscription: subscription,
///   onUpgrade: () => Navigator.pushNamed(context, '/plans'),
/// );
/// if (!canProceed) return;
/// // Continuar com a ação...
/// ```
class FeatureGateCheck {
  /// Verifica se pode adicionar uma foto.
  static Future<bool> photos(
    BuildContext context, {
    required Subscription? subscription,
    VoidCallback? onUpgrade,
  }) async {
    final result = FeatureGateService.canAddPhoto(subscription);
    return FeatureGateLimitModal.checkAndShow(
      context,
      result: result,
      onUpgrade: onUpgrade,
    );
  }

  /// Verifica se pode adicionar N fotos.
  static Future<bool> multiplePhotos(
    BuildContext context, {
    required Subscription? subscription,
    required int count,
    VoidCallback? onUpgrade,
  }) async {
    final result = FeatureGateService.canAddPhotos(subscription, count);
    return FeatureGateLimitModal.checkAndShow(
      context,
      result: result,
      onUpgrade: onUpgrade,
    );
  }

  /// Verifica se pode criar um formulário.
  static Future<bool> formTemplate(
    BuildContext context, {
    required Subscription? subscription,
    VoidCallback? onUpgrade,
  }) async {
    final result = FeatureGateService.canCreateFormTemplate(subscription);
    return FeatureGateLimitModal.checkAndShow(
      context,
      result: result,
      onUpgrade: onUpgrade,
    );
  }

  /// Verifica se pode adicionar um colaborador.
  static Future<bool> collaborator(
    BuildContext context, {
    required Subscription? subscription,
    VoidCallback? onUpgrade,
  }) async {
    final result = FeatureGateService.canAddCollaborator(subscription);
    return FeatureGateLimitModal.checkAndShow(
      context,
      result: result,
      onUpgrade: onUpgrade,
    );
  }
}
