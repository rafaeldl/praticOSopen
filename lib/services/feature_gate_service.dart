// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:praticos/models/subscription.dart';
import 'package:praticos/services/subscription_service.dart';

/// Tipos de features limitadas por plano.
enum FeatureType {
  order,
  photo,
  formTemplate,
  collaborator,
}

/// Features that depend on the plan (#724), with the keys of `features` in
/// docs/plans/plans.json. The basics (what Free has) and the assistant never
/// depend on it.
enum PlanFeature {
  nfse,
  brandedPdf,
  ownChecklists,
  charges,
  teamRoles,
  perPersonAgenda,
  workStages,
  tvMode,
  contracts,
  aiFinance,
  spreadsheetExport,
  bulkActions,
  mcp,
  api,
}

/// Whether the plan in force has a feature, and the plan that has it.
class PlanFeatureResult {
  final bool isAllowed;

  /// Key of the feature in the plan table.
  final String feature;

  /// Plan in force (Free once expiresAt has passed).
  final SubscriptionPlan currentPlan;

  /// First plan of the current table with the feature: the one to move to.
  final SubscriptionPlan? requiredPlan;

  const PlanFeatureResult({
    required this.isAllowed,
    required this.feature,
    required this.currentPlan,
    required this.requiredPlan,
  });
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

  /// Allowed only because of the month of grace (orders over the limit for
  /// the first month).
  final bool grace;

  /// Over the limit on a plan that never blocks (Business): only says it went over what is included (no outside purchase in the app, 3.1.1).
  final bool contactUs;

  /// Units being added by this check.
  final int adding;

  final String? _overrideMessage;
  final SubscriptionPlan? _overrideSuggestedPlan;

