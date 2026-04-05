import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TrackingTransparencyService {
  TrackingTransparencyService._();

  static final TrackingTransparencyService instance =
      TrackingTransparencyService._();

  static const String _attRequestedPrefKey = 'att_prompt_requested_v1';
  bool _isRequestInFlight = false;

  Future<void> requestIfEligible() async {
    if (!Platform.isIOS || _isRequestInFlight) return;

    _isRequestInFlight = true;
    try {
      final status =
          await AppTrackingTransparency.trackingAuthorizationStatus;

      if (status != TrackingStatus.notDetermined) {
        await _syncAnalyticsConsent(status);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final alreadyRequested = prefs.getBool(_attRequestedPrefKey) ?? false;
      if (alreadyRequested) return;

      await prefs.setBool(_attRequestedPrefKey, true);

      final newStatus =
          await AppTrackingTransparency.requestTrackingAuthorization();
      await _syncAnalyticsConsent(newStatus);
    } catch (e, stack) {
      debugPrint('Error requesting ATT permission: $e');
      debugPrintStack(stackTrace: stack);
    } finally {
      _isRequestInFlight = false;
    }
  }

  Future<void> _syncAnalyticsConsent(TrackingStatus status) async {
    final granted = status == TrackingStatus.authorized;
    await FirebaseAnalytics.instance.setConsent(
      analyticsStorageConsentGranted: true,
      adStorageConsentGranted: granted,
      adUserDataConsentGranted: granted,
      adPersonalizationSignalsConsentGranted: granted,
    );
  }
}
