// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_photo.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderPhoto _$OrderPhotoFromJson(Map<String, dynamic> json) => OrderPhoto()
  ..id = json['id'] as String?
  ..url = json['url'] as String?
  ..storagePath = json['storagePath'] as String?
  ..createdAt = json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String)
  ..createdBy = json['createdBy'] == null
      ? null
      : UserAggr.fromJson(json['createdBy'] as Map<String, dynamic>);

Map<String, dynamic> _$OrderPhotoToJson(OrderPhoto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'url': instance.url,
      'storagePath': instance.storagePath,
      'createdAt': instance.createdAt?.toIso8601String(),
      'createdBy': instance.createdBy?.toJson(),
    };
