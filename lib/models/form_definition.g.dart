// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'form_definition.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FormDefinition _$FormDefinitionFromJson(Map<String, dynamic> json) =>
    FormDefinition(
        id: json['id'] as String?,
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
        titleI18n: (json['titleI18n'] as Map<String, dynamic>?)?.map(
          (k, e) => MapEntry(k, e as String),
        ),
        descriptionI18n: (json['descriptionI18n'] as Map<String, dynamic>?)
            ?.map((k, e) => MapEntry(k, e as String)),
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.parse(json['createdAt'] as String),
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.parse(json['updatedAt'] as String),
      )
      ..createdBy = json['createdBy'] == null
          ? null
          : UserAggr.fromJson(json['createdBy'] as Map<String, dynamic>)
      ..updatedBy = json['updatedBy'] == null
          ? null
          : UserAggr.fromJson(json['updatedBy'] as Map<String, dynamic>)
      ..company = json['company'] == null
          ? null
          : CompanyAggr.fromJson(json['company'] as Map<String, dynamic>);

Map<String, dynamic> _$FormDefinitionToJson(FormDefinition instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt?.toIso8601String(),
      'createdBy': instance.createdBy?.toJson(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'updatedBy': instance.updatedBy?.toJson(),
      'company': instance.company?.toJson(),
      'title': instance.title,
      'description': instance.description,
      'isActive': instance.isActive,
      'items': instance.items.map((e) => e.toJson()).toList(),
      'titleI18n': instance.titleI18n,
      'descriptionI18n': instance.descriptionI18n,
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
      labelI18n: (json['labelI18n'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      optionsI18n: (json['optionsI18n'] as Map<String, dynamic>?)?.map(
        (k, e) =>
            MapEntry(k, (e as List<dynamic>).map((e) => e as String).toList()),
      ),
    );

Map<String, dynamic> _$FormItemDefinitionToJson(FormItemDefinition instance) =>
    <String, dynamic>{
      'id': instance.id,
      'label': instance.label,
      'type': _$FormItemTypeEnumMap[instance.type]!,
      'options': instance.options,
      'required': instance.required,
      'allowPhotos': instance.allowPhotos,
      'labelI18n': instance.labelI18n,
      'optionsI18n': instance.optionsI18n,
    };

const _$FormItemTypeEnumMap = {
  FormItemType.text: 'text',
  FormItemType.number: 'number',
  FormItemType.select: 'select',
  FormItemType.checklist: 'checklist',
  FormItemType.photoOnly: 'photo_only',
  FormItemType.boolean: 'boolean',
};
