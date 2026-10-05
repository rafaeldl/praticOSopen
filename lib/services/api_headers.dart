import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:praticos/global.dart';

/// Thrown when there is no signed-in user to authenticate an API call.
class AppApiUnauthenticatedException implements Exception {
  const AppApiUnauthenticatedException();

  @override
  String toString() => 'User not authenticated';
}

/// Firebase ID token of the signed-in user, or null.
Future<String?> defaultIdTokenProvider() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  return user.getIdToken();
}

/// Headers for calls to `/v1/app/*` on the Functions API.
///
/// Sends `X-Company-Id` (the selected company, or [companyId]) so users that
/// belong to several companies don't fall back to the first one on the server.
Future<Map<String, String>> appApiHeaders({
  String? companyId,
  Future<String?> Function()? tokenProvider,
}) async {
  final token = await (tokenProvider ?? defaultIdTokenProvider)();
  if (token == null || token.isEmpty) {
    throw const AppApiUnauthenticatedException();
  }
  final resolvedCompanyId =
      (companyId?.isNotEmpty ?? false) ? companyId : Global.companyAggr?.id;
  return {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
    if (resolvedCompanyId != null && resolvedCompanyId.isNotEmpty)
      'X-Company-Id': resolvedCompanyId,
  };
}

/// Base URL of the PraticOS Functions API (no trailing slash).
///
/// Debug builds: emulator host on Android, ngrok tunnel on the iOS simulator
/// (localhost:5000 conflicts with AirTunes).
String get appApiBaseUrl {
  if (kDebugMode) {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000/praticos/southamerica-east1/api';
    }
    return 'https://acidogenic-lorinda-unnymphean.ngrok-free.dev/praticos/southamerica-east1/api';
  }
  return 'https://southamerica-east1-praticos.cloudfunctions.net/api';
}
