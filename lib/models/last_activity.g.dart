// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'last_activity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LastActivity _$LastActivityFromJson(Map<String, dynamic> json) => LastActivity(
  type: json['type'] as String?,
  icon: json['icon'] as String?,
  preview: json['preview'] as String?,
  authorId: json['authorId'] as String?,
  authorName: json['authorName'] as String?,
  createdAt: LastActivity._timestampFromJson(json['createdAt']),
  visibility: json['visibility'] as String?,
);

Map<String, dynamic> _$LastActivityToJson(LastActivity instance) =>
    <String, dynamic>{
      'type': instance.type,
      'icon': instance.icon,
      'preview': instance.preview,
      'authorId': instance.authorId,
      'authorName': instance.authorName,
      'createdAt': LastActivity._timestampToJson(instance.createdAt),
      'visibility': instance.visibility,
    };
