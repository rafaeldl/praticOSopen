// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Subscription _$SubscriptionFromJson(Map<String, dynamic> json) => Subscription()
  ..plan = json['plan'] as String?
  ..status = json['status'] as String?
  ..rcSubscriberId = json['rcSubscriberId'] as String?
  ..subscribedAt = json['subscribedAt'] == null
      ? null
      : DateTime.parse(json['subscribedAt'] as String)
  ..expiresAt = json['expiresAt'] == null
      ? null
      : DateTime.parse(json['expiresAt'] as String)
  ..cancelledAt = json['cancelledAt'] == null
      ? null
      : DateTime.parse(json['cancelledAt'] as String)
  ..limits = json['limits'] == null
      ? null
      : SubscriptionLimits.fromJson(json['limits'] as Map<String, dynamic>)
  ..usage = json['usage'] == null
      ? null
      : SubscriptionUsage.fromJson(json['usage'] as Map<String, dynamic>);

Map<String, dynamic> _$SubscriptionToJson(Subscription instance) =>
    <String, dynamic>{
      'plan': instance.plan,
      'status': instance.status,
      'rcSubscriberId': instance.rcSubscriberId,
      'subscribedAt': instance.subscribedAt?.toIso8601String(),
      'expiresAt': instance.expiresAt?.toIso8601String(),
      'cancelledAt': instance.cancelledAt?.toIso8601String(),
      'limits': instance.limits?.toJson(),
      'usage': instance.usage?.toJson(),
    };

SubscriptionLimits _$SubscriptionLimitsFromJson(Map<String, dynamic> json) =>
    SubscriptionLimits()
      ..photosPerMonth = (json['photosPerMonth'] as num?)?.toInt()
      ..formTemplates = (json['formTemplates'] as num?)?.toInt()
      ..users = (json['users'] as num?)?.toInt()
      ..pdfWatermark = json['pdfWatermark'] as bool?;

Map<String, dynamic> _$SubscriptionLimitsToJson(SubscriptionLimits instance) =>
    <String, dynamic>{
      'photosPerMonth': instance.photosPerMonth,
      'formTemplates': instance.formTemplates,
      'users': instance.users,
      'pdfWatermark': instance.pdfWatermark,
    };

SubscriptionUsage _$SubscriptionUsageFromJson(Map<String, dynamic> json) =>
    SubscriptionUsage()
      ..photosThisMonth = (json['photosThisMonth'] as num?)?.toInt()
      ..formTemplatesActive = (json['formTemplatesActive'] as num?)?.toInt()
      ..usersActive = (json['usersActive'] as num?)?.toInt()
      ..usageResetAt = json['usageResetAt'] == null
          ? null
          : DateTime.parse(json['usageResetAt'] as String);

Map<String, dynamic> _$SubscriptionUsageToJson(SubscriptionUsage instance) =>
    <String, dynamic>{
      'photosThisMonth': instance.photosThisMonth,
      'formTemplatesActive': instance.formTemplatesActive,
      'usersActive': instance.usersActive,
      'usageResetAt': instance.usageResetAt?.toIso8601String(),
    };
