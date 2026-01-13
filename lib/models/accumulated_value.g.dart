// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'accumulated_value.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AccumulatedValue _$AccumulatedValueFromJson(Map<String, dynamic> json) =>
    AccumulatedValue(
      id: json['id'] as String?,
      value: json['value'] as String,
      searchKey: json['searchKey'] as String?,
      usageCount: (json['usageCount'] as num?)?.toInt() ?? 0,
      group: json['group'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$AccumulatedValueToJson(AccumulatedValue instance) =>
    <String, dynamic>{
      'id': instance.id,
      'value': instance.value,
      'searchKey': instance.searchKey,
      'usageCount': instance.usageCount,
      'group': instance.group,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
