import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' show DateFormat;
import 'package:praticos/models/customer_charge.dart';
import 'package:praticos/models/nfse.dart';
import 'package:praticos/models/order_charge.dart';
import 'package:praticos/models/payment_settings.dart';
import 'package:praticos/services/api_headers.dart';

/// Error from the Asaas endpoints of the PraticOS API.
///
/// [message] is raw diagnostic text and must never reach the UI; map
/// [code] with `asaasErrorText` instead.
class AsaasApiException implements Exception {
  final String? code;
  final String message;

  /// Asaas's own text (pt-BR) when it refused something (`error.detail`):
  /// shown on the nota screens, where it says what to fix.
  final String? detail;

  AsaasApiException(this.code, this.message, {this.detail});

  @override
  String toString() => message;
}

typedef ApiHeadersProvider = Future<Map<String, String>> Function();

/// Open order of a customer as the server lists it for "Receber de João":
/// only number, what is open and the date (a consultant sees other people's
/// orders this way, never the whole order).
class CustomerOpenOrder {
  const CustomerOpenOrder({
    required this.id,
    required this.open,
    this.number,
    this.createdAt,
    this.own = false,
  });

  final String id;
  final int? number;
  final double open;
  final DateTime? createdAt;

  /// Created by the user asking.
  final bool own;

  factory CustomerOpenOrder.fromJson(Map<String, dynamic> json) =>
      CustomerOpenOrder(
        id: json['id'] as String? ?? '',
        number: (json['number'] as num?)?.toInt(),
        open: (json['open'] as num?)?.toDouble() ?? 0,
        createdAt: json['createdAt'] is String
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
        own: json['own'] == true,
      );
}

/// Client for the payment endpoints: Asaas connection, order charges, the
/// customer charge of several orders, the server-side customer receipt and
/// the NFS-e (`/v1/app/nfse`, docs/NFSE_ASAAS.md).
///
/// The app never talks to Asaas directly and never keeps the API key.
class AsaasApiService {
  final http.Client _client;
  final ApiHeadersProvider _headersProvider;
  final Duration _timeout;

  AsaasApiService._(
    this._client,
    this._headersProvider, [
    this._timeout = const Duration(seconds: 30),
  ]);

  static final AsaasApiService instance = AsaasApiService._(
    http.Client(),
    () => appApiHeaders(),
  );

  /// Test seam: lets a test inject a mock client and fake headers.
  static AsaasApiService withClient(
    http.Client client, {
    required ApiHeadersProvider headersProvider,
    Duration timeout = const Duration(seconds: 30),
  }) => AsaasApiService._(client, headersProvider, timeout);

  static Map<String, dynamic> _data(String body) {
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    return Map<String, dynamic>.from(decoded['data'] as Map);
  }

  static PaymentSettings parseSettings(String body) =>
      PaymentSettings.fromJson(_data(body));

  static OrderCharge parseCharge(String body) {
    final data = _data(body);
    if (data['id'] == null && data['chargeId'] != null) {
      data['id'] = data['chargeId'];
    }
    return OrderCharge.fromJson(data);
  }

  static CustomerCharge parseCustomerCharge(String body) =>
      CustomerCharge.fromJson(_data(body));

  static List<CustomerOpenOrder> parseOpenOrders(String body) {
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final list = decoded['data'] as List? ?? const [];
    return [
      for (final item in list)
        if (item is Map)
          CustomerOpenOrder.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  static Map<String, dynamic> buildChargeBody({
    required double value,
    required ChargeMode mode,
    int? installmentCount,
    DateTime? dueDate,
    String? customerTaxId,
  }) {
    return {
      'value': (value * 100).round() / 100,
      'mode': mode.name,
      if (mode == ChargeMode.cardInstallments && installmentCount != null)
        'installmentCount': installmentCount,
      if (dueDate != null) 'dueDate': DateFormat('yyyy-MM-dd').format(dueDate),
      if (customerTaxId != null && customerTaxId.isNotEmpty)
        'customerTaxId': customerTaxId,
    };
  }

  Future<Map<String, String>> _headers() async {
    final Map<String, String> headers;
    try {
      headers = await _headersProvider();
    } catch (_) {
      throw AsaasApiException('UNAUTHENTICATED', 'User not authenticated');
    }
    final authorization = headers['Authorization'];
    if (authorization == null || authorization.isEmpty) {
      throw AsaasApiException('UNAUTHENTICATED', 'User not authenticated');
    }
    return {...headers, 'Content-Type': 'application/json'};
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } on TimeoutException {
      throw AsaasApiException('NETWORK_ERROR', 'Request timed out');
    } on http.ClientException catch (e) {
      throw AsaasApiException('NETWORK_ERROR', e.message);
    } on SocketException catch (e) {
      throw AsaasApiException('NETWORK_ERROR', e.message);
    }
  }

  void _ensureOk(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    String message = 'Request failed (${response.statusCode})';
    String? code;
    String? detail;
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final error = decoded['error'] as Map<String, dynamic>?;
      if (error?['message'] is String) message = error!['message'] as String;
      if (error?['code'] is String) code = error!['code'] as String;
      final text = error?['detail'];
      if (text is String && text.trim().isNotEmpty) detail = text.trim();
    } catch (_) {
      // keep the default message and leave code as null
    }
    code ??= switch (response.statusCode) {
      401 => 'UNAUTHENTICATED',
      403 => 'FORBIDDEN',
      429 => 'RATE_LIMIT_EXCEEDED',
      _ => null,
    };
    throw AsaasApiException(code, message, detail: detail);
  }

