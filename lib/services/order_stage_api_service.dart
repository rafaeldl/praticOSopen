import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:praticos/services/api_headers.dart';

/// The server refused or could not take the stage change.
class OrderStageApiException implements Exception {
  const OrderStageApiException(this.statusCode, {this.code});

  final int? statusCode;
  final String? code;

  @override
  String toString() => 'Could not set the stage ($statusCode ${code ?? ''})';
}

/// Client for `PUT /v1/app/orders/:id/stage` (docs/WORK_STAGES.md): the
/// server checks the permission, writes the stage and leaves the internal
/// comment "Etapa: X".
class OrderStageApiService {
  OrderStageApiService._(this._client, this._tokenProvider);

  final http.Client _client;
  final Future<String?> Function() _tokenProvider;

  static final OrderStageApiService instance = OrderStageApiService._(
    http.Client(),
    defaultIdTokenProvider,
  );

  /// Test seam: lets a test inject a mock client and a fake auth token.
  static OrderStageApiService withClient(
    http.Client client, {
    required Future<String?> Function() tokenProvider,
  }) => OrderStageApiService._(client, tokenProvider);

  /// Moves the order to [stageId], at the end of that stage.
  Future<void> setStage(
    String companyId,
    String orderId,
    String stageId,
  ) async {
    final Map<String, String> headers;
    try {
      headers = await appApiHeaders(
        companyId: companyId,
        tokenProvider: _tokenProvider,
      );
    } on AppApiUnauthenticatedException {
      throw const OrderStageApiException(401, code: 'UNAUTHENTICATED');
    }
    final response = await _client.put(
      Uri.parse(
        '$appApiBaseUrl/v1/app/orders/${Uri.encodeComponent(orderId)}/stage',
      ),
      headers: headers,
      body: jsonEncode({'stageId': stageId}),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String? code;
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      code = (decoded['error'] as Map<String, dynamic>?)?['code'] as String?;
    } catch (_) {
      // not JSON: the status code is enough
    }
    throw OrderStageApiException(response.statusCode, code: code);
  }
}
