// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_document.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderDocument _$OrderDocumentFromJson(Map<String, dynamic> json) =>
    OrderDocument()
      ..id = json['id'] as String?
      ..url = json['url'] as String?
      ..storagePath = json['storagePath'] as String?
      ..fileName = json['fileName'] as String?
      ..contentType = json['contentType'] as String?
      ..fileSize = (json['fileSize'] as num?)?.toInt()
      ..type = $enumDecodeNullable(_$OrderDocumentTypeEnumMap, json['type'])
      ..description = json['description'] as String?
      ..createdAt = json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String)
      ..createdBy = json['createdBy'] == null
          ? null
          : UserAggr.fromJson(json['createdBy'] as Map<String, dynamic>)
      ..linkedTransactionId = json['linkedTransactionId'] as String?;

Map<String, dynamic> _$OrderDocumentToJson(OrderDocument instance) =>
    <String, dynamic>{
      'id': instance.id,
      'url': instance.url,
      'storagePath': instance.storagePath,
      'fileName': instance.fileName,
      'contentType': instance.contentType,
      'fileSize': instance.fileSize,
      'type': _$OrderDocumentTypeEnumMap[instance.type],
      'description': instance.description,
      'createdAt': instance.createdAt?.toIso8601String(),
      'createdBy': instance.createdBy?.toJson(),
      'linkedTransactionId': instance.linkedTransactionId,
    };

const _$OrderDocumentTypeEnumMap = {
  OrderDocumentType.receipt: 'receipt',
  OrderDocumentType.invoice: 'invoice',
  OrderDocumentType.contract: 'contract',
  OrderDocumentType.warranty: 'warranty',
  OrderDocumentType.other: 'other',
};
