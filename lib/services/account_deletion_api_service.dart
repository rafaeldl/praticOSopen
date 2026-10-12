import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;
import 'package:praticos/services/api_headers.dart';

/// Error from `DELETE /v1/app/account` that has no dedicated handling.
///
/// [toString] is shown (cleaned up) by `AccountDeletionFlow.formatError`;
/// network failures contain "network" so the screen shows the localized
/// network message.
class AccountDeletionApiException implements Exception {
  final String? code;
  final String message;

  AccountDeletionApiException(this.code, this.message);

  @override
  String toString() => message;
}

typedef AccountDeletionHeadersProvider = Future<Map<String, String>> Function();

/// Asks the server to delete the signed-in user's account
/// (docs/ACCOUNT_DELETION.md). The server checks the companies, deletes the
/// data and the Firebase Auth user in one request.
///
/// Errors the account deletion screen already handles:
/// - 401 `REQUIRES_RECENT_LOGIN` → `Exception('REQUIRES_RECENT_LOGIN')`
///   (the screen re-authenticates and tries again);
/// - 409 `COMPANY_HAS_MEMBERS` → `Exception(<pt message from the server>)`.
class AccountDeletionApiService {
  static const requiresRecentLogin = 'REQUIRES_RECENT_LOGIN';
  static const companyHasMembers = 'COMPANY_HAS_MEMBERS';

  /// Fallback when the 409 body has no message (same text as the server).
  static const companyHasMembersMessage =
      'Você é o proprietário de uma empresa com outros membros. '
      'Transfira a propriedade ou remova os membros antes de excluir sua conta.';

  final http.Client _client;
  final AccountDeletionHeadersProvider _headersProvider;
  final Duration _timeout;
  final String Function() _baseUrl;

  AccountDeletionApiService._(
    this._client,
    this._headersProvider,
    this._timeout,
    this._baseUrl,
  );

  static final AccountDeletionApiService instance = AccountDeletionApiService._(
    http.Client(),
    () => appApiHeaders(),
    const Duration(seconds: 120),
    () => appApiBaseUrl,
  );

  /// Test seam: lets a test inject a mock client and fake headers.
  static AccountDeletionApiService withClient(
    http.Client client, {
    required AccountDeletionHeadersProvider headersProvider,
    Duration timeout = const Duration(seconds: 120),
    String baseUrl = 'https://api.test',
  }) =>
      AccountDeletionApiService._(client, headersProvider, timeout, () => baseUrl);

  /// Deletes the account. Completes normally when the server confirms (also
  /// when the account was already deleted by an earlier attempt).
  Future<void> deleteAccount() async {
    final Map<String, String> headers;
    try {
      headers = await _headersProvider();
    } catch (_) {
      throw AccountDeletionApiException('UNAUTHENTICATED', 'User not authenticated');
    }

    final http.Response response;
    try {
      response = await _client
          .delete(Uri.parse('${_baseUrl()}/v1/app/account'), headers: headers)
          .timeout(_timeout);
    } on TimeoutException {
      throw AccountDeletionApiException('NETWORK_ERROR', 'network timeout');
    } on http.ClientException {
      throw AccountDeletionApiException('NETWORK_ERROR', 'network error');
    } on SocketException {
      throw AccountDeletionApiException('NETWORK_ERROR', 'network error');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw mapError(response.statusCode, response.body);
  }

  /// Maps an error response to the exception the deletion screen expects.
  static Exception mapError(int statusCode, String body) {
    String? code;
    String? message;
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final error = decoded['error'] as Map<String, dynamic>?;
      if (error?['code'] is String) code = error!['code'] as String;
      if (error?['message'] is String) message = error!['message'] as String;
    } catch (_) {
      // Not JSON: fall back to the status code.
    }

    if (statusCode == 401 && code == requiresRecentLogin) {
      return Exception(requiresRecentLogin);
    }
    if (statusCode == 409 || code == companyHasMembers) {
      return Exception(
        (message != null && message.isNotEmpty)
            ? message
            : companyHasMembersMessage,
      );
    }
    return AccountDeletionApiException(
      code,
      'Request failed ($statusCode)${code != null ? ' $code' : ''}',
    );
  }
}
