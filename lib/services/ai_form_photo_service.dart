import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/models/order_form.dart';
import 'package:praticos/services/ai_order_assist_service.dart';
import 'package:praticos/services/api_headers.dart';

/// Why the AI could not read a checklist photo.
enum AiPhotoIssue { dark, blurry, offTarget }

/// The question sent with the photo: its label in the person's language and
/// the options as saved (the answer comes back as one of them).
class AiFormQuestion {
  const AiFormQuestion({required this.label, required this.type, this.options});

  final String label;
  final FormItemType type;
  final List<String>? options;

  static const _types = {
    FormItemType.text: 'text',
    FormItemType.number: 'number',
    FormItemType.select: 'select',
    FormItemType.checklist: 'checklist',
    FormItemType.photoOnly: 'photo_only',
    FormItemType.boolean: 'boolean',
  };

  Map<String, dynamic> toJson() => {
    'label': label.length > 300 ? label.substring(0, 300) : label,
    'type': _types[type],
    if (options != null && options!.isNotEmpty)
      'options': [
        for (final o in options!.take(50))
          if (o.trim().isNotEmpty)
            o.trim().length > 200 ? o.trim().substring(0, 200) : o.trim(),
      ],
  };
}

/// What `POST /v1/app/ai/form-photo` read (docs/AI_ORDER_ASSIST.md). Fields
/// without a value do not come; the server already dropped an answer outside
/// the options or given without confidence.
class AiFormPhotoResult {
  const AiFormPhotoResult({
    this.answer,
    this.note,
    this.optionNotes = const [],
    this.photoNote,
    this.photoIssue,
    this.confident = false,
    this.used,
    this.limit,
  });

  /// String, number, bool or list of strings, by the question's type.
  final Object? answer;
  final String? note;
  final List<({String option, String text})> optionNotes;
  final String? photoNote;
  final AiPhotoIssue? photoIssue;
  final bool confident;
  final int? used;
  final int? limit;

  factory AiFormPhotoResult.fromJson(Map<String, dynamic> json) {
    String? text(Object? v) =>
        v is String && v.trim().isNotEmpty ? v.trim() : null;
    final usage = json['usage'] is Map ? json['usage'] as Map : const {};
    return AiFormPhotoResult(
      answer: json['answer'],
      note: text(json['note']),
      optionNotes: [
        for (final o in (json['optionNotes'] as List? ?? const []))
          if (o is Map && text(o['option']) != null && text(o['text']) != null)
            (option: text(o['option'])!, text: text(o['text'])!),
      ],
      photoNote: text(json['photoNote']),
      photoIssue: switch (json['photoIssue']) {
        'dark' => AiPhotoIssue.dark,
        'blurry' => AiPhotoIssue.blurry,
        'off_target' => AiPhotoIssue.offTarget,
        _ => null,
      },
      confident: json['confident'] == true,
      used: (usage['used'] as num?)?.toInt(),
      limit: (usage['limit'] as num?)?.toInt(),
    );
  }
}

/// Reads a checklist photo. Injected in tests.
abstract class AiFormPhotoClient {
  /// Whether the AI is on for the company (same answer as the order's).
  /// Never throws: any failure means off.
  Future<bool> isEnabled();

  /// Throws [AiOrderAssistException] (same codes as the order's assistant).
  Future<AiFormPhotoResult> read({
    required AiPhoto photo,
    required AiFormQuestion question,
    String? deviceCategory,
    String? deviceName,
    String? segment,
    String? locale,
    ({int value, String? unit})? lastReading,
  });
}

/// Body of the request; no customer, phone, plate or serial goes in it.
Map<String, dynamic> aiFormPhotoBody({
  required AiPhoto photo,
  required AiFormQuestion question,
  String? deviceCategory,
  String? deviceName,
  String? segment,
  String? locale,
  ({int value, String? unit})? lastReading,
}) {
  String? cut(String? s, int max) {
    final t = s?.trim() ?? '';
    if (t.isEmpty) return null;
    return t.length > max ? t.substring(0, max) : t;
  }

  final category = cut(deviceCategory, 60);
  final name = cut(deviceName, 120);
  final unit = cut(lastReading?.unit, 20);
  return {
    'photo': {'mimeType': photo.mimeType, 'data': base64Encode(photo.bytes)},
    'question': question.toJson(),
    if (category != null || name != null)
      'device': {'category': ?category, 'name': ?name},
    if (cut(segment, 60) case final s?) 'segment': s,
    if (locale != null && const ['pt', 'en', 'es'].contains(locale))
      'locale': locale,
    if (lastReading != null && lastReading.value >= 0)
      'lastReading': {'value': lastReading.value, 'unit': ?unit},
  };
}

