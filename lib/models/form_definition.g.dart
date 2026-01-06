// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'form_definition.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FormDefinition _$FormDefinitionFromJson(Map<String, dynamic> json) =>
    FormDefinition(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      items:
          (json['items'] as List<dynamic>?)
              ?.map(
                (e) => FormItemDefinition.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$FormDefinitionToJson(FormDefinition instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'isActive': instance.isActive,
      'items': instance.items.map((e) => e.toJson()).toList(),
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

FormItemDefinition _$FormItemDefinitionFromJson(Map<String, dynamic> json) =>
    FormItemDefinition(
      id: json['id'] as String,
      label: json['label'] as String,
      type: $enumDecode(_$FormItemTypeEnumMap, json['type']),
      options: (json['options'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      required: json['required'] as bool? ?? false,
      allowPhotos: json['allowPhotos'] as bool? ?? true,
    );

Map<String, dynamic> _$FormItemDefinitionToJson(FormItemDefinition instance) =>
    <String, dynamic>{
      'id': instance.id,
      'label': instance.label,
      'type': _$FormItemTypeEnumMap[instance.type]!,
      'options': instance.options,
      'required': instance.required,
      'allowPhotos': instance.allowPhotos,
    };

const _$FormItemTypeEnumMap = {
  FormItemType.text: 'text',
  FormItemType.number: 'number',
  FormItemType.select: 'select',
  FormItemType.checklist: 'checklist',
  FormItemType.photoOnly: 'photo_only',
  FormItemType.boolean: 'boolean',
};
