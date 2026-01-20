import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service for handling Firebase custom claims operations.
///
/// Custom claims are set by a Cloud Function (`updateUserClaims`) that triggers
/// when the user document is updated. Due to latency between Firestore writes
/// and Cloud Function execution, there's a delay before claims are available
/// in the user's token.
///
/// This service provides utilities to wait for claims to be properly set,
/// solving the "first access" problem where users can't access company data
/// immediately after signup/invite acceptance.
class ClaimsService {
  static final ClaimsService _instance = ClaimsService._internal();
  static ClaimsService get instance => _instance;

  ClaimsService._internal();
  factory ClaimsService() => _instance;

  /// Default polling interval in milliseconds.
  static const int _defaultPollInterval = 500;

  /// Default maximum wait time in milliseconds.
  static const int _defaultMaxWaitTime = 10000;

  /// Waits for the user's custom claims to include access to the specified company.
  ///
  /// This method polls the Firebase Auth token until the claims contain the
  /// expected companyId in the `roles` map, or until the timeout is reached.
  ///
  /// **Usage:**
  /// Call this method after operations that modify `user.companies` (which
  /// triggers the Cloud Function to update claims), such as:
  /// - Creating a new company during onboarding
  /// - Accepting an invite to join a company
  ///
  /// **Example:**
  /// ```dart
  /// await userStore.createCompanyForUser(company);
  /// final success = await ClaimsService.instance.waitForCompanyClaim(companyId);
  /// if (!success) {
  ///   // Handle timeout - claims may not be ready yet
  /// }
  /// ```
  ///
  /// [companyId] The company ID that should appear in the user's claims.
  /// [maxWaitTime] Maximum time to wait in milliseconds (default: 10000ms).
  /// [pollInterval] Interval between polling attempts in milliseconds (default: 500ms).
  ///
  /// Returns `true` if the claims were successfully updated within the timeout,
  /// `false` if the timeout was reached without the claims being updated.
  Future<bool> waitForCompanyClaim(
    String companyId, {
    int maxWaitTime = _defaultMaxWaitTime,
    int pollInterval = _defaultPollInterval,
  }) async {
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsedMilliseconds < maxWaitTime) {
      final hasAccess = await _checkCompanyAccess(companyId);
      if (hasAccess) {
        stopwatch.stop();
        debugPrint(
          '[ClaimsService] Claims updated for company $companyId '
          'after ${stopwatch.elapsedMilliseconds}ms',
        );
        return true;
      }

      await Future.delayed(Duration(milliseconds: pollInterval));
    }

    stopwatch.stop();
    debugPrint(
      '[ClaimsService] Timeout waiting for claims for company $companyId '
      'after ${stopwatch.elapsedMilliseconds}ms',
    );
    return false;
  }

  /// Checks if the current user's token contains access to the specified company.
  ///
  /// Forces a token refresh to get the latest claims from the server.
  Future<bool> _checkCompanyAccess(String companyId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Force token refresh to get latest claims
      final tokenResult = await user.getIdTokenResult(true);
      final claims = tokenResult.claims;

      if (claims == null) return false;

      // Check if roles map contains the company
      final roles = claims['roles'];
      if (roles == null || roles is! Map) return false;

      final hasCompany = roles.containsKey(companyId);
      debugPrint(
        '[ClaimsService] Checking claims - roles: $roles, '
        'hasCompany($companyId): $hasCompany',
      );

      return hasCompany;
    } catch (e) {
      debugPrint('[ClaimsService] Error checking claims: $e');
      return false;
    }
  }

  /// Gets the current user's custom claims.
  ///
  /// Forces a token refresh to ensure we have the latest claims.
  /// Returns null if no user is signed in or if there was an error.
  Future<Map<String, dynamic>?> getCurrentClaims() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final tokenResult = await user.getIdTokenResult(true);
      return tokenResult.claims;
    } catch (e) {
      debugPrint('[ClaimsService] Error getting claims: $e');
      return null;
    }
  }

  /// Forces a token refresh without checking claims.
  ///
  /// Use this when you need to refresh the token but don't need to verify
  /// specific claims (e.g., after role changes).
  Future<void> forceTokenRefresh() async {
    try {
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      debugPrint('[ClaimsService] Token refreshed');
    } catch (e) {
      debugPrint('[ClaimsService] Error refreshing token: $e');
    }
  }
}
