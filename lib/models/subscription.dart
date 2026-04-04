import 'package:json_annotation/json_annotation.dart';

part 'subscription.g.dart';

/// Modelo de assinatura da empresa.
/// Representa o plano atual e limites de uso.
@JsonSerializable(explicitToJson: true)
class Subscription {
  /// Plano atual: 'free', 'starter', 'pro', 'business'
  String? plan;

  /// Status: 'active', 'trialing', 'past_due', 'cancelled', 'expired'
  String? status;

  /// RevenueCat subscriber ID
  String? rcSubscriberId;

  /// Data de início da assinatura
  DateTime? subscribedAt;

  /// Data de expiração
  DateTime? expiresAt;

  /// Data de cancelamento
  DateTime? cancelledAt;

  /// Limites do plano atual
  SubscriptionLimits? limits;

  /// Uso atual (resetado mensalmente)
  SubscriptionUsage? usage;

  Subscription();

  factory Subscription.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionFromJson(json);

  Map<String, dynamic> toJson() => _$SubscriptionToJson(this);

  /// Verifica se a assinatura está ativa
  bool get isActive => status == 'active' || status == 'trialing';

  /// Verifica se é um plano pago
  bool get isPaid => plan != null && plan != 'free';

  /// Verifica se a assinatura está expirada
  bool get isExpired =>
      status == 'expired' ||
      (expiresAt != null && expiresAt!.isBefore(DateTime.now()));
}

/// Limites de uso baseados no plano.
@JsonSerializable()
class SubscriptionLimits {
  /// Fotos por mês: -1 = ilimitado
  int? photosPerMonth;

  /// Número de templates de formulário
  int? formTemplates;

  /// Número de usuários
  int? users;

  /// Se deve exibir marca d'água no PDF (true para Free)
  bool? pdfWatermark;

  SubscriptionLimits();

  factory SubscriptionLimits.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionLimitsFromJson(json);

  Map<String, dynamic> toJson() => _$SubscriptionLimitsToJson(this);

  /// Verifica se o limite é ilimitado
  bool isUnlimited(int? limit) => limit == -1;
}

/// Uso atual da assinatura.
@JsonSerializable()
class SubscriptionUsage {
  /// Fotos usadas no mês atual
  int? photosThisMonth;

  /// Templates de formulário ativos
  int? formTemplatesActive;

  /// Usuários ativos
  int? usersActive;

  /// Data de reset do uso (primeiro dia do próximo mês)
  DateTime? usageResetAt;

  SubscriptionUsage();

  factory SubscriptionUsage.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionUsageFromJson(json);

  Map<String, dynamic> toJson() => _$SubscriptionUsageToJson(this);
}