/// Maps the HTTP answer to a result or an [AiOrderAssistException].
AiFormPhotoResult parseAiFormPhotoResponse(int status, String body) {
  Map<String, dynamic>? json;
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) json = Map<String, dynamic>.from(decoded);
  } catch (_) {}
  if (status == 200 && json?['success'] == true && json?['data'] is Map) {
    return AiFormPhotoResult.fromJson(Map<String, dynamic>.from(json!['data']));
  }
  // Same error codes as the order's assistant.
  parseAiOrderAssistResponse(status, body);
  throw const AiOrderAssistException(AiAssistError.other);
}

class AiFormPhotoService implements AiFormPhotoClient {
  AiFormPhotoService({http.Client? client, AiOrderAssistService? status})
    : _client = client ?? http.Client(),
      _status = status ?? AiOrderAssistService(client: client);

  final http.Client _client;
  final AiOrderAssistService _status;

  @override
  Future<bool> isEnabled() => _status.isEnabled();

  @override
  Future<AiFormPhotoResult> read({
    required AiPhoto photo,
    required AiFormQuestion question,
    String? deviceCategory,
    String? deviceName,
    String? segment,
    String? locale,
    ({int value, String? unit})? lastReading,
  }) async {
    final body = aiFormPhotoBody(
      photo: photo,
      question: question,
      deviceCategory: deviceCategory,
      deviceName: deviceName,
      segment: segment,
      locale: locale,
      lastReading: lastReading,
    );
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$appApiBaseUrl/v1/app/ai/form-photo'),
            headers: await appApiHeaders(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));
    } on AppApiUnauthenticatedException {
      rethrow;
    } catch (_) {
      throw const AiOrderAssistException(AiAssistError.unavailable);
    }
    final result = parseAiFormPhotoResponse(response.statusCode, response.body);
    // The use of the month changed: "Plano" reads it again.
    AiOrderAssistService.clearStatusCache();
    return result;
  }
}

/// [raw] (the AI's answer) as the question saves it, or null when it does
/// not fit: yes/no as bool, an option as its saved text, multiple choice as
/// the saved options, a number or text as typed text.
Object? aiAnswerValue(FormItemDefinition item, Object? raw) {
  if (raw == null) return null;
  final options = item.options ?? const <String>[];
  String? option(Object? v) {
    if (v is! String) return null;
    final t = v.trim().toLowerCase();
    for (final o in options) {
      if (o.trim().toLowerCase() == t) return o;
    }
    return null;
  }

  switch (item.type) {
    case FormItemType.boolean:
      if (raw is bool) return raw;
      if (raw is String) {
        final t = raw.trim().toLowerCase();
        if (t == 'true') return true;
        if (t == 'false') return false;
      }
      return null;
    case FormItemType.select:
      return option(raw);
    case FormItemType.checklist:
      if (raw is! List) return null;
      final marked = <String>[];
      for (final v in raw) {
        final o = option(v);
        if (o != null && !marked.contains(o)) marked.add(o);
      }
      return marked.isEmpty ? null : marked;
    case FormItemType.number:
      final n = raw is num
          ? raw
          : raw is String
          ? num.tryParse(raw.trim().replaceAll(' ', ''))
          : null;
      if (n == null || !n.isFinite) return null;
      return n == n.roundToDouble() ? '${n.round()}' : '$n';
    case FormItemType.text:
      return raw is String && raw.trim().isNotEmpty ? raw.trim() : null;
    case FormItemType.photoOnly:
      return null;
  }
}

bool _sameAnswer(Object? a, Object? b) {
  if (a is List && b is List) {
    final x = a.map((e) => e.toString()).toSet();
    final y = b.map((e) => e.toString()).toSet();
    return x.length == y.length && x.containsAll(y);
  }
  return a?.toString().trim() == b?.toString().trim();
}

