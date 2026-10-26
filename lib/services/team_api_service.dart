import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:praticos/models/collaborator_exception.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/services/api_headers.dart';

/// Client for /v1/app/team — role change and removal of a team member.
///
/// The server updates the membership, the member's `users/{uid}.companies`
/// and their `roles` claim together; the app can't write another user's doc.
/// Known server refusals become a [CollaboratorException].
class TeamApiService {
  final http.Client _client;
  final Future<String?> Function() _tokenProvider;

  TeamApiService._(this._client, this._tokenProvider);

  static final TeamApiService instance = TeamApiService._(
    http.Client(),
    defaultIdTokenProvider,
  );

  /// Test seam: lets a test inject a mock client and a fake auth token.
  static TeamApiService withClient(
    http.Client client, {
    required Future<String?> Function() tokenProvider,
  }) =>
      TeamApiService._(client, tokenProvider);

  static String get _baseUrl => appApiBaseUrl;

  Uri _memberUri(String userId) => Uri.parse(
      '$_baseUrl/v1/app/team/members/${Uri.encodeComponent(userId)}');

  Future<Map<String, String>> _headers() async {
    try {
      return await appApiHeaders(tokenProvider: _tokenProvider);
    } on AppApiUnauthenticatedException {
      throw CollaboratorException(CollaboratorErrorCode.requestFailed);
    }
  }

  Future<void> changeRole(String userId, RolesType role) async {
    final response = await _client.patch(
      _memberUri(userId),
      headers: await _headers(),
      body: jsonEncode({'role': role.name}),
    );
    _ensureOk(response, removal: false);
  }

  Future<void> removeMember(String userId) async {
    final response = await _client.delete(
      _memberUri(userId),
      headers: await _headers(),
    );
    _ensureOk(response, removal: true);
  }

  static void _ensureOk(http.Response response, {required bool removal}) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw CollaboratorException(
      errorCodeFor(response, removal: removal),
    );
  }

  /// Maps a failed response to the code the screen shows a message for.
  static CollaboratorErrorCode errorCodeFor(
    http.Response response, {
    required bool removal,
  }) {
    String? code;
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      code = (decoded['error'] as Map<String, dynamic>?)?['code'] as String?;
    } catch (_) {
      // not JSON: fall back to the status code
    }
    switch (code) {
      case 'OWNER_PROTECTED':
        return CollaboratorErrorCode.cannotChangeOwner;
      case 'LAST_ADMIN':
        return removal
            ? CollaboratorErrorCode.cannotRemoveOnlyAdmin
            : CollaboratorErrorCode.cannotChangeOnlyAdminRole;
      case 'MEMBER_NOT_FOUND':
        return CollaboratorErrorCode.userNotFound;
    }
    if (response.statusCode == 403) return CollaboratorErrorCode.notAllowed;
    return CollaboratorErrorCode.requestFailed;
  }
}
