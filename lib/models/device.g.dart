// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Device _$DeviceFromJson(Map<String, dynamic> json) => Device()
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
  ..serial = json['serial'] as String?
  ..name = json['name'] as String?
  ..manufacturer = json['manufacturer'] as String?
  ..category = json['category'] as String?
  ..description = json['description'] as String?
  ..photo = json['photo'] as String?
  ..keywords = (json['keywords'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList();

Map<String, dynamic> _$DeviceToJson(Device instance) => <String, dynamic>{
  'id': instance.id,
  'createdAt': instance.createdAt?.toIso8601String(),
  'createdBy': instance.createdBy?.toJson(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
  'updatedBy': instance.updatedBy?.toJson(),
  'company': instance.company?.toJson(),
  'serial': instance.serial,
  'name': instance.name,
  'manufacturer': instance.manufacturer,
  'category': instance.category,
  'description': instance.description,
  'photo': instance.photo,
  'keywords': instance.keywords,
};

DeviceAggr _$DeviceAggrFromJson(Map<String, dynamic> json) => DeviceAggr()
  ..id = json['id'] as String?
  ..serial = json['serial'] as String?
  ..name = json['name'] as String?
  ..photo = json['photo'] as String?;

Map<String, dynamic> _$DeviceAggrToJson(DeviceAggr instance) =>
    <String, dynamic>{
      'id': instance.id,
      'serial': instance.serial,
      'name': instance.name,
      'photo': instance.photo,
    };
