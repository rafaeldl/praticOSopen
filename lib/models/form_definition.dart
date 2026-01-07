import 'package:json_annotation/json_annotation.dart';
import 'package:praticos/models/base_audit_company.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/models/company.dart';

part 'form_definition.g.dart';

@JsonSerializable(explicitToJson: true)
class FormDefinition extends BaseAuditCompany {
  String title;
  String? description;
  bool isActive;
  List<FormItemDefinition> items;

  FormDefinition({
    String? id,
    required this.title,
    this.description,
    this.isActive = true,
    this.items = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    this.id = id;
    this.createdAt = createdAt;
    this.updatedAt = updatedAt;
  }

  factory FormDefinition.fromJson(Map<String, dynamic> json) =>
      _$FormDefinitionFromJson(json);
  @override
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
