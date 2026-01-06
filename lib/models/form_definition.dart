import 'package:json_annotation/json_annotation.dart';

part 'form_definition.g.dart';

@JsonSerializable(explicitToJson: true)
class FormDefinition {
  String id;
  String title;
  String? description;
  bool isActive;
  List<FormItemDefinition> items;
  DateTime? createdAt;
  DateTime? updatedAt;

  FormDefinition({
    required this.id,
    required this.title,
    this.description,
    this.isActive = true,
    this.items = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory FormDefinition.fromJson(Map<String, dynamic> json) =>
      _$FormDefinitionFromJson(json);
  Map<String, dynamic> toJson() => _$FormDefinitionToJson(this);
}

enum FormItemType {
  text,
  number,
  select,
  checklist,
  @JsonValue('photo_only')
  photoOnly,
  boolean,
}

@JsonSerializable(explicitToJson: true)
class FormItemDefinition {
  String id;
  String label;
  FormItemType type;
  List<String>? options;
  bool required;
  bool allowPhotos;

  FormItemDefinition({
    required this.id,
    required this.label,
    required this.type,
    this.options,
    this.required = false,
    this.allowPhotos = true,
  });

  factory FormItemDefinition.fromJson(Map<String, dynamic> json) =>
      _$FormItemDefinitionFromJson(json);
  Map<String, dynamic> toJson() => _$FormItemDefinitionToJson(this);
}