  /// Validates and stores the company's Asaas API key on the server.
  Future<PaymentSettings> connect(String apiKey) async {
    final headers = await _headers();
    final response = await _send(
      () => _client.post(
        Uri.parse('$appApiBaseUrl/v1/app/payments/asaas/connect'),
        headers: headers,
        body: jsonEncode({'apiKey': apiKey}),
      ),
    );
    _ensureOk(response);
    return parseSettings(response.body);
  }

  Future<void> disconnect() async {
    final headers = await _headers();
    final response = await _send(
      () => _client.delete(
        Uri.parse('$appApiBaseUrl/v1/app/payments/asaas/connect'),
        headers: headers,
      ),
    );
    _ensureOk(response);
  }

  /// Creates an Asaas charge for the order. The server cancels any open
  /// charge of the same order first.
  Future<OrderCharge> createCharge(
    String orderId, {
    required double value,
    required ChargeMode mode,
    int? installmentCount,
    DateTime? dueDate,
    String? customerTaxId,
  }) async {
    final headers = await _headers();
    final body = buildChargeBody(
      value: value,
      mode: mode,
      installmentCount: installmentCount,
      dueDate: dueDate,
      customerTaxId: customerTaxId,
    );
    final response = await _send(
      () => _client.post(
        Uri.parse('$appApiBaseUrl/v1/app/orders/$orderId/charges'),
        headers: headers,
        body: jsonEncode(body),
      ),
    );
    _ensureOk(response);
    return parseCharge(response.body);
  }

  Future<OrderCharge> cancelCharge(String orderId, String chargeId) async {
    final headers = await _headers();
    final response = await _send(
      () => _client.delete(
        Uri.parse('$appApiBaseUrl/v1/app/orders/$orderId/charges/$chargeId'),
        headers: headers,
      ),
    );
    _ensureOk(response);
    return parseCharge(response.body);
  }

  /// One Asaas charge for several orders of [customerId] ("Mandar cobrança"
  /// from "Receber de João"). The server splits [value] oldest order first
  /// and cancels the open charges it replaces.
  Future<CustomerCharge> createCustomerCharge(
    String customerId, {
    required List<String> orderIds,
    required double value,
    DateTime? dueDate,
    String? customerTaxId,
  }) async {
    final headers = await _headers();
    final response = await _send(
      () => _client.post(
        Uri.parse('$appApiBaseUrl/v1/app/customers/$customerId/charges'),
        headers: headers,
        body: jsonEncode({
          'orderIds': orderIds,
          'value': (value * 100).round() / 100,
          if (dueDate != null)
            'dueDate': DateFormat('yyyy-MM-dd').format(dueDate),
          if (customerTaxId != null && customerTaxId.isNotEmpty)
            'customerTaxId': customerTaxId,
        }),
      ),
    );
    _ensureOk(response);
    return parseCustomerCharge(response.body);
  }

  Future<CustomerCharge> cancelCustomerCharge(
    String customerId,
    String chargeId,
  ) async {
    final headers = await _headers();
    final response = await _send(
      () => _client.delete(
        Uri.parse(
          '$appApiBaseUrl/v1/app/customers/$customerId/charges/$chargeId',
        ),
        headers: headers,
      ),
    );
    _ensureOk(response);
    return parseCustomerCharge(response.body);
  }

  /// Open orders of [customerId] (number, open amount, date, own).
  Future<List<CustomerOpenOrder>> listCustomerOpenOrders(
    String customerId,
  ) async {
    final headers = await _headers();
    final response = await _send(
      () => _client.get(
        Uri.parse('$appApiBaseUrl/v1/app/customers/$customerId/open-orders'),
        headers: headers,
      ),
    );
    _ensureOk(response);
    return parseOpenOrders(response.body);
  }

  /// Records a receipt on the server (used when a consultant includes orders
  /// someone else created). Online only; the server validates everything.
  Future<void> registerCustomerReceipt(
    String customerId, {
    required String receiptId,
    required DateTime paidAt,
    required List<({String orderId, double amount})> allocations,
    Map<String, dynamic>? receiptFile,
  }) async {
    final headers = await _headers();
    final response = await _send(
      () => _client.post(
        Uri.parse('$appApiBaseUrl/v1/app/customers/$customerId/receipts'),
        headers: headers,
        body: jsonEncode({
          'receiptId': receiptId,
          'paidAt': paidAt.toUtc().toIso8601String(),
          'allocations': [
            for (final a in allocations)
              {'orderId': a.orderId, 'amount': (a.amount * 100).round() / 100},
          ],
          if (receiptFile != null) 'receiptFile': receiptFile,
        }),
      ),
    );
    _ensureOk(response);
  }

