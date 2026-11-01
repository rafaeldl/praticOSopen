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
    this.description,
    this.value,
    this.quantity = 1,
    this.catalogId,
    this.alternatives = const [],
  });

  /// 'service' or 'product'.
  final String kind;
  final String name;

  /// What only this line has ("Para-choque dianteiro"), apart from the name.
  final String? description;

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
    description: _text(json['description']),
    value: (json['value'] as num?)?.toDouble(),
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    catalogId: json['catalogId'] as String?,
    alternatives: [
      for (final a in (json['alternatives'] as List? ?? const []))
        AiCatalogOption.fromJson(Map<String, dynamic>.from(a as Map)),
    ],
  );
}

/// One line already in the order, sent so the assistant can change or remove
/// it ("a pintura é 300", "tira a lavação") instead of adding a new one.
class AiOrderLine {
  const AiOrderLine({
    required this.name,
    this.description,
    this.value,
    this.quantity,
  });

  final String name;
  final String? description;
  final double? value;

  /// Parts only.
  final int? quantity;

  Map<String, dynamic> toJson() => {
    'name': name,
    if (_text(description) case final d?)
      'description': d.length > 200 ? d.substring(0, 200) : d,
    if (value != null) 'value': value,
    if (quantity != null && quantity! > 0) 'quantity': quantity,
  };
}

/// The order lines in screen order. The server refers to them by index.
class AiOrderSnapshot {
  const AiOrderSnapshot({this.services = const [], this.products = const []});

  final List<AiOrderLine> services;
  final List<AiOrderLine> products;

  bool get isEmpty => services.isEmpty && products.isEmpty;

  /// The server takes at most 50 lines of each kind and names up to 200 chars.
  Map<String, dynamic> toJson() {
    List<Map<String, dynamic>> lines(List<AiOrderLine> all) => [
      for (final l in all.take(50))
        if (l.name.trim().isNotEmpty)
          AiOrderLine(
            name: l.name.trim().length > 200
                ? l.name.trim().substring(0, 200)
                : l.name.trim(),
            description: l.description,
            value: l.value,
            quantity: l.quantity,
          ).toJson(),
    ];
    return {'services': lines(services), 'products': lines(products)};
  }
}

/// A line of the order: its kind and its index in [AiOrderSnapshot].
class AiLineRef {
  const AiLineRef({required this.kind, required this.index});

  /// 'service' or 'product'.
  final String kind;
  final int index;

  bool get isProduct => kind == 'product';

  static AiLineRef? fromJson(Object? json) {
    if (json is! Map) return null;
    final index = (json['index'] as num?)?.toInt();
    if (index == null || index < 0) return null;
    return AiLineRef(
      kind: json['kind'] == 'product' ? 'product' : 'service',
      index: index,
    );
  }
}

/// A change the assistant asks for on a line already in the order.
class AiDraftChange {
  const AiDraftChange({
    required this.remove,
    required this.name,
    this.line,
    this.candidates = const [],
    this.value,
    this.quantity,
    this.description,
  });

  /// True = take the line out; false = change [value], [quantity] and/or
  /// [description].
  final bool remove;
  final String name;

  /// Null when it could fit more than one line: ask among [candidates].
  final AiLineRef? line;
  final List<AiLineRef> candidates;
  final double? value;
  final int? quantity;
  final String? description;

  static AiDraftChange? fromJson(Map<String, dynamic> json) {
    final action = json['action'];
    if (action != 'update' && action != 'remove') return null;
    final line = AiLineRef.fromJson(json['line']);
    final candidates = [
      for (final c in (json['candidates'] as List? ?? const []))
        ?AiLineRef.fromJson(c),
    ];
    if (line == null && candidates.length < 2) return null;
    return AiDraftChange(
      remove: action == 'remove',
      name: json['name'] as String? ?? '',
      line: line,
      candidates: line == null ? candidates : const [],
      value: (json['value'] as num?)?.toDouble(),
      quantity: (json['quantity'] as num?)?.toInt(),
      description: _text(json['description']),
    );
  }
}

