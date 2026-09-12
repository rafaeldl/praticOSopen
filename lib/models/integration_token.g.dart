// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'integration_token.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IntegrationToken _$IntegrationTokenFromJson(Map<String, dynamic> json) =>
    IntegrationToken(
      id: json['id'] as String?,
      name: json['name'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      lastUsedAt: json['lastUsedAt'] == null
          ? null
          : DateTime.parse(json['lastUsedAt'] as String),
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
    );

Map<String, dynamic> _$IntegrationTokenToJson(IntegrationToken instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'createdAt': instance.createdAt?.toIso8601String(),
      'lastUsedAt': instance.lastUsedAt?.toIso8601String(),
      'expiresAt': instance.expiresAt?.toIso8601String(),
    };

CreatedIntegrationToken _$CreatedIntegrationTokenFromJson(
  Map<String, dynamic> json,
) => CreatedIntegrationToken(
  id: json['id'] as String?,
  url: json['url'] as String?,
  expiresAt: json['expiresAt'] == null
      ? null
      : DateTime.parse(json['expiresAt'] as String),
);

Map<String, dynamic> _$CreatedIntegrationTokenToJson(
  CreatedIntegrationToken instance,
) => <String, dynamic>{
  'id': instance.id,
  'url': instance.url,
  'expiresAt': instance.expiresAt?.toIso8601String(),
};
