// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_comment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CommentAuthor _$CommentAuthorFromJson(Map<String, dynamic> json) =>
    CommentAuthor()
      ..name = json['name'] as String?
      ..email = json['email'] as String?
      ..phone = json['phone'] as String?
      ..userId = json['userId'] as String?;

Map<String, dynamic> _$CommentAuthorToJson(CommentAuthor instance) =>
    <String, dynamic>{
      'name': instance.name,
      'email': instance.email,
      'phone': instance.phone,
      'userId': instance.userId,
    };

OrderComment _$OrderCommentFromJson(Map<String, dynamic> json) => OrderComment()
  ..id = json['id'] as String?
  ..text = json['text'] as String?
  ..authorType = json['authorType'] as String?
  ..author = json['author'] == null
      ? null
      : CommentAuthor.fromJson(json['author'] as Map<String, dynamic>)
  ..source = json['source'] as String?
  ..shareToken = json['shareToken'] as String?
  ..isInternal = json['isInternal'] as bool?
  ..createdAt = const TimestampConverter().fromJson(json['createdAt'])
  ..updatedAt = const TimestampConverter().fromJson(json['updatedAt'])
  ..deleted = json['deleted'] as bool?;

Map<String, dynamic> _$OrderCommentToJson(OrderComment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'text': instance.text,
      'authorType': instance.authorType,
      'author': instance.author?.toJson(),
      'source': instance.source,
      'shareToken': instance.shareToken,
      'isInternal': instance.isInternal,
      'createdAt': const TimestampConverter().toJson(instance.createdAt),
      'updatedAt': const TimestampConverter().toJson(instance.updatedAt),
      'deleted': instance.deleted,
    };
