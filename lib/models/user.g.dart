// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User()
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
  ..photo = json['photo'] as String?
  ..companies = (json['companies'] as List<dynamic>?)
      ?.map((e) => CompanyRoleAggr.fromJson(e as Map<String, dynamic>))
      .toList();

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  'id': instance.id,
  'createdAt': instance.createdAt?.toIso8601String(),
  'createdBy': instance.createdBy?.toJson(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
  'updatedBy': instance.updatedBy?.toJson(),
  'name': instance.name,
  'email': instance.email,
  'photo': instance.photo,
  'companies': instance.companies?.map((e) => e.toJson()).toList(),
};

UserAggr _$UserAggrFromJson(Map<String, dynamic> json) => UserAggr()
  ..id = json['id'] as String?
  ..name = json['name'] as String?
  ..email = json['email'] as String?
  ..photo = json['photo'] as String?;

Map<String, dynamic> _$UserAggrToJson(UserAggr instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'email': instance.email,
  'photo': instance.photo,
};
