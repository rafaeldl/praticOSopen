import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import 'package:praticos/models/integration_token.dart';
import 'package:praticos/services/api_headers.dart';

class IntegrationApiException implements Exception {
  final String message;
  final String? code;
  IntegrationApiException(this.message, {this.code});

  @override
  String toString() => message;
}

/// Client for /v1/app/integrations — the MCP connection tokens.
class IntegrationApiService {
  final http.Client _client;
  final Future<String?> Function() _tokenProvider;

  IntegrationApiService._(this._client, this._tokenProvider);

  static final IntegrationApiService instance = IntegrationApiService._(
    http.Client(),
    defaultIdTokenProvider,
  );

  /// Test seam: lets a test inject a mock client and a fake auth token.
  static IntegrationApiService withClient(
    http.Client client, {
    required Future<String?> Function() tokenProvider,
  }) =>
      IntegrationApiService._(client, tokenProvider);

  static String get _baseUrl {
    if (kDebugMode) {
      // Use ngrok for iOS simulator (localhost:5000 conflicts with AirTunes)
      // For Android emulator, use 10.0.2.2
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:5000/praticos/southamerica-east1/api';
      }
      // iOS simulator - use ngrok tunnel
      return 'https://acidogenic-lorinda-unnymphean.ngrok-free.dev/praticos/southamerica-east1/api';
    }
    return 'https://southamerica-east1-praticos.cloudfunctions.net/api';
  }

  static List<IntegrationToken> parseList(String body) {
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final data = (decoded['data'] as List<dynamic>? ?? []);
    return data
        .map((e) => IntegrationToken.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static CreatedIntegrationToken parseCreated(String body) {
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    return CreatedIntegrationToken.fromJson(
      decoded['data'] as Map<String, dynamic>,
    );
  }

  Future<Map<String, String>> _headers() async {
    try {
      return await appApiHeaders(tokenProvider: _tokenProvider);
    } on AppApiUnauthenticatedException {
      throw IntegrationApiException('User not authenticated',
          code: 'UNAUTHENTICATED');
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
    throw IntegrationApiException(message, code: code);
  }

  Future<List<IntegrationToken>> list() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/v1/app/integrations/tokens'),
      headers: await _headers(),
    );
    _ensureOk(response);
    return parseList(response.body);
  }

  Future<CreatedIntegrationToken> create({required String name}) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/v1/app/integrations/tokens'),
      headers: await _headers(),
      body: jsonEncode({'name': name}),
    );
    _ensureOk(response);
    return parseCreated(response.body);
  }

  Future<void> revoke(String id) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/v1/app/integrations/tokens/$id'),
      headers: await _headers(),
    );
    _ensureOk(response);
  }
}
