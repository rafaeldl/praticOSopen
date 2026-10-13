import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:praticos/services/api_headers.dart';

/// One photo sent to the assistant (JPEG bytes).
class AiPhoto {
  const AiPhoto(this.bytes, {this.mimeType = 'image/jpeg'});

  final Uint8List bytes;
  final String mimeType;
}

/// Catalog alternative the assistant found for an item.
class AiCatalogOption {
  const AiCatalogOption({required this.id, required this.name, this.value});

  final String id;
  final String name;
  final double? value;

  factory AiCatalogOption.fromJson(Map<String, dynamic> json) =>
      AiCatalogOption(
        id: json['id'] as String,
        name: json['name'] as String,
        value: (json['value'] as num?)?.toDouble(),
      );
}

/// Service or product proposed by the assistant.
class AiDraftItem {
  const AiDraftItem({
    required this.kind,
    required this.name,
    this.value,
    this.quantity = 1,
    this.catalogId,
    this.alternatives = const [],
  });

  /// 'service' or 'product'.
  final String kind;
  final String name;

  /// Null = "sem valor".
  final double? value;
  final int quantity;

  /// Null when nothing in the catalog matched (the item goes in by name only;
  /// the catalog is never filled by the assistant).
  final String? catalogId;
  final List<AiCatalogOption> alternatives;

  bool get isProduct => kind == 'product';

  factory AiDraftItem.fromJson(Map<String, dynamic> json) => AiDraftItem(
    kind: json['kind'] == 'product' ? 'product' : 'service',
    name: json['name'] as String? ?? '',
    value: (json['value'] as num?)?.toDouble(),
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    catalogId: json['catalogId'] as String?,
    alternatives: [
      for (final a in (json['alternatives'] as List? ?? const []))
        AiCatalogOption.fromJson(Map<String, dynamic>.from(a as Map)),
    ],
  );
}

/// Customer registered in the company that the assistant matched.
class AiCustomerHit {
  const AiCustomerHit({required this.id, required this.name, this.phone});

  final String id;
  final String name;
  final String? phone;

  factory AiCustomerHit.fromJson(Map<String, dynamic> json) => AiCustomerHit(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    phone: json['phone'] as String?,
  );
}

/// Device registered in the company that the assistant matched.
class AiDeviceHit {
  const AiDeviceHit({
    required this.id,
    required this.name,
    this.serial,
    this.manufacturer,
  });

  final String id;
  final String name;
  final String? serial;
  final String? manufacturer;

  factory AiDeviceHit.fromJson(Map<String, dynamic> json) => AiDeviceHit(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    serial: json['serial'] as String?,
    manufacturer: json['manufacturer'] as String?,
  );
}

/// Structured draft of a new order returned by `aiOrderAssist`. Nothing is
/// saved: the app fills the blank order and the user taps "Salvar OS".
class AiOrderDraft {
  const AiOrderDraft({
    this.transcript,
    this.customer,
    this.customerGuess,
    this.device,
    this.deviceGuessName,
    this.deviceGuessSerial,
    this.items = const [],
    this.notes,
    this.dueDate,
    this.used,
    this.limit,
  });

  final String? transcript;
  final AiCustomerHit? customer;

  /// Name heard/read when no registered customer matched.
  final String? customerGuess;
  final AiDeviceHit? device;
  final String? deviceGuessName;
  final String? deviceGuessSerial;
  final List<AiDraftItem> items;
  final String? notes;

  /// When the customer wants it ready. Without a spoken time it is 18:00.
  final DateTime? dueDate;
  final int? used;

  /// -1 = unlimited.
  final int? limit;

