// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Customer _$CustomerFromJson(Map<String, dynamic> json) => Customer()
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
  ..phone = json['phone'] as String?
  ..email = json['email'] as String?
  ..address = json['address'] as String?
  ..latitude = (json['latitude'] as num?)?.toDouble()
  ..longitude = (json['longitude'] as num?)?.toDouble()
  ..keywords = (json['keywords'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList();

Map<String, dynamic> _$CustomerToJson(Customer instance) => <String, dynamic>{
  'id': instance.id,
  'createdAt': instance.createdAt?.toIso8601String(),
  'createdBy': instance.createdBy?.toJson(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
  'updatedBy': instance.updatedBy?.toJson(),
  'company': instance.company?.toJson(),
  'name': instance.name,
  'phone': instance.phone,
  'email': instance.email,
  'address': instance.address,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'keywords': instance.keywords,
};

CustomerAggr _$CustomerAggrFromJson(Map<String, dynamic> json) => CustomerAggr()
  ..id = json['id'] as String?
  ..name = json['name'] as String?
  ..phone = json['phone'] as String?
  ..email = json['email'] as String?;

Map<String, dynamic> _$CustomerAggrToJson(CustomerAggr instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'phone': instance.phone,
      'email': instance.email,
    };
