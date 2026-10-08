// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SubscriptionUsage _$SubscriptionUsageFromJson(Map<String, dynamic> json) =>
    SubscriptionUsage(
      photosThisMonth: (json['photosThisMonth'] as num?)?.toInt() ?? 0,
      formTemplatesActive: (json['formTemplatesActive'] as num?)?.toInt() ?? 0,
      usersActive: (json['usersActive'] as num?)?.toInt() ?? 0,
      usageResetAt: _dateFromJson(json['usageResetAt']),
    );

Map<String, dynamic> _$SubscriptionUsageToJson(SubscriptionUsage instance) =>
    <String, dynamic>{
      'photosThisMonth': instance.photosThisMonth,
      'formTemplatesActive': instance.formTemplatesActive,
      'usersActive': instance.usersActive,
      'usageResetAt': _dateToJson(instance.usageResetAt),
    };

SubscriptionLimits _$SubscriptionLimitsFromJson(Map<String, dynamic> json) =>
    SubscriptionLimits(
      photosPerMonth: (json['photosPerMonth'] as num?)?.toInt() ?? 30,
      formTemplates: (json['formTemplates'] as num?)?.toInt() ?? 1,
      users: (json['users'] as num?)?.toInt() ?? 1,
      pdfWatermark: json['pdfWatermark'] as bool? ?? true,
    );

Map<String, dynamic> _$SubscriptionLimitsToJson(SubscriptionLimits instance) =>
    <String, dynamic>{
      'photosPerMonth': instance.photosPerMonth,
      'formTemplates': instance.formTemplates,
      'users': instance.users,
      'pdfWatermark': instance.pdfWatermark,
    };

Subscription _$SubscriptionFromJson(Map<String, dynamic> json) => Subscription(
  plan:
      $enumDecodeNullable(
        _$SubscriptionPlanEnumMap,
        json['plan'],
        unknownValue: SubscriptionPlan.free,
      ) ??
      SubscriptionPlan.free,
  status:
      $enumDecodeNullable(
        _$SubscriptionStatusEnumMap,
        json['status'],
        unknownValue: SubscriptionStatus.active,
      ) ??
      SubscriptionStatus.active,
  source: $enumDecodeNullable(
    _$SubscriptionSourceEnumMap,
    json['source'],
    unknownValue: JsonKey.nullForUndefinedEnumValue,
  ),
  store: $enumDecodeNullable(
    _$BillingStoreEnumMap,
    json['store'],
    unknownValue: JsonKey.nullForUndefinedEnumValue,
  ),
  expiresAt: _dateFromJson(json['expiresAt']),
  limits: json['limits'] == null
      ? null
      : SubscriptionLimits.fromJson(json['limits'] as Map<String, dynamic>),
  usage: json['usage'] == null
      ? null
      : SubscriptionUsage.fromJson(json['usage'] as Map<String, dynamic>),
  rcSubscriberId: json['rcSubscriberId'] as String?,
  updatedAt: _dateFromJson(json['updatedAt']),
);

Map<String, dynamic> _$SubscriptionToJson(Subscription instance) =>
    <String, dynamic>{
      'plan': _$SubscriptionPlanEnumMap[instance.plan]!,
      'status': _$SubscriptionStatusEnumMap[instance.status]!,
      'source': _$SubscriptionSourceEnumMap[instance.source],
      'store': _$BillingStoreEnumMap[instance.store],
      'expiresAt': _dateToJson(instance.expiresAt),
      'limits': instance.limits?.toJson(),
      'usage': instance.usage.toJson(),
      'rcSubscriberId': instance.rcSubscriberId,
      'updatedAt': _dateToJson(instance.updatedAt),
    };

const _$SubscriptionPlanEnumMap = {
  SubscriptionPlan.free: 'free',
  SubscriptionPlan.starter: 'starter',
  SubscriptionPlan.pro: 'pro',
  SubscriptionPlan.business: 'business',
};

const _$SubscriptionStatusEnumMap = {
  SubscriptionStatus.active: 'active',
  SubscriptionStatus.cancelled: 'cancelled',
  SubscriptionStatus.pastDue: 'past_due',
  SubscriptionStatus.expired: 'expired',
};

const _$SubscriptionSourceEnumMap = {
  SubscriptionSource.store: 'store',
  SubscriptionSource.grace: 'grace',
};

const _$BillingStoreEnumMap = {
  BillingStore.appStore: 'app_store',
  BillingStore.playStore: 'play_store',
};
