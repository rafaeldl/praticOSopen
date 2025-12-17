// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_role.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserRole _$UserRoleFromJson(Map<String, dynamic> json) => UserRole()
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
  ..user = json['user'] == null
      ? null
      : UserAggr.fromJson(json['user'] as Map<String, dynamic>)
  ..role = $enumDecodeNullable(_$RolesTypeEnumMap, json['role']);

Map<String, dynamic> _$UserRoleToJson(UserRole instance) => <String, dynamic>{
  'id': instance.id,
  'createdAt': instance.createdAt?.toIso8601String(),
  'createdBy': instance.createdBy?.toJson(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
  'updatedBy': instance.updatedBy?.toJson(),
  'company': instance.company?.toJson(),
  'user': instance.user?.toJson(),
  'role': _$RolesTypeEnumMap[instance.role],
};

const _$RolesTypeEnumMap = {
  RolesType.admin: 'admin',
  RolesType.manager: 'manager',
  RolesType.user: 'user',
};

UserRoleAggr _$UserRoleAggrFromJson(Map<String, dynamic> json) => UserRoleAggr()
  ..user = json['user'] == null
      ? null
      : UserAggr.fromJson(json['user'] as Map<String, dynamic>)
  ..role = $enumDecodeNullable(_$RolesTypeEnumMap, json['role']);

Map<String, dynamic> _$UserRoleAggrToJson(UserRoleAggr instance) =>
    <String, dynamic>{
      'user': instance.user?.toJson(),
      'role': _$RolesTypeEnumMap[instance.role],
    };

CompanyRoleAggr _$CompanyRoleAggrFromJson(Map<String, dynamic> json) =>
    CompanyRoleAggr()
      ..company = json['company'] == null
          ? null
          : CompanyAggr.fromJson(json['company'] as Map<String, dynamic>)
      ..role = $enumDecodeNullable(_$RolesTypeEnumMap, json['role']);

Map<String, dynamic> _$CompanyRoleAggrToJson(CompanyRoleAggr instance) =>
    <String, dynamic>{
      'company': instance.company?.toJson(),
      'role': _$RolesTypeEnumMap[instance.role],
    };
