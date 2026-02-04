// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invite.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Invite _$InviteFromJson(Map<String, dynamic> json) => Invite()
  ..id = json['id'] as String?
  ..token = json['token'] as String?
  ..name = json['name'] as String?
  ..email = json['email'] as String?
  ..phone = json['phone'] as String?
  ..company = json['company'] == null
      ? null
      : CompanyAggr.fromJson(json['company'] as Map<String, dynamic>)
  ..role = $enumDecodeNullable(
    _$RolesTypeEnumMap,
    json['role'],
    unknownValue: RolesType.technician,
  )
  ..invitedBy = json['invitedBy'] == null
      ? null
      : UserAggr.fromJson(json['invitedBy'] as Map<String, dynamic>)
  ..createdAt = json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String)
  ..expiresAt = json['expiresAt'] == null
      ? null
      : DateTime.parse(json['expiresAt'] as String)
  ..status = $enumDecodeNullable(
    _$InviteStatusEnumMap,
    json['status'],
    unknownValue: InviteStatus.pending,
  )
  ..acceptedAt = json['acceptedAt'] == null
      ? null
      : DateTime.parse(json['acceptedAt'] as String)
  ..acceptedByUserId = json['acceptedByUserId'] as String?
  ..channel = $enumDecodeNullable(
    _$InviteChannelEnumMap,
    json['channel'],
    unknownValue: InviteChannel.app,
  );

Map<String, dynamic> _$InviteToJson(Invite instance) => <String, dynamic>{
  'id': instance.id,
  'token': instance.token,
  'name': instance.name,
  'email': instance.email,
  'phone': instance.phone,
  'company': instance.company?.toJson(),
  'role': _$RolesTypeEnumMap[instance.role],
  'invitedBy': instance.invitedBy?.toJson(),
  'createdAt': instance.createdAt?.toIso8601String(),
  'expiresAt': instance.expiresAt?.toIso8601String(),
  'status': _$InviteStatusEnumMap[instance.status],
  'acceptedAt': instance.acceptedAt?.toIso8601String(),
  'acceptedByUserId': instance.acceptedByUserId,
  'channel': _$InviteChannelEnumMap[instance.channel],
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
  InviteStatus.cancelled: 'cancelled',
};

const _$InviteChannelEnumMap = {
  InviteChannel.app: 'app',
  InviteChannel.whatsapp: 'whatsapp',
};
