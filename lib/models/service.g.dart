// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Service _$ServiceFromJson(Map<String, dynamic> json) => Service()
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
  ..name = json['name'] as String?
  ..value = (json['value'] as num?)?.toDouble()
  ..photo = json['photo'] as String?
  ..keywords = (json['keywords'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList()
  ..customData = json['customData'] as Map<String, dynamic>?;

Map<String, dynamic> _$ServiceToJson(Service instance) => <String, dynamic>{
  'id': instance.id,
  'createdAt': instance.createdAt?.toIso8601String(),
  'createdBy': instance.createdBy?.toJson(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
  'updatedBy': instance.updatedBy?.toJson(),
  'company': instance.company?.toJson(),
  'name': instance.name,
  'value': instance.value,
  'photo': instance.photo,
  'keywords': instance.keywords,
  'customData': instance.customData,
};

ServiceAggr _$ServiceAggrFromJson(Map<String, dynamic> json) => ServiceAggr()
  ..id = json['id'] as String?
  ..name = json['name'] as String?
  ..value = (json['value'] as num?)?.toDouble()
  ..photo = json['photo'] as String?;

Map<String, dynamic> _$ServiceAggrToJson(ServiceAggr instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'value': instance.value,
      'photo': instance.photo,
    };