  const FeatureGateResult({
    required this.isAllowed,
    required this.currentUsage,
    required this.limit,
    required this.featureType,
    required this.currentPlan,
    this.grace = false,
    this.contactUs = false,
    this.adding = 1,
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

  /// Where the usage stands after what enters, like the server's level:
  /// unlimited, ok, near (80%), atLimit (100%) or over.
  String get level {
    if (limit < 0) return 'unlimited';
    final total = currentUsage + adding;
    if (total > limit) return 'over';
    if (total == limit) return 'atLimit';
    return total >= limit * 0.8 ? 'near' : 'ok';
  }

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
      case FeatureType.order:
        return 'OS';
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
      case FeatureType.order:
        return limits.ordersPerMonth;
      case FeatureType.photo:
        return limits.photosPerMonth;
      case FeatureType.formTemplate:
        return limits.formTemplates;
      case FeatureType.collaborator:
        return limits.users;
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
/// Usa o plano efetivo da assinatura: um plano com `expiresAt` vencido conta
/// como Free, sem esperar o job diário do servidor.
class FeatureGateService {
  /// Overrides [planLimitsEnforced] in tests. Always reset to null afterwards.
  @visibleForTesting
  static bool? debugPlanLimitsEnforcedOverride;

  /// The one switch of the plan limits, `config/paidPlans.enabled`
  /// (Firestore), the same document the server and the web read.
  /// SubscriptionStore reads it; off until read.
  static bool limitsSwitchOn = false;

  /// Whether subscription plan limits apply: the switch is on and this build
  /// can sell plans ([SubscriptionService.paidPlansEnabled]): limits only
  /// exist where plans can be bought in the app (App Review 3.1.1).
  static bool get planLimitsEnforced =>
      debugPlanLimitsEnforcedOverride ??
      (SubscriptionService.paidPlansEnabled && limitsSwitchOn);

  /// Plan limit for the platform: the real one, or -1 (unlimited).
  static int _effectiveLimit(int planLimit) =>
      planLimitsEnforced ? planLimit : -1;

  static int _usageFor(SubscriptionUsage usage, FeatureType type, DateTime now) {
    switch (type) {
      case FeatureType.order:
        return usage.ordersAt(now).thisMonth;
      case FeatureType.photo:
        return usage.photosThisMonth;
      case FeatureType.formTemplate:
        return usage.formTemplatesActive;
      case FeatureType.collaborator:
        return usage.usersActive;
    }
  }

  /// Checks whether [adding] more units of [type] fit in the plan.
  /// A null [subscription] means the Free plan. Orders have a soft limit:
  /// the first month over still creates ([FeatureGateResult.grace]); only
  /// when the month before was over too does a new order wait for a plan.
  /// Business never blocks orders nor people ([FeatureGateResult.contactUs]).
  static FeatureGateResult _check(
    Subscription? subscription,
    FeatureType type, {
    int adding = 1,
    DateTime? at,
  }) {
    final sub = subscription ?? Subscription();
    final now = at ?? DateTime.now();
    final currentUsage = _usageFor(sub.usage, type, now);
    final limit = _effectiveLimit(
      FeatureGateResult._getLimitForFeature(sub.effectiveLimits(now), type),
    );
    final fits = limit == -1 || currentUsage + adding <= limit;
    final overage = (type == FeatureType.order || type == FeatureType.collaborator) &&
        sub.planRowAt(now).overageAllowed;
    final contactUs = !fits && overage;
    final grace = !fits &&
        !contactUs &&
        type == FeatureType.order &&
        sub.usage.ordersAt(now).lastMonth <= limit;

    return FeatureGateResult(
      isAllowed: fits || contactUs || grace,
      currentUsage: currentUsage,
      limit: limit,
      featureType: type,
      currentPlan: sub.effectivePlan(now),
      grace: grace,
      contactUs: contactUs,
      adding: adding,
    );
  }

  /// Verifica se pode criar uma OS nova (limite suave do mês). Nunca vale
  /// para uma OS já aberta (editar, concluir, receber, mandar).
  static FeatureGateResult canCreateOrder(Subscription? subscription, {DateTime? now}) =>
      _check(subscription, FeatureType.order, at: now);

  /// Verifica se pode adicionar uma foto.
  static FeatureGateResult canAddPhoto(Subscription? subscription) =>
      _check(subscription, FeatureType.photo);

  /// Alias of [canAddPhoto].
  static FeatureGateResult canAddPhotoWithSubscription(Subscription? subscription) =>
      _check(subscription, FeatureType.photo);

  /// Verifica se pode adicionar N fotos.
  static FeatureGateResult canAddPhotos(Subscription? subscription, int count) =>
      _check(subscription, FeatureType.photo, adding: count);

  /// Verifica se pode criar (ou ativar) um checklist próprio. Usar um pronto
  /// do ramo não passa por aqui.
  static FeatureGateResult canCreateFormTemplate(Subscription? subscription) =>
      _check(subscription, FeatureType.formTemplate);

  /// Verifica se pode adicionar um colaborador.
  static FeatureGateResult canAddCollaborator(Subscription? subscription) =>
      _check(subscription, FeatureType.collaborator);

  /// Verifica se deve exibir marca d'água no PDF.
  static bool shouldShowPdfWatermark(Subscription? subscription) {
    if (!planLimitsEnforced) return false;
    final sub = subscription ?? Subscription();
    return sub.effectiveLimits(DateTime.now()).pdfWatermark;
  }

  // ==========================================================================
  // Features of the plan (#724). The same rule as the server
  // (plan-features.service.ts) and the web (src/lib/plan-features.ts); shared
  // cases in docs/web-app/contract-cases/plan-features.json.
  // ==========================================================================

  /// In every plan whatever the table says: the assistant only has ceilings.
  static const _neverGated = {'ai'};

  /// Roles that need [PlanFeature.teamRoles] (Pro); owner and admin are in
  /// every plan.
  static const teamRolesFeatureRoles = {'manager', 'supervisor', 'consultant', 'technician'};

  /// First plan of the current table with [feature], or null.
  static SubscriptionPlan? requiredPlanFor(String feature) {
    if (_neverGated.contains(feature)) return SubscriptionPlan.free;
    for (final plan in SubscriptionPlan.values) {
      if (currentPlanRow(plan).features.contains(feature)) return plan;
    }
    return null;
  }

  /// The feature a role needs, or null (owner, admin, or not a role).
  static PlanFeature? featureForRole(String? role) =>
      teamRolesFeatureRoles.contains(role) ? PlanFeature.teamRoles : null;

  /// Whether the plan in force has [feature] (a key of the table). Allowed
  /// with limits off ([enforced], default [planLimitsEnforced]), for the
  /// basics and the assistant, for a key no plan lists, and on a table
  /// version that lists no feature at all (version 1). Only guards creating
  /// or turning on something new: what the company has keeps working.
  static PlanFeatureResult checkFeatureKey(
    Subscription? subscription,
    String feature, {
    DateTime? now,
    bool? enforced,
  }) {
    final sub = subscription ?? Subscription();
    final at = now ?? DateTime.now();
    // The same row as the limits on server, app and web (planInForce, #726).
    final inForce = sub.planInForce(at);
    final plan = inForce.plan;
    final required = requiredPlanFor(feature);
    PlanFeatureResult result(bool allowed) => PlanFeatureResult(
          isAllowed: allowed,
          feature: feature,
          currentPlan: plan,
          requiredPlan: required,
        );
    if (!(enforced ?? planLimitsEnforced) || _neverGated.contains(feature) || required == null) {
      return result(true);
    }
    final PlanRow row = inForce.row;
    if (row.features.isEmpty) return result(true);
    return result(row.features.contains(feature));
  }

  /// [checkFeatureKey] for a [PlanFeature].
  static PlanFeatureResult checkFeature(
    Subscription? subscription,
    PlanFeature feature, {
    DateTime? now,
    bool? enforced,
  }) =>
      checkFeatureKey(subscription, feature.name, now: now, enforced: enforced);
}
