// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_notification.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppNotification _$AppNotificationFromJson(Map<String, dynamic> json) =>
    AppNotification()
      ..id = json['id'] as String?
      ..createdAt = json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String)
      ..createdBy = json['createdBy'] == null
          ? null
          : UserAggr.fromJson(json['createdBy'] as Map<String, dynamic>)
      ..updatedAt = json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String)
      ..updatedBy = json['updatedBy'] == null
          ? null
          : UserAggr.fromJson(json['updatedBy'] as Map<String, dynamic>)
      ..company = json['company'] == null
          ? null
          : CompanyAggr.fromJson(json['company'] as Map<String, dynamic>)
      ..title = json['title'] as String?
      ..body = json['body'] as String?
      ..type = json['type'] as String?
      ..orderId = json['orderId'] as String?
      ..orderNumber = json['orderNumber'] as String?
      ..read = json['read'] as bool?
      ..readAt = json['readAt'] == null
          ? null
          : DateTime.parse(json['readAt'] as String)
      ..recipientId = json['recipientId'] as String?
      ..data = json['data'] as Map<String, dynamic>?;

Map<String, dynamic> _$AppNotificationToJson(AppNotification instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt?.toIso8601String(),
      'createdBy': instance.createdBy?.toJson(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'updatedBy': instance.updatedBy?.toJson(),
      'company': instance.company?.toJson(),
      'title': instance.title,
      'body': instance.body,
      'type': instance.type,
      'orderId': instance.orderId,
      'orderNumber': instance.orderNumber,
      'read': instance.read,
      'readAt': instance.readAt?.toIso8601String(),
      'recipientId': instance.recipientId,
      'data': instance.data,
    };

AppNotificationAggr _$AppNotificationAggrFromJson(Map<String, dynamic> json) =>
    AppNotificationAggr()
      ..id = json['id'] as String?
      ..title = json['title'] as String?
      ..type = json['type'] as String?
      ..read = json['read'] as bool?;

Map<String, dynamic> _$AppNotificationAggrToJson(
  AppNotificationAggr instance,
) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'type': instance.type,
  'read': instance.read,
};
