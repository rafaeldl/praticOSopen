// ignore_for_file: lines_longer_than_80_chars
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:praticos/models/subscription.dart';

/// Tipos de features limitadas por plano.
enum FeatureType {
  photo,
  formTemplate,
  collaborator,
}

/// Resultado da verificação de limite de feature.
class FeatureGateResult {
  /// Se a feature está permitida.
  final bool isAllowed;

  /// Uso atual.
  final int currentUsage;

  /// Limite do plano. -1 = ilimitado.
  final int limit;

  /// Tipo da feature.
  final FeatureType featureType;

  /// Plano atual do usuário.
  final SubscriptionPlan currentPlan;

  final String? _overrideMessage;
  final SubscriptionPlan? _overrideSuggestedPlan;

  const FeatureGateResult({
    required this.isAllowed,
    required this.currentUsage,
    required this.limit,
    required this.featureType,
    required this.currentPlan,
    String? message,
    SubscriptionPlan? suggestedPlan,
  })  : _overrideMessage = message,
        _overrideSuggestedPlan = suggestedPlan;

  /// Porcentagem de uso (0.0 a 1.0+).
  double get usagePercentage {
    if (limit == -1) return 0.0;
    if (limit == 0) return 1.0;
    return currentUsage / limit;
  }

  /// Se está próximo do limite (>= 80%).
  bool get isNearLimit => usagePercentage >= 0.8 && !isAtLimit;

  /// Se está no limite (>= 100%).
  bool get isAtLimit => usagePercentage >= 1.0;

  /// Se o plano é ilimitado para esta feature (limit == -1).
  bool get isUnlimited => limit == -1;

  /// Quantidade restante disponível.
  int get remaining {
    if (limit == -1) return 999999; // ilimitado
    return (limit - currentUsage).clamp(0, limit);
  }

  /// Mensagem descritiva do resultado (pode ser sobrescrita no construtor).
  String? get message {
    if (_overrideMessage != null) return _overrideMessage;
    if (!isAllowed) {
      return 'Limite de ${_featureTypeName(featureType)} atingido ($currentUsage/$limit).';
    }
    return null;
  }

  static String _featureTypeName(FeatureType type) {
    switch (type) {
      case FeatureType.photo:
        return 'fotos';
      case FeatureType.formTemplate:
        return 'formulários';
      case FeatureType.collaborator:
        return 'colaboradores';
    }
  }

  /// Alias de [suggestedUpgrade] para compatibilidade.
  SubscriptionPlan? get suggestedPlan => _overrideSuggestedPlan ?? suggestedUpgrade;

  /// Plano sugerido para upgrade.
  SubscriptionPlan? get suggestedUpgrade {
    if (isAllowed && !isNearLimit) return null;

    // Encontra o próximo plano com limite maior
    final plans = SubscriptionPlan.values;
    final currentIndex = plans.indexOf(currentPlan);

    for (var i = currentIndex + 1; i < plans.length; i++) {
      final nextPlan = plans[i];
      final nextLimits = SubscriptionLimits.forPlan(nextPlan);
      final nextLimit = _getLimitForFeature(nextLimits, featureType);

      if (nextLimit == -1 || nextLimit > limit) {
        return nextPlan;
      }
    }

    return null;
  }

  static int _getLimitForFeature(SubscriptionLimits limits, FeatureType type) {
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

/// Exceção lançada quando um limite de feature é atingido.
class FeatureGateLimitException implements Exception {
  final FeatureGateResult result;

  const FeatureGateLimitException(this.result);

  String get message =>
      result.message ?? 'Limite de feature atingido (${result.currentUsage}/${result.limit})';

  @override
  String toString() => 'FeatureGateLimitException: $message';
}

/// Serviço central para verificação de feature gates.
///
/// Verifica limites de uso baseado no plano de assinatura do usuário.
class FeatureGateService {
  /// Overrides [planLimitsEnforced] in tests. Always reset to null afterwards.
  @visibleForTesting
  static bool? debugPlanLimitsEnforcedOverride;

  /// Whether subscription plan limits apply on this platform.
  ///
  /// Always `false` on iOS: App Review rejected the app under guideline 3.1.1
  /// because it accessed paid content that is not sold through In-App Purchase.
  /// With no IAP, the iOS app must not contain any paid feature, so every limit
  /// is lifted there (unlimited photos, forms and collaborators, no PDF
  /// watermark). To restore limits on iOS: ship IAP first, then drop this check.
  static bool get planLimitsEnforced =>
      debugPlanLimitsEnforcedOverride ?? !Platform.isIOS;

  /// Plan limit for the platform: the real one, or -1 (unlimited) on iOS.
  static int _effectiveLimit(int planLimit) =>
      planLimitsEnforced ? planLimit : -1;

  /// Verifica se pode adicionar uma foto.
  ///
  /// Se [subscription] for null, usa limites do plano Free.
  static FeatureGateResult canAddPhoto(Subscription? subscription) =>
      canAddPhotoWithSubscription(subscription);

  /// Alias of [canAddPhoto] — verifica se pode adicionar uma foto.
  static FeatureGateResult canAddPhotoWithSubscription(Subscription? subscription) {
    final sub = subscription ?? Subscription();
    final limits = sub.limits;
    final currentUsage = sub.usage.photosThisMonth;
    final limit = _effectiveLimit(limits.photosPerMonth);

    return FeatureGateResult(
      isAllowed: limit == -1 || currentUsage < limit,
      currentUsage: currentUsage,
      limit: limit,
      featureType: FeatureType.photo,
      currentPlan: sub.plan,
    );
  }

  /// Verifica se pode adicionar N fotos.
  static FeatureGateResult canAddPhotos(Subscription? subscription, int count) {
    final sub = subscription ?? Subscription();
    final limits = sub.limits;
    final currentUsage = sub.usage.photosThisMonth;
    final limit = _effectiveLimit(limits.photosPerMonth);

    return FeatureGateResult(
      isAllowed: limit == -1 || (currentUsage + count) <= limit,
      currentUsage: currentUsage,
      limit: limit,
      featureType: FeatureType.photo,
      currentPlan: sub.plan,
    );
  }

  /// Verifica se pode criar um formulário.
  static FeatureGateResult canCreateFormTemplate(Subscription? subscription) {
    final sub = subscription ?? Subscription();
    final limits = sub.limits;
    final currentUsage = sub.usage.formTemplates;
    final limit = _effectiveLimit(limits.formTemplates);

    return FeatureGateResult(
      isAllowed: limit == -1 || currentUsage < limit,
      currentUsage: currentUsage,
      limit: limit,
      featureType: FeatureType.formTemplate,
      currentPlan: sub.plan,
    );
  }

  /// Verifica se pode adicionar um colaborador.
  static FeatureGateResult canAddCollaborator(Subscription? subscription) {
    final sub = subscription ?? Subscription();
    final limits = sub.limits;
    final currentUsage = sub.usage.collaborators;
    final limit = _effectiveLimit(limits.collaborators);

    return FeatureGateResult(
      isAllowed: limit == -1 || currentUsage < limit,
      currentUsage: currentUsage,
      limit: limit,
      featureType: FeatureType.collaborator,
      currentPlan: sub.plan,
    );
  }

  /// Verifica se deve exibir marca d'água no PDF.
  static bool shouldShowPdfWatermark(Subscription? subscription) {
    if (!planLimitsEnforced) return false;
    final sub = subscription ?? Subscription();
    return sub.limits.pdfWatermark;
  }
}
