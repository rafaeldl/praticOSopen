// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timeline_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TimelineEvent _$TimelineEventFromJson(Map<String, dynamic> json) =>
    TimelineEvent(
      id: json['id'] as String?,
      type: json['type'] as String?,
      visibility: json['visibility'] as String? ?? 'internal',
      author: json['author'] == null
          ? null
          : TimelineAuthor.fromJson(json['author'] as Map<String, dynamic>),
      data: json['data'] == null
          ? null
          : TimelineEventData.fromJson(json['data'] as Map<String, dynamic>),
      readBy: (json['readBy'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      mentions: (json['mentions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      createdAt: TimelineEvent._timestampFromJson(json['createdAt']),
      isDeleted: json['isDeleted'] as bool? ?? false,
    );

Map<String, dynamic> _$TimelineEventToJson(TimelineEvent instance) =>
    <String, dynamic>{
      'id': ?instance.id,
      'type': ?instance.type,
      'visibility': ?instance.visibility,
      'author': ?instance.author?.toJson(),
      'data': ?instance.data?.toJson(),
      'readBy': ?instance.readBy,
      'mentions': ?instance.mentions,
      'createdAt': ?TimelineEvent._timestampToJson(instance.createdAt),
      'isDeleted': ?instance.isDeleted,
    };

TimelineAuthor _$TimelineAuthorFromJson(Map<String, dynamic> json) =>
    TimelineAuthor(
      id: json['id'] as String?,
      name: json['name'] as String?,
      photoUrl: json['photoUrl'] as String?,
      type: json['type'] as String? ?? 'collaborator',
    );

Map<String, dynamic> _$TimelineAuthorToJson(TimelineAuthor instance) =>
    <String, dynamic>{
      'id': ?instance.id,
      'name': ?instance.name,
      'photoUrl': ?instance.photoUrl,
      'type': ?instance.type,
    };

TimelineEventData _$TimelineEventDataFromJson(
  Map<String, dynamic> json,
) => TimelineEventData(
  text: json['text'] as String?,
  attachments: (json['attachments'] as List<dynamic>?)
      ?.map((e) => TimelineAttachment.fromJson(e as Map<String, dynamic>))
      .toList(),
  oldStatus: json['oldStatus'] as String?,
  newStatus: json['newStatus'] as String?,
  reason: json['reason'] as String?,
  photoUrls: (json['photoUrls'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  caption: json['caption'] as String?,
  serviceName: json['serviceName'] as String?,
  serviceValue: (json['serviceValue'] as num?)?.toDouble(),
  oldValue: (json['oldValue'] as num?)?.toDouble(),
  newValue: (json['newValue'] as num?)?.toDouble(),
  description: json['description'] as String?,
  productName: json['productName'] as String?,
  quantity: (json['quantity'] as num?)?.toInt(),
  oldQuantity: (json['oldQuantity'] as num?)?.toInt(),
  newQuantity: (json['newQuantity'] as num?)?.toInt(),
  unitPrice: (json['unitPrice'] as num?)?.toDouble(),
  totalPrice: (json['totalPrice'] as num?)?.toDouble(),
  oldTotal: (json['oldTotal'] as num?)?.toDouble(),
  newTotal: (json['newTotal'] as num?)?.toDouble(),
  formName: json['formName'] as String?,
  formId: json['formId'] as String?,
  totalItems: (json['totalItems'] as num?)?.toInt(),
  completedItems: (json['completedItems'] as num?)?.toInt(),
  amount: (json['amount'] as num?)?.toDouble(),
  method: json['method'] as String?,
  orderTotal: (json['orderTotal'] as num?)?.toDouble(),
  totalPaid: (json['totalPaid'] as num?)?.toDouble(),
  remaining: (json['remaining'] as num?)?.toDouble(),
  oldAssignee: json['oldAssignee'] == null
      ? null
      : TimelineAuthor.fromJson(json['oldAssignee'] as Map<String, dynamic>),
  newAssignee: json['newAssignee'] == null
      ? null
      : TimelineAuthor.fromJson(json['newAssignee'] as Map<String, dynamic>),
  dueDate: TimelineEvent._timestampFromJson(json['dueDate']),
  oldDate: TimelineEvent._timestampFromJson(json['oldDate']),
  newDate: TimelineEvent._timestampFromJson(json['newDate']),
  daysRemaining: (json['daysRemaining'] as num?)?.toInt(),
  isOverdue: json['isOverdue'] as bool?,
  customerName: json['customerName'] as String?,
  customerPhone: json['customerPhone'] as String?,
  deviceName: json['deviceName'] as String?,
  deviceSerial: json['deviceSerial'] as String?,
);

Map<String, dynamic> _$TimelineEventDataToJson(TimelineEventData instance) =>
    <String, dynamic>{
      'text': ?instance.text,
      'attachments': ?instance.attachments?.map((e) => e.toJson()).toList(),
      'oldStatus': ?instance.oldStatus,
      'newStatus': ?instance.newStatus,
      'reason': ?instance.reason,
      'photoUrls': ?instance.photoUrls,
      'caption': ?instance.caption,
      'serviceName': ?instance.serviceName,
      'serviceValue': ?instance.serviceValue,
      'oldValue': ?instance.oldValue,
      'newValue': ?instance.newValue,
      'description': ?instance.description,
      'productName': ?instance.productName,
      'quantity': ?instance.quantity,
      'oldQuantity': ?instance.oldQuantity,
      'newQuantity': ?instance.newQuantity,
      'unitPrice': ?instance.unitPrice,
      'totalPrice': ?instance.totalPrice,
      'oldTotal': ?instance.oldTotal,
      'newTotal': ?instance.newTotal,
      'formName': ?instance.formName,
      'formId': ?instance.formId,
      'totalItems': ?instance.totalItems,
      'completedItems': ?instance.completedItems,
      'amount': ?instance.amount,
      'method': ?instance.method,
      'orderTotal': ?instance.orderTotal,
      'totalPaid': ?instance.totalPaid,
      'remaining': ?instance.remaining,
      'oldAssignee': ?instance.oldAssignee?.toJson(),
      'newAssignee': ?instance.newAssignee?.toJson(),
      'dueDate': ?TimelineEvent._timestampToJson(instance.dueDate),
      'oldDate': ?TimelineEvent._timestampToJson(instance.oldDate),
      'newDate': ?TimelineEvent._timestampToJson(instance.newDate),
      'daysRemaining': ?instance.daysRemaining,
      'isOverdue': ?instance.isOverdue,
      'customerName': ?instance.customerName,
      'customerPhone': ?instance.customerPhone,
      'deviceName': ?instance.deviceName,
      'deviceSerial': ?instance.deviceSerial,
    };

TimelineAttachment _$TimelineAttachmentFromJson(Map<String, dynamic> json) =>
    TimelineAttachment(
      id: json['id'] as String?,
      type: json['type'] as String?,
      url: json['url'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      name: json['name'] as String?,
      size: (json['size'] as num?)?.toInt(),
    );

Map<String, dynamic> _$TimelineAttachmentToJson(TimelineAttachment instance) =>
    <String, dynamic>{
      'id': ?instance.id,
      'type': ?instance.type,
      'url': ?instance.url,
      'thumbnailUrl': ?instance.thumbnailUrl,
      'name': ?instance.name,
      'size': ?instance.size,
    };
