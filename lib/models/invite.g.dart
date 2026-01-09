// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invite.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Invite _$InviteFromJson(Map<String, dynamic> json) => Invite()
  ..id = json['id'] as String?
  ..email = json['email'] as String?
  ..company = json['company'] == null
      ? null
      : CompanyAggr.fromJson(json['company'] as Map<String, dynamic>)
  ..role = $enumDecodeNullable(_$RolesTypeEnumMap, json['role'])
  ..invitedBy = json['invitedBy'] == null
      ? null
      : UserAggr.fromJson(json['invitedBy'] as Map<String, dynamic>)
  ..createdAt = json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String)
  ..status = $enumDecodeNullable(_$InviteStatusEnumMap, json['status']);

Map<String, dynamic> _$InviteToJson(Invite instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'company': instance.company?.toJson(),
  'role': _$RolesTypeEnumMap[instance.role],
  'invitedBy': instance.invitedBy?.toJson(),
  'createdAt': instance.createdAt?.toIso8601String(),
  'status': _$InviteStatusEnumMap[instance.status],
};

const _$RolesTypeEnumMap = {
  RolesType.admin: 'admin',
  RolesType.supervisor: 'supervisor',
  RolesType.manager: 'manager',
  RolesType.consultant: 'consultant',
  RolesType.technician: 'technician',
};

const _$InviteStatusEnumMap = {
  InviteStatus.pending: 'pending',
  InviteStatus.accepted: 'accepted',
  InviteStatus.rejected: 'rejected',
};
