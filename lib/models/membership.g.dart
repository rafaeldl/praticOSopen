// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'membership.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Membership _$MembershipFromJson(Map<String, dynamic> json) => Membership(
  user: json['user'] == null
      ? null
      : UserAggr.fromJson(json['user'] as Map<String, dynamic>),
  role: $enumDecodeNullable(
    _$RolesTypeEnumMap,
    json['role'],
    unknownValue: RolesType.technician,
  ),
  joinedAt: const TimestampConverter().fromJson(json['joinedAt']),
);

Map<String, dynamic> _$MembershipToJson(Membership instance) =>
    <String, dynamic>{
      'user': instance.user?.toJson(),
      'role': _$RolesTypeEnumMap[instance.role],
      'joinedAt': const TimestampConverter().toJson(instance.joinedAt),
    };

const _$RolesTypeEnumMap = {
  RolesType.admin: 'admin',
  RolesType.supervisor: 'supervisor',
  RolesType.manager: 'manager',
  RolesType.consultant: 'consultant',
  RolesType.technician: 'technician',
};
