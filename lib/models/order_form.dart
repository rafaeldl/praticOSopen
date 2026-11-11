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

  /// ID of the linked device (null = global/no device)
  String? deviceId;

  /// Notes by question id, outside [responses] (older apps and the web
  /// rewrite each response with only `itemId`, `value` and `photoUrls`, and
  /// the app's offline write removes the exact response object). Saved only
  /// with an update of `notes.{itemId}` ([FormsService.saveNote]).
  @JsonKey(fromJson: _notesFromJson)
  Map<String, FormItemNote> notes;

  /// Questions whose answer came from the AI and was not changed since.
  List<String> aiFilled;

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
    this.deviceId,
    Map<String, FormItemNote>? notes,
    List<String>? aiFilled,
  }) : notes = notes ?? {},
       aiFilled = aiFilled ?? [];

  factory OrderForm.fromJson(Map<String, dynamic> json) =>
      _$OrderFormFromJson(json);
  Map<String, dynamic> toJson() => _$OrderFormToJson(this);

  /// Returns the localized title for the given locale code (e.g., 'pt', 'en', 'es')
  /// Falls back to the default title if translation is not available
  String getLocalizedTitle(String? localeCode) {
    if (localeCode == null || titleI18n == null) return title;
    return titleI18n![localeCode] ?? titleI18n!['pt'] ?? title;
  }

  /// Retorna a resposta para um determinado item, se existir. With the
  /// question twice in the list, the first one, as the web, the bot and
  /// older apps read it.
  FormResponse? getResponse(String itemId) {
    for (final r in responses) {
      if (r.itemId == itemId) return r;
    }
    return null;
  }

  /// The note of question [itemId], if any.
  FormItemNote? noteOf(String itemId) => notes[itemId];
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

/// Reads `notes` leaving out what is not a note, so a bad entry never hides
/// the checklist.
Map<String, FormItemNote> _notesFromJson(Object? json) {
  if (json is! Map) return {};
  final notes = <String, FormItemNote>{};
  json.forEach((key, value) {
    if (value is! Map) return;
    try {
      notes[key.toString()] = FormItemNote.fromJson(
        Map<String, dynamic>.from(value),
      );
    } catch (_) {
      // Not a note this app knows: left out.
    }
  });
  return notes;
}

/// Note of one question ("Amassado na porta traseira esquerda"), of the
/// options marked in a multiple choice question (key: the option as saved in
/// `value`, the template's original text) and of each photo (key: its URL,
/// the same as in `photoUrls`). [ai] is true while the text is the AI's;
/// the person's first edit saves false.
@JsonSerializable(explicitToJson: true)
class FormItemNote {
  String? text;
  bool ai;
  List<FormOptionNote> options;
  List<FormPhotoNote> photos;

  FormItemNote({
    this.text,
    this.ai = false,
    List<FormOptionNote>? options,
    List<FormPhotoNote>? photos,
  }) : options = options ?? [],
       photos = photos ?? [];

  factory FormItemNote.fromJson(Map<String, dynamic> json) =>
      _$FormItemNoteFromJson(json);
  Map<String, dynamic> toJson() => _$FormItemNoteToJson(this);

  /// Note of option [option] (the saved value), if written.
  String? optionText(String option) {
    for (final o in options) {
      if (o.option == option && o.text.trim().isNotEmpty) return o.text;
    }
    return null;
  }

  /// Note of the photo at [url], if written.
  String? photoText(String url) {
    for (final p in photos) {
      if (p.url == url && p.text.trim().isNotEmpty) return p.text;
    }
    return null;
  }

  /// Whether nothing is written (the note can be removed).
  bool get isEmpty =>
      (text?.trim().isEmpty ?? true) &&
      options.every((o) => o.text.trim().isEmpty) &&
      photos.every((p) => p.text.trim().isEmpty);

  /// A copy without the note of the photo at [url] (the photo was removed).
  FormItemNote withoutPhoto(String url) => FormItemNote(
    text: text,
    ai: ai,
    options: [for (final o in options) FormOptionNote.fromJson(o.toJson())],
    photos: [
      for (final p in photos)
        if (p.url != url) FormPhotoNote.fromJson(p.toJson()),
    ],
  );
}

@JsonSerializable()
class FormOptionNote {
  String option;
  String text;
  bool ai;

  FormOptionNote({required this.option, required this.text, this.ai = false});

  factory FormOptionNote.fromJson(Map<String, dynamic> json) =>
      _$FormOptionNoteFromJson(json);
  Map<String, dynamic> toJson() => _$FormOptionNoteToJson(this);
}

@JsonSerializable()
class FormPhotoNote {
  String url;
  String text;
  bool ai;

  FormPhotoNote({required this.url, required this.text, this.ai = false});

  factory FormPhotoNote.fromJson(Map<String, dynamic> json) =>
      _$FormPhotoNoteFromJson(json);
  Map<String, dynamic> toJson() => _$FormPhotoNoteToJson(this);
}
