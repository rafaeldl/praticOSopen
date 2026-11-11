// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'work_stage.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderStage _$OrderStageFromJson(Map<String, dynamic> json) => OrderStage()
  ..id = json['id'] as String?
  ..rank = (json['rank'] as num?)?.toDouble()
  ..since = json['since'] == null
      ? null
      : DateTime.parse(json['since'] as String);

Map<String, dynamic> _$OrderStageToJson(OrderStage instance) =>
    <String, dynamic>{
      'id': ?instance.id,
      'rank': ?instance.rank,
      'since': ?instance.since?.toIso8601String(),
    };
