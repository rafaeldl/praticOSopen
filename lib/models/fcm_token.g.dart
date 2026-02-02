// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fcm_token.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FcmToken _$FcmTokenFromJson(Map<String, dynamic> json) => FcmToken(
  token: json['token'] as String?,
  deviceId: json['deviceId'] as String?,
  platform: json['platform'] as String?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  lastUsedAt: json['lastUsedAt'] == null
      ? null
      : DateTime.parse(json['lastUsedAt'] as String),
);

Map<String, dynamic> _$FcmTokenToJson(FcmToken instance) => <String, dynamic>{
  'token': instance.token,
  'deviceId': instance.deviceId,
  'platform': instance.platform,
  'createdAt': instance.createdAt?.toIso8601String(),
  'lastUsedAt': instance.lastUsedAt?.toIso8601String(),
};
