// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SubscriptionUsage _$SubscriptionUsageFromJson(Map<String, dynamic> json) =>
    SubscriptionUsage(
      photosThisMonth: (json['photosThisMonth'] as num?)?.toInt() ?? 0,
      formTemplates: (json['formTemplates'] as num?)?.toInt() ?? 0,
      collaborators: (json['collaborators'] as num?)?.toInt() ?? 0,
      periodStart: json['periodStart'] == null
          ? null
          : DateTime.parse(json['periodStart'] as String),
      periodEnd: json['periodEnd'] == null
          ? null
          : DateTime.parse(json['periodEnd'] as String),
    );

Map<String, dynamic> _$SubscriptionUsageToJson(SubscriptionUsage instance) =>
    <String, dynamic>{
      'photosThisMonth': instance.photosThisMonth,
      'formTemplates': instance.formTemplates,
      'collaborators': instance.collaborators,
      'periodStart': instance.periodStart?.toIso8601String(),
      'periodEnd': instance.periodEnd?.toIso8601String(),
    };

SubscriptionLimits _$SubscriptionLimitsFromJson(Map<String, dynamic> json) =>
    SubscriptionLimits(
      photosPerMonth: (json['photosPerMonth'] as num?)?.toInt() ?? 30,
      formTemplates: (json['formTemplates'] as num?)?.toInt() ?? 1,
      collaborators: (json['collaborators'] as num?)?.toInt() ?? 1,
      pdfWatermark: json['pdfWatermark'] as bool? ?? true,
    );

Map<String, dynamic> _$SubscriptionLimitsToJson(SubscriptionLimits instance) =>
    <String, dynamic>{
      'photosPerMonth': instance.photosPerMonth,
      'formTemplates': instance.formTemplates,
      'collaborators': instance.collaborators,
      'pdfWatermark': instance.pdfWatermark,
    };

Subscription _$SubscriptionFromJson(Map<String, dynamic> json) => Subscription(
  id: json['id'] as String?,
  plan:
      $enumDecodeNullable(_$SubscriptionPlanEnumMap, json['plan']) ??
      SubscriptionPlan.free,
  status:
      $enumDecodeNullable(_$SubscriptionStatusEnumMap, json['status']) ??
      SubscriptionStatus.active,
  usage: json['usage'] == null
      ? null
      : SubscriptionUsage.fromJson(json['usage'] as Map<String, dynamic>),
  currentPeriodStart: json['currentPeriodStart'] == null
      ? null
      : DateTime.parse(json['currentPeriodStart'] as String),
  currentPeriodEnd: json['currentPeriodEnd'] == null
      ? null
      : DateTime.parse(json['currentPeriodEnd'] as String),
  revenueCatCustomerId: json['revenueCatCustomerId'] as String?,
);

Map<String, dynamic> _$SubscriptionToJson(Subscription instance) =>
    <String, dynamic>{
      'id': instance.id,
      'plan': _$SubscriptionPlanEnumMap[instance.plan]!,
      'status': _$SubscriptionStatusEnumMap[instance.status]!,
      'usage': instance.usage.toJson(),
      'currentPeriodStart': instance.currentPeriodStart?.toIso8601String(),
      'currentPeriodEnd': instance.currentPeriodEnd?.toIso8601String(),
      'revenueCatCustomerId': instance.revenueCatCustomerId,
    };

const _$SubscriptionPlanEnumMap = {
  SubscriptionPlan.free: 'free',
  SubscriptionPlan.starter: 'starter',
  SubscriptionPlan.pro: 'pro',
  SubscriptionPlan.business: 'business',
};

const _$SubscriptionStatusEnumMap = {
  SubscriptionStatus.active: 'active',
  SubscriptionStatus.canceled: 'canceled',
  SubscriptionStatus.expired: 'expired',
  SubscriptionStatus.trialing: 'trialing',
};
