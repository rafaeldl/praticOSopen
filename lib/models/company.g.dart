// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'company.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Company _$CompanyFromJson(Map<String, dynamic> json) => Company()
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
  ..name = json['name'] as String?
  ..email = json['email'] as String?
  ..address = json['address'] as String?
  ..logo = json['logo'] as String?
  ..phone = json['phone'] as String?
  ..site = json['site'] as String?
  ..segment = json['segment'] as String?
  ..country = json['country'] as String?
  ..subspecialties = (json['subspecialties'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList()
  ..fieldService = json['fieldService'] as bool?
  ..useScheduling = json['useScheduling'] as bool?
  ..owner = json['owner'] == null
      ? null
      : UserAggr.fromJson(json['owner'] as Map<String, dynamic>)
  ..users = (json['users'] as List<dynamic>?)
      ?.map((e) => UserRoleAggr.fromJson(e as Map<String, dynamic>))
      .toList();

Map<String, dynamic> _$CompanyToJson(Company instance) => <String, dynamic>{
  'id': instance.id,
  'createdAt': instance.createdAt?.toIso8601String(),
  'createdBy': instance.createdBy?.toJson(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
  'updatedBy': instance.updatedBy?.toJson(),
  'name': instance.name,
  'email': instance.email,
  'address': instance.address,
  'logo': instance.logo,
  'phone': instance.phone,
  'site': instance.site,
  'segment': instance.segment,
  'country': instance.country,
  'subspecialties': instance.subspecialties,
  'fieldService': instance.fieldService,
  'useScheduling': instance.useScheduling,
  'owner': instance.owner?.toJson(),
  'users': instance.users?.map((e) => e.toJson()).toList(),
};

CompanyAggr _$CompanyAggrFromJson(Map<String, dynamic> json) => CompanyAggr()
  ..id = json['id'] as String?
  ..name = json['name'] as String?
  ..country = json['country'] as String?;

Map<String, dynamic> _$CompanyAggrToJson(CompanyAggr instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'country': instance.country,
    };
