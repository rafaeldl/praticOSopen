// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_form.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderForm _$OrderFormFromJson(Map<String, dynamic> json) => OrderForm(
  id: json['id'] as String,
  formDefinitionId: json['formDefinitionId'] as String,
  title: json['title'] as String,
  status:
      $enumDecodeNullable(_$FormStatusEnumMap, json['status']) ??
      FormStatus.pending,
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => FormItemDefinition.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  responses:
      (json['responses'] as List<dynamic>?)
          ?.map((e) => FormResponse.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  startedAt: json['startedAt'] == null
      ? null
      : DateTime.parse(json['startedAt'] as String),
  completedAt: json['completedAt'] == null
      ? null
      : DateTime.parse(json['completedAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
  isRequired: json['isRequired'] as bool? ?? false,
);

Map<String, dynamic> _$OrderFormToJson(OrderForm instance) => <String, dynamic>{
  'id': instance.id,
  'formDefinitionId': instance.formDefinitionId,
  'title': instance.title,
  'status': _$FormStatusEnumMap[instance.status]!,
  'items': instance.items.map((e) => e.toJson()).toList(),
  'responses': instance.responses.map((e) => e.toJson()).toList(),
  'startedAt': instance.startedAt?.toIso8601String(),
  'completedAt': instance.completedAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
  'isRequired': instance.isRequired,
};

const _$FormStatusEnumMap = {
  FormStatus.pending: 'pending',
  FormStatus.inProgress: 'in_progress',
  FormStatus.completed: 'completed',
};

FormResponse _$FormResponseFromJson(Map<String, dynamic> json) => FormResponse(
  itemId: json['itemId'] as String,
  value: json['value'],
  photoUrls:
      (json['photoUrls'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
);

Map<String, dynamic> _$FormResponseToJson(FormResponse instance) =>
    <String, dynamic>{
      'itemId': instance.itemId,
      'value': instance.value,
      'photoUrls': instance.photoUrls,
    };
