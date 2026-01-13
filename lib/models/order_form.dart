import 'package:json_annotation/json_annotation.dart';
import 'package:praticos/models/form_definition.dart';

part 'order_form.g.dart';

enum FormStatus {
  pending,
  @JsonValue('in_progress')
  inProgress,
  completed,
}

@JsonSerializable(explicitToJson: true)
class OrderForm {
  String id;
  String formDefinitionId;
  String title;
  FormStatus status;
  List<FormItemDefinition> items; // Snapshot dos itens do template
  List<FormResponse> responses;
  DateTime? startedAt;
  DateTime? completedAt;
  DateTime? updatedAt;

  /// i18n translations for title: {'pt': 'Título', 'en': 'Title', 'es': 'Título'}
  Map<String, String>? titleI18n;

  OrderForm({
    required this.id,
    required this.formDefinitionId,
    required this.title,
    this.status = FormStatus.pending,
    this.items = const [],
    this.responses = const [],
    this.startedAt,
    this.completedAt,
    this.updatedAt,
    this.titleI18n,
  });

  factory OrderForm.fromJson(Map<String, dynamic> json) =>
      _$OrderFormFromJson(json);
  Map<String, dynamic> toJson() => _$OrderFormToJson(this);

  /// Returns the localized title for the given locale code (e.g., 'pt', 'en', 'es')
  /// Falls back to the default title if translation is not available
  String getLocalizedTitle(String? localeCode) {
    if (localeCode == null || titleI18n == null) return title;
    return titleI18n![localeCode] ?? titleI18n!['pt'] ?? title;
  }

  /// Retorna a resposta para um determinado item, se existir
  FormResponse? getResponse(String itemId) {
    try {
      return responses.firstWhere((r) => r.itemId == itemId);
    } catch (_) {
      return null;
    }
  }
}

@JsonSerializable(explicitToJson: true)
class FormResponse {
  String itemId;
  dynamic value;
  List<String> photoUrls;

  FormResponse({
    required this.itemId,
    this.value,
    this.photoUrls = const [],
  });

  factory FormResponse.fromJson(Map<String, dynamic> json) =>
      _$FormResponseFromJson(json);
  Map<String, dynamic> toJson() => _$FormResponseToJson(this);
}