  // ─── NFS-e (nota fiscal de serviço) ───

  Future<Map<String, dynamic>> _nfse(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final headers = await _headers();
    final uri = Uri.parse('$appApiBaseUrl/v1/app/nfse$path');
    final response = await _send(() {
      switch (method) {
        case 'GET':
          return _client.get(uri, headers: headers);
        case 'PUT':
          return _client.put(uri, headers: headers, body: jsonEncode(body));
        default:
          return _client.post(
            uri,
            headers: headers,
            body: jsonEncode(body ?? const {}),
          );
      }
    });
    _ensureOk(response);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'];
    return data is Map ? Map<String, dynamic>.from(data) : {'list': data};
  }

  /// What is filled and what is missing to issue notas (owner/admin).
  Future<NfseSetup> nfseSetup() async =>
      NfseSetup.fromJson(await _nfse('GET', '/setup'));

  /// Saves the company's fiscal info in Asaas (owner/admin).
  Future<NfseSetup> saveNfseFiscalInfo({
    required String email,
    required bool simplesNacional,
    String? municipalInscription,
    String? cnae,
    String? specialTaxRegime,
    String? serviceListItem,
  }) async {
    String? clean(String? v) => (v ?? '').trim().isEmpty ? null : v!.trim();
    final body = <String, dynamic>{
      'email': email.trim(),
      'simplesNacional': simplesNacional,
      if (clean(municipalInscription) != null)
        'municipalInscription': clean(municipalInscription),
      if (clean(cnae) != null) 'cnae': clean(cnae),
      if (clean(specialTaxRegime) != null)
        'specialTaxRegime': clean(specialTaxRegime),
      if (clean(serviceListItem) != null)
        'serviceListItem': clean(serviceListItem),
    };
    return NfseSetup.fromJson(
      await _nfse('POST', '/setup/fiscal-info', body: body),
    );
  }

  /// Services of the city's list matching [query].
  Future<List<NfseMunicipalService>> nfseMunicipalServices(String query) async {
    final q = Uri.encodeQueryComponent(query.trim());
    final data = await _nfse(
      'GET',
      '/setup/municipal-services${q.isEmpty ? '' : '?q=$q'}',
    );
    return [
      for (final item in (data['list'] as List? ?? const []))
        if (item is Map)
          NfseMunicipalService.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  /// Saves the default service of the notas (owner/admin).
  Future<NfseSetup> saveNfseService(NfseServiceSettings service) async =>
      NfseSetup.fromJson(
        await _nfse('PUT', '/setup/service', body: service.toJson()),
      );

  /// What a nota for [orderIds] (one customer) will have.
  Future<NfsePreview> previewInvoice(
    List<String> orderIds, {
    String? customerId,
  }) async => NfsePreview.fromJson(
    await _nfse(
      'POST',
      '/invoices/preview',
      body: {
        'orderIds': orderIds,
        if (customerId != null) 'customerId': customerId,
      },
    ),
  );

  /// Issues one nota for [orderIds]. [effectiveDate] defaults to today on
  /// the server. [customerData]: e-mail/address the city needs, typed in the
  /// sheet (the server sends it to the Asaas customer).
  Future<NfseInvoice> createInvoice(
    List<String> orderIds, {
    String? customerId,
    String? serviceDescription,
    DateTime? effectiveDate,
    String? customerTaxId,
    Map<String, String>? customerData,
  }) async {
    final data = await _nfse(
      'POST',
      '/invoices',
      body: {
        'orderIds': orderIds,
        if (customerId != null) 'customerId': customerId,
        if ((serviceDescription ?? '').trim().isNotEmpty)
          'serviceDescription': serviceDescription!.trim(),
        if (effectiveDate != null)
          'effectiveDate': DateFormat('yyyy-MM-dd').format(effectiveDate),
        if ((customerTaxId ?? '').isNotEmpty) 'customerTaxId': customerTaxId,
        if (customerData != null && customerData.isNotEmpty)
          'customerData': customerData,
      },
    );
    return NfseInvoice.fromJson(data);
  }

  /// Cancels a nota. [onlyOnAsaas]: the city does not cancel through the
  /// integration and the user already canceled it at the city.
  Future<NfseInvoice> cancelInvoice(
    String invoiceId, {
    bool onlyOnAsaas = false,
  }) async => NfseInvoice.fromJson(
    await _nfse(
      'POST',
      '/invoices/$invoiceId/cancel',
      body: {if (onlyOnAsaas) 'onlyOnAsaas': true},
    ),
  );
}
