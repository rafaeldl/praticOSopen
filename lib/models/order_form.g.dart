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
  titleI18n: (json['titleI18n'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
  deviceId: json['deviceId'] as String?,
  notes: _notesFromJson(json['notes']),
  aiFilled: (json['aiFilled'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
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
  'titleI18n': instance.titleI18n,
  'deviceId': instance.deviceId,
  'notes': instance.notes.map((k, e) => MapEntry(k, e.toJson())),
  'aiFilled': instance.aiFilled,
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

FormItemNote _$FormItemNoteFromJson(Map<String, dynamic> json) => FormItemNote(
  text: json['text'] as String?,
  ai: json['ai'] as bool? ?? false,
  options: (json['options'] as List<dynamic>?)
      ?.map((e) => FormOptionNote.fromJson(e as Map<String, dynamic>))
      .toList(),
  photos: (json['photos'] as List<dynamic>?)
      ?.map((e) => FormPhotoNote.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$FormItemNoteToJson(FormItemNote instance) =>
    <String, dynamic>{
      'text': instance.text,
      'ai': instance.ai,
      'options': instance.options.map((e) => e.toJson()).toList(),
      'photos': instance.photos.map((e) => e.toJson()).toList(),
    };

FormOptionNote _$FormOptionNoteFromJson(Map<String, dynamic> json) =>
    FormOptionNote(
      option: json['option'] as String,
      text: json['text'] as String,
      ai: json['ai'] as bool? ?? false,
    );

Map<String, dynamic> _$FormOptionNoteToJson(FormOptionNote instance) =>
    <String, dynamic>{
      'option': instance.option,
      'text': instance.text,
      'ai': instance.ai,
    };

FormPhotoNote _$FormPhotoNoteFromJson(Map<String, dynamic> json) =>
    FormPhotoNote(
      url: json['url'] as String,
      text: json['text'] as String,
      ai: json['ai'] as bool? ?? false,
    );

Map<String, dynamic> _$FormPhotoNoteToJson(FormPhotoNote instance) =>
    <String, dynamic>{
      'url': instance.url,
      'text': instance.text,
      'ai': instance.ai,
    };
