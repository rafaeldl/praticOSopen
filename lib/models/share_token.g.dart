// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'share_token.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ShareToken _$ShareTokenFromJson(Map<String, dynamic> json) => ShareToken()
  ..token = json['token'] as String?
  ..orderId = json['orderId'] as String?
  ..companyId = json['companyId'] as String?
  ..permissions = (json['permissions'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList()
  ..customer = json['customer'] == null
      ? null
      : CustomerAggr.fromJson(json['customer'] as Map<String, dynamic>)
  ..createdAt = json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String)
  ..expiresAt = json['expiresAt'] == null
      ? null
      : DateTime.parse(json['expiresAt'] as String)
  ..createdBy = json['createdBy'] == null
      ? null
      : UserAggr.fromJson(json['createdBy'] as Map<String, dynamic>)
  ..viewCount = (json['viewCount'] as num?)?.toInt()
  ..lastViewedAt = json['lastViewedAt'] == null
      ? null
      : DateTime.parse(json['lastViewedAt'] as String)
  ..approvedAt = json['approvedAt'] == null
      ? null
      : DateTime.parse(json['approvedAt'] as String)
  ..rejectedAt = json['rejectedAt'] == null
      ? null
      : DateTime.parse(json['rejectedAt'] as String)
  ..rejectionReason = json['rejectionReason'] as String?;

Map<String, dynamic> _$ShareTokenToJson(ShareToken instance) =>
    <String, dynamic>{
      'token': instance.token,
      'orderId': instance.orderId,
      'companyId': instance.companyId,
      'permissions': instance.permissions,
      'customer': instance.customer?.toJson(),
      'createdAt': instance.createdAt?.toIso8601String(),
      'expiresAt': instance.expiresAt?.toIso8601String(),
      'createdBy': instance.createdBy?.toJson(),
      'viewCount': instance.viewCount,
      'lastViewedAt': instance.lastViewedAt?.toIso8601String(),
      'approvedAt': instance.approvedAt?.toIso8601String(),
      'rejectedAt': instance.rejectedAt?.toIso8601String(),
      'rejectionReason': instance.rejectionReason,
    };

ShareLinkResult _$ShareLinkResultFromJson(Map<String, dynamic> json) =>
    ShareLinkResult()
      ..token = json['token'] as String?
      ..url = json['url'] as String?
      ..permissions = (json['permissions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList()
      ..expiresAt = json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String)
      ..customer = json['customer'] == null
          ? null
          : CustomerAggr.fromJson(json['customer'] as Map<String, dynamic>);

Map<String, dynamic> _$ShareLinkResultToJson(ShareLinkResult instance) =>
    <String, dynamic>{
      'token': instance.token,
      'url': instance.url,
      'permissions': instance.permissions,
      'expiresAt': instance.expiresAt?.toIso8601String(),
      'customer': instance.customer?.toJson(),
    };
