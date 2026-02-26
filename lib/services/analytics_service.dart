import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Centralized analytics service for Firebase Analytics.
///
/// Singleton pattern (same as FormatService, SegmentConfigService).
/// All methods are fire-and-forget — they never block the UI.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  static AnalyticsService get instance => _instance;
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Fire-and-forget wrapper. Never throws, never blocks UI.
  void _safe(Future<void> Function() fn) {
    fn().catchError((e, stack) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'AnalyticsService',
        fatal: false,
      );
    });
  }

  /// Detects auth method from current user's providerData.
  static String getAuthMethod() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'unknown';

    for (final provider in user.providerData) {
      switch (provider.providerId) {
        case 'google.com':
          return 'google';
        case 'apple.com':
          return 'apple';
        case 'password':
          return 'email';
        case 'phone':
          return 'phone';
      }
    }
    return 'unknown';
  }

  // ═══════════════════════════════════════════════════════════════════
  // User Identity
  // ═══════════════════════════════════════════════════════════════════

  /// Sets userId, user properties and default event parameters.
  /// Called after successful login with company data.
  void identifyUser({
    required String userId,
    String? companyId,
    String? segment,
    String? userRole,
  }) {
    _safe(() async {
      await _analytics.setUserId(id: userId);
      await _analytics.setUserProperty(
        name: 'company_id',
        value: companyId,
      );
      await _analytics.setUserProperty(
        name: 'segment',
        value: segment,
      );
      await _analytics.setUserProperty(
        name: 'user_role',
        value: userRole,
      );
      await _analytics.setDefaultEventParameters({
        'company_id': companyId,
        'segment': segment,
      });
    });
  }

  /// Clears user identity on logout.
  void clearUser() {
    _safe(() async {
      await _analytics.setUserId(id: null);
      await _analytics.setDefaultEventParameters({
        'company_id': null,
        'segment': null,
      });
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // P1 — Install → Activation Funnel
  // ═══════════════════════════════════════════════════════════════════

  /// Logs a login event (Firebase built-in).
  void logLogin({required String method, bool hasCompany = true}) {
    _safe(() => _analytics.logLogin(loginMethod: method, parameters: {
      'has_company': hasCompany.toString(),
    }));
  }

  /// Logs a sign_up event (Firebase built-in).
  void logSignUp({required String method}) {
    _safe(() => _analytics.logSignUp(signUpMethod: method));
  }

  /// Logs tutorial_begin (Firebase built-in).
  /// [variant] differentiates "setup" (full onboarding) vs "skip" (quick start).
  void logTutorialBegin({required String variant}) {
    _safe(() => _analytics.logTutorialBegin(parameters: {
      'variant': variant,
    }));
  }

  /// Logs tutorial_complete (Firebase built-in).
  void logTutorialComplete() {
    _safe(() => _analytics.logTutorialComplete());
  }

  /// Logs company_created custom event.
  void logCompanyCreated({
    String? companyId,
    String? segment,
  }) {
    _safe(() => _analytics.logEvent(
      name: 'company_created',
      parameters: {
        if (companyId != null) 'company_id': companyId,
        if (segment != null) 'segment': segment,
      },
    ));
  }

  // ═══════════════════════════════════════════════════════════════════
  // P2 — Engagement & Activation
  // ═══════════════════════════════════════════════════════════════════

  /// Logs order_created custom event.
  void logOrderCreated({
    String? orderId,
    String? customerId,
    int deviceCount = 0,
    int itemCount = 0,
    double? totalValue,
  }) {
    _safe(() => _analytics.logEvent(
      name: 'order_created',
      parameters: {
        if (orderId != null) 'order_id': orderId,
        if (customerId != null) 'customer_id': customerId,
        'device_count': deviceCount,
        'item_count': itemCount,
        if (totalValue != null) 'total_value': totalValue,
      },
    ));
  }

  /// Logs customer_created custom event.
  void logCustomerCreated({String? customerId}) {
    _safe(() => _analytics.logEvent(
      name: 'customer_created',
      parameters: {
        if (customerId != null) 'customer_id': customerId,
      },
    ));
  }

  /// Logs share event (Firebase built-in).
  void logShare({required String method, required String contentType}) {
    _safe(() => _analytics.logShare(
      contentType: contentType,
      itemId: '',
      method: method,
    ));
  }

  // ═══════════════════════════════════════════════════════════════════
  // P3 — Feature Adoption
  // ═══════════════════════════════════════════════════════════════════

  /// Logs photo_uploaded custom event.
  void logPhotoUploaded({required String source}) {
    _safe(() => _analytics.logEvent(
      name: 'photo_uploaded',
      parameters: {
        'source': source,
      },
    ));
  }

  /// Logs payment_added custom event.
  void logPaymentAdded({double? amount}) {
    _safe(() => _analytics.logEvent(
      name: 'payment_added',
      parameters: {
        if (amount != null) 'amount': amount,
      },
    ));
  }

  /// Logs collaborator_invited custom event.
  void logCollaboratorInvited({required String method, String? role}) {
    _safe(() => _analytics.logEvent(
      name: 'collaborator_invited',
      parameters: {
        'method': method,
        if (role != null) 'role': role,
      },
    ));
  }

  /// Logs invite_accepted custom event.
  void logInviteAccepted({String? companyId}) {
    _safe(() => _analytics.logEvent(
      name: 'invite_accepted',
      parameters: {
        if (companyId != null) 'company_id': companyId,
      },
    ));
  }
}
