import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' show DateFormat;
import 'package:praticos/models/customer_charge.dart';
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

  AsaasApiException(this.code, this.message);

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
/// customer charge of several orders and the server-side customer receipt.
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
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final error = decoded['error'] as Map<String, dynamic>?;
      if (error?['message'] is String) message = error!['message'] as String;
      if (error?['code'] is String) code = error!['code'] as String;
    } catch (_) {
      // keep the default message and leave code as null
    }
    code ??= switch (response.statusCode) {
      401 => 'UNAUTHENTICATED',
      403 => 'FORBIDDEN',
      429 => 'RATE_LIMIT_EXCEEDED',
      _ => null,
    };
    throw AsaasApiException(code, message);
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
}