  factory AiOrderDraft.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? map(Object? v) =>
        v is Map ? Map<String, dynamic>.from(v) : null;
    final customer = map(json['customer']);
    final device = map(json['device']);
    final usage = map(json['usage']);
    final customerMatch = map(customer?['match']);
    final deviceMatch = map(device?['match']);
    final deviceGuess = map(device?['guess']);
    return AiOrderDraft(
      transcript: json['transcript'] as String?,
      customer: customerMatch == null
          ? null
          : AiCustomerHit.fromJson(customerMatch),
      customerGuess: map(customer?['guess'])?['name'] as String?,
      device: deviceMatch == null ? null : AiDeviceHit.fromJson(deviceMatch),
      deviceGuessName: deviceGuess?['name'] as String?,
      deviceGuessSerial: deviceGuess?['serial'] as String?,
      items: [
        for (final i in (json['items'] as List? ?? const []))
          AiDraftItem.fromJson(Map<String, dynamic>.from(i as Map)),
      ],
      notes: json['notes'] as String?,
      dueDate: parseDueDate(json['dueDate']),
      used: (usage?['used'] as num?)?.toInt(),
      limit: (usage?['limit'] as num?)?.toInt(),
    );
  }
}

/// "YYYY-MM-DD" (ready at 18:00) or "YYYY-MM-DDTHH:MM", in local time.
DateTime? parseDueDate(Object? value) {
  if (value is! String) return null;
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}):(\d{2}))?$',
  ).firstMatch(value.trim());
  if (match == null) return null;
  int at(int i) => int.parse(match.group(i)!);
  final hasTime = match.group(4) != null;
  return DateTime(
    at(1),
    at(2),
    at(3),
    hasTime ? at(4) : 18,
    hasTime ? at(5) : 0,
  );
}

/// Error codes from the server (docs/AI_ORDER_ASSIST.md).
enum AiAssistError { disabled, quotaExceeded, unavailable, other }

class AiOrderAssistException implements Exception {
  const AiOrderAssistException(this.error, {this.used, this.limit});

  final AiAssistError error;
  final int? used;
  final int? limit;

  @override
  String toString() => 'AiOrderAssistException($error)';
}

/// Calls `POST /v1/app/ai/order-assist`. Injected in tests.
abstract class AiOrderAssistClient {
  Future<AiOrderDraft> assist({
    String? text,
    List<AiPhoto> photos = const [],
    String? locale,
  });
}

class AiOrderAssistService implements AiOrderAssistClient {
  AiOrderAssistService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<AiOrderDraft> assist({
    String? text,
    List<AiPhoto> photos = const [],
    String? locale,
  }) async {
    final body = <String, dynamic>{
      if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
      if (photos.isNotEmpty)
        'photos': [
          for (final p in photos)
            {'mimeType': p.mimeType, 'data': base64Encode(p.bytes)},
        ],
      if (locale != null && const ['pt', 'en', 'es'].contains(locale))
        'locale': locale,
    };
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$appApiBaseUrl/v1/app/ai/order-assist'),
            headers: await appApiHeaders(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 70));
    } on AppApiUnauthenticatedException {
      rethrow;
    } catch (_) {
      throw const AiOrderAssistException(AiAssistError.unavailable);
    }
    return parseAiOrderAssistResponse(response.statusCode, response.body);
  }
}

/// Maps the HTTP answer to a draft or an [AiOrderAssistException].
AiOrderDraft parseAiOrderAssistResponse(int status, String body) {
  Map<String, dynamic>? json;
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) json = Map<String, dynamic>.from(decoded);
  } catch (_) {}
  if (status == 200 && json?['success'] == true && json?['data'] is Map) {
    return AiOrderDraft.fromJson(Map<String, dynamic>.from(json!['data']));
  }
  final error = json?['error'] is Map ? json!['error'] as Map : const {};
  final details = error['details'] is Map ? error['details'] as Map : const {};
  switch (error['code']) {
    case 'AI_DISABLED':
      throw const AiOrderAssistException(AiAssistError.disabled);
    case 'AI_QUOTA_EXCEEDED':
      throw AiOrderAssistException(
        AiAssistError.quotaExceeded,
        used: (details['used'] as num?)?.toInt(),
        limit: (details['limit'] as num?)?.toInt(),
      );
    case 'AI_UNAVAILABLE':
      throw const AiOrderAssistException(AiAssistError.unavailable);
  }
  throw const AiOrderAssistException(AiAssistError.other);
}
