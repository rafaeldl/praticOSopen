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

  /// i18n translations for title: {'pt': 'Título', 'en': 'Title', 'es': 'Título'}
  Map<String, String>? titleI18n;

  /// i18n translations for description
  Map<String, String>? descriptionI18n;

  /// Id of the segment's ready-made checklist this one was copied from
  /// ("Usar"). A copy does not count as the company's own checklist (plan
  /// limit); copies of the first access keep the segment's id instead.
  String? sourceTemplateId;

  FormDefinition({
    String? id,
    required this.title,
    this.description,
    this.isActive = true,
    this.items = const [],
    this.titleI18n,
    this.descriptionI18n,
    this.sourceTemplateId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    this.id = id;
    this.createdAt = createdAt;
    this.updatedAt = updatedAt;
  }

  /// Returns the localized title for the given locale code (e.g., 'pt', 'en', 'es')
  /// Falls back to the default title if translation is not available
  String getLocalizedTitle(String? localeCode) {
    if (localeCode == null || titleI18n == null) return title;
    return titleI18n![localeCode] ?? titleI18n!['pt'] ?? title;
  }

  /// Returns the localized description for the given locale code
  /// Falls back to the default description if translation is not available
  String? getLocalizedDescription(String? localeCode) {
    if (localeCode == null || descriptionI18n == null) return description;
    return descriptionI18n![localeCode] ?? descriptionI18n!['pt'] ?? description;
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

  /// A number question that is the device's reading (km, hour meter): its
  /// answer is also the order's reading of the checklist's device, and an
  /// order that already has the reading answers it. Only for number
  /// questions, in segments with a reading field. See
  /// `docs/DEVICE_READING.md`.
  @JsonKey(defaultValue: false, includeToJson: false)
  bool reading;

  /// i18n translations for label: {'pt': 'Label PT', 'en': 'Label EN', 'es': 'Label ES'}
  Map<String, String>? labelI18n;

  /// i18n translations for options: {'pt': ['Opt1', 'Opt2'], 'en': ['Opt1', 'Opt2']}
  Map<String, List<String>>? optionsI18n;

  FormItemDefinition({
    required this.id,
    required this.label,
    required this.type,
    this.options,
    this.required = false,
    this.allowPhotos = true,
    this.reading = false,
    this.labelI18n,
    this.optionsI18n,
  });

  /// Returns the localized label for the given locale code
  String getLocalizedLabel(String? localeCode) {
    if (localeCode == null || labelI18n == null) return label;
    return labelI18n![localeCode] ?? labelI18n!['pt'] ?? label;
  }

  /// Returns the localized options for the given locale code
  List<String>? getLocalizedOptions(String? localeCode) {
    if (localeCode == null || optionsI18n == null) return options;
    return optionsI18n![localeCode] ?? optionsI18n!['pt'] ?? options;
  }

  /// Whether this question is linked to the device's reading.
  bool get isReading => reading && type == FormItemType.number;

  factory FormItemDefinition.fromJson(Map<String, dynamic> json) =>
      _$FormItemDefinitionFromJson(json);
  /// `reading` is written only when true, so templates and snapshots
  /// without it stay as they were.
  Map<String, dynamic> toJson() => {
    ..._$FormItemDefinitionToJson(this),
    if (reading) 'reading': true,
  };
}
