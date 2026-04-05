import 'package:json_annotation/json_annotation.dart';

part 'subscription.g.dart';

/// Planos disponíveis no PraticOS.
enum SubscriptionPlan {
  @JsonValue('free')
  free,
  @JsonValue('starter')
  starter,
  @JsonValue('pro')
  pro,
  @JsonValue('business')
  business,
}

/// Status da assinatura.
enum SubscriptionStatus {
  @JsonValue('active')
  active,
  @JsonValue('canceled')
  canceled,
  @JsonValue('expired')
  expired,
  @JsonValue('trialing')
  trialing,
}

/// Contadores de uso do plano atual.
@JsonSerializable()
class SubscriptionUsage {
  int photosThisMonth;
  int formTemplates;
  int collaborators;
  DateTime? periodStart;
  DateTime? periodEnd;

  SubscriptionUsage({
    this.photosThisMonth = 0,
    this.formTemplates = 0,
    this.collaborators = 0,
    this.periodStart,
    this.periodEnd,
  });

  factory SubscriptionUsage.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionUsageFromJson(json);
  Map<String, dynamic> toJson() => _$SubscriptionUsageToJson(this);
}

/// Limites do plano.
@JsonSerializable()
class SubscriptionLimits {
  /// Fotos por mês. -1 = ilimitado.
  final int photosPerMonth;

  /// Formulários ativos. -1 = ilimitado.
  final int formTemplates;

  /// Usuários na empresa. -1 = ilimitado.
  final int collaborators;

  /// Exibir marca d'água no PDF.
  final bool pdfWatermark;

  const SubscriptionLimits({
    this.photosPerMonth = 30,
    this.formTemplates = 1,
    this.collaborators = 1,
    this.pdfWatermark = true,
  });

  factory SubscriptionLimits.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionLimitsFromJson(json);
  Map<String, dynamic> toJson() => _$SubscriptionLimitsToJson(this);

  /// Limites padrão por plano.
  static const Map<SubscriptionPlan, SubscriptionLimits> defaults = {
    SubscriptionPlan.free: SubscriptionLimits(
      photosPerMonth: 30,
      formTemplates: 1,
      collaborators: 1,
      pdfWatermark: true,
    ),
    SubscriptionPlan.starter: SubscriptionLimits(
      photosPerMonth: 200,
      formTemplates: 3,
      collaborators: 3,
      pdfWatermark: false,
    ),
    SubscriptionPlan.pro: SubscriptionLimits(
      photosPerMonth: 500,
      formTemplates: 10,
      collaborators: 5,
      pdfWatermark: false,
    ),
    SubscriptionPlan.business: SubscriptionLimits(
      photosPerMonth: -1, // ilimitado
      formTemplates: -1,
      collaborators: -1,
      pdfWatermark: false,
    ),
  };

  /// Retorna limites para um plano específico.
  static SubscriptionLimits forPlan(SubscriptionPlan plan) {
    return defaults[plan] ?? const SubscriptionLimits();
  }
}

/// Modelo de assinatura do PraticOS.
@JsonSerializable(explicitToJson: true)
class Subscription {
  String? id;
  SubscriptionPlan plan;
  SubscriptionStatus status;
  SubscriptionUsage usage;
  DateTime? currentPeriodStart;
  DateTime? currentPeriodEnd;
  String? revenueCatCustomerId;

  Subscription({
    this.id,
    this.plan = SubscriptionPlan.free,
    this.status = SubscriptionStatus.active,
    SubscriptionUsage? usage,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.revenueCatCustomerId,
  }) : usage = usage ?? SubscriptionUsage();

  factory Subscription.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionFromJson(json);
  Map<String, dynamic> toJson() => _$SubscriptionToJson(this);

  /// Retorna os limites do plano atual.
  SubscriptionLimits get limits => SubscriptionLimits.forPlan(plan);

  /// Verifica se a assinatura está ativa.
  bool get isActive =>
      status == SubscriptionStatus.active ||
      status == SubscriptionStatus.trialing;
}