/// Trimmed text, or null when blank or not a string.
String? _text(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

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

/// Structured draft returned by `aiOrderAssist`: what to add ([items]) and
/// what to change in the lines already in the order ([changes]). The function
/// saves nothing: the app applies it on screen.
class AiOrderDraft {
  const AiOrderDraft({
    this.transcript,
    this.customer,
    this.customerGuess,
    this.customerGuessPhone,
    this.customerOptions = const [],
    this.device,
    this.deviceGuessName,
    this.deviceGuessSerial,
    this.deviceGuessManufacturer,
    this.deviceOptions = const [],
    this.items = const [],
    this.changes = const [],
    this.notes,
    this.dueDate,
    this.used,
    this.limit,
  });

  final String? transcript;
  final AiCustomerHit? customer;

  /// Name heard/read when no registered customer matched.
  final String? customerGuess;
  final String? customerGuessPhone;

  /// Registered customers close to [customerGuess] ("Juliene" → Juliana
  /// Souza, Juliana Lima): the app asks which one, or registers a new one.
  final List<AiCustomerHit> customerOptions;
  final AiDeviceHit? device;
  final String? deviceGuessName;
  final String? deviceGuessSerial;
  final String? deviceGuessManufacturer;

  /// Registered vehicles close to the guess (same model, other plate).
  final List<AiDeviceHit> deviceOptions;
  final List<AiDraftItem> items;

  /// Changes to lines already in the order (only when the order was sent).
  final List<AiDraftChange> changes;
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
      customerGuessPhone: map(customer?['guess'])?['phone'] as String?,
      customerOptions: customerMatch != null
          ? const []
          : [
              for (final a in (customer?['alternatives'] as List? ?? const []))
                if (a is Map)
                  AiCustomerHit.fromJson(Map<String, dynamic>.from(a)),
            ],
      device: deviceMatch == null ? null : AiDeviceHit.fromJson(deviceMatch),
      deviceGuessName: deviceGuess?['name'] as String?,
      deviceGuessSerial: deviceGuess?['serial'] as String?,
      deviceGuessManufacturer: deviceGuess?['manufacturer'] as String?,
      deviceOptions: deviceMatch != null
          ? const []
          : [
              for (final a in (device?['alternatives'] as List? ?? const []))
                if (a is Map)
                  AiDeviceHit.fromJson(Map<String, dynamic>.from(a)),
            ],
      items: [
        for (final i in (json['items'] as List? ?? const []))
          AiDraftItem.fromJson(Map<String, dynamic>.from(i as Map)),
      ],
      changes: [
        for (final c in (json['changes'] as List? ?? const []))
          if (c is Map) ?AiDraftChange.fromJson(Map<String, dynamic>.from(c)),
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

/// Calls `/v1/app/ai/*`. Injected in tests.
abstract class AiOrderAssistClient {
  Future<AiOrderDraft> assist({
    String? text,
    List<AiPhoto> photos = const [],
    String? locale,
    AiOrderSnapshot? order,
  });

  /// Whether the assistant is on for the selected company. Never throws: any
  /// failure (offline, old server, no permission) means off.
  Future<bool> isEnabled();
}

/// `GET /v1/app/ai/status`: is the assistant on, and this month's use.
class AiStatus {
  const AiStatus({required this.enabled, this.used, this.limit});

  static const off = AiStatus(enabled: false);

  final bool enabled;

  /// Requests used this month, when the server sent them.
  final int? used;

  /// Requests allowed per month (-1 = unlimited), when the server sent them.
  final int? limit;
}

/// How long one company's answer to `GET /status` is reused.
const Duration kAiStatusCacheDuration = Duration(minutes: 5);

/// Reads the body of `GET /v1/app/ai/status`: only a 200 with
/// `data.enabled == true` turns the assistant on.
bool parseAiStatusResponse(int status, String body) {
  if (status != 200) return false;
  try {
    final json = jsonDecode(body);
    return json is Map &&
        json['data'] is Map &&
        json['data']['enabled'] == true;
  } catch (_) {
    return false;
  }
}

/// Reads the use of the month out of `GET /v1/app/ai/status`.
AiStatus parseAiStatus(int status, String body) {
  if (!parseAiStatusResponse(status, body)) return AiStatus.off;
  final usage = (jsonDecode(body) as Map)['data']['usage'];
  return AiStatus(
    enabled: true,
    used: usage is Map ? (usage['used'] as num?)?.toInt() : null,
    limit: usage is Map ? (usage['limit'] as num?)?.toInt() : null,
  );
}

class AiOrderAssistService implements AiOrderAssistClient {
  AiOrderAssistService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  /// Last answer per company, shared by every screen (see
  /// [kAiStatusCacheDuration]).
  static final Map<String, ({AiStatus status, DateTime at})> _statusCache = {};

  /// Clears the cached answers (tests, company switch).
  static void clearStatusCache() => _statusCache.clear();

  @override
  Future<bool> isEnabled({DateTime Function() now = DateTime.now}) async =>
      (await status(now: now)).enabled;

  /// On or off and this month's use. Any failure means off.
  Future<AiStatus> status({DateTime Function() now = DateTime.now}) async {
    try {
      final headers = await appApiHeaders();
      final companyId = headers['X-Company-Id'] ?? '';
      final cached = _statusCache[companyId];
      if (cached != null &&
          now().difference(cached.at) < kAiStatusCacheDuration) {
        return cached.status;
      }
      final response = await _client
          .get(Uri.parse('$appApiBaseUrl/v1/app/ai/status'), headers: headers)
          .timeout(const Duration(seconds: 10));
      final status = parseAiStatus(response.statusCode, response.body);
      _statusCache[companyId] = (status: status, at: now());
      return status;
    } catch (_) {
      return AiStatus.off;
    }
  }

  @override
  Future<AiOrderDraft> assist({
    String? text,
    List<AiPhoto> photos = const [],
    String? locale,
    AiOrderSnapshot? order,
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
      if (order != null && !order.isEmpty) 'order': order.toJson(),
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
    final draft = parseAiOrderAssistResponse(response.statusCode, response.body);
    // The use of the month changed: "Plano" reads it again.
    clearStatusCache();
    return draft;
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