bool _hasAnswer(FormItemDefinition item, FormResponse? response) {
  final value = response?.value;
  if (value == null) return false;
  if (value is List) return value.isNotEmpty;
  return value.toString().trim().isNotEmpty;
}

/// What to do with what the AI read for [item] (spec
/// 2026-11-10-checklist-ia-foto-design §3): fill only what is empty, never
/// rewrite what is there.
class AiFormPhotoPlan {
  const AiFormPhotoPlan({
    this.answer,
    this.answerSeen,
    this.note,
    this.extra,
    this.issue,
  });

  /// The answer to save (the question had none), or null.
  final Object? answer;

  /// The AI's answer when the question already had a different one: told,
  /// never put in its place.
  final Object? answerSeen;

  /// The question's note with what the AI wrote in the empty places, or
  /// null when nothing changes.
  final FormItemNote? note;

  /// What the AI saw where the person already wrote: offered ("A IA viu
  /// também: …") to be added to the question's note.
  final String? extra;

  /// Bad photo: nothing is filled.
  final AiPhotoIssue? issue;

  bool get filled => answer != null || note != null;
  bool get isEmpty =>
      !filled && answerSeen == null && extra == null && issue == null;
}

/// Plans how [result] fills [item], which had [response] and [note] when
/// the AI answered, for the photo at [photoUrl].
AiFormPhotoPlan planAiFormPhoto({
  required FormItemDefinition item,
  required FormResponse? response,
  required FormItemNote? note,
  required String photoUrl,
  required AiFormPhotoResult result,
}) {
  if (result.photoIssue != null) {
    return AiFormPhotoPlan(issue: result.photoIssue);
  }

  Object? answer;
  Object? answerSeen;
  final value = aiAnswerValue(item, result.answer);
  if (value != null) {
    if (!_hasAnswer(item, response)) {
      answer = value;
    } else if (!_sameAnswer(value, response?.value)) {
      answerSeen = value;
    }
  }

  final extras = <String>[];
  bool covers(String? written, String seen) {
    final w = written?.trim().toLowerCase() ?? '';
    return w.contains(seen.trim().toLowerCase());
  }

  var changed = false;
  String? text = note?.text;
  var textAi = note?.ai ?? false;
  if (result.note case final seen?) {
    if (text == null || text.trim().isEmpty) {
      text = seen;
      textAi = true;
      changed = true;
    } else if (!covers(text, seen)) {
      extras.add(seen);
    }
  }

  final options = [...?note?.options];
  if (item.type == FormItemType.checklist) {
    for (final o in result.optionNotes) {
      final saved = (item.options ?? const <String>[])
          .where((x) => x.trim().toLowerCase() == o.option.toLowerCase())
          .firstOrNull;
      if (saved == null) continue;
      final written = note?.optionText(saved);
      if (written == null) {
        options.removeWhere((x) => x.option == saved);
        options.add(FormOptionNote(option: saved, text: o.text, ai: true));
        changed = true;
      } else if (!covers(written, o.text)) {
        extras.add(o.text);
      }
    }
  }

  final photos = [...?note?.photos];
  if (result.photoNote case final seen?) {
    final written = note?.photoText(photoUrl);
    if (written == null) {
      photos.removeWhere((p) => p.url == photoUrl);
      photos.add(FormPhotoNote(url: photoUrl, text: seen, ai: true));
      changed = true;
    } else if (!covers(written, seen)) {
      extras.add(seen);
    }
  }

  return AiFormPhotoPlan(
    answer: answer,
    answerSeen: answerSeen,
    note: changed
        ? FormItemNote(text: text, ai: textAi, options: options, photos: photos)
        : null,
    extra: extras.isEmpty ? null : extras.join('. '),
  );
}

/// The question's note with [extra] added after what the person wrote
/// ("Acrescentar"): the text is the person's from then on.
FormItemNote appendToNote(FormItemNote? note, String extra) {
  final text = note?.text?.trim() ?? '';
  final joined = text.isEmpty
      ? extra
      : '$text${RegExp(r'[.!?]$').hasMatch(text) ? '' : '.'} $extra';
  return FormItemNote(
    text: joined,
    options: [...?note?.options],
    photos: [...?note?.photos],
  );
}
