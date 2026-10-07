import 'dart:io' show Platform;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

/// RevenueCat wrapper (App Store In-App Purchase and Google Play Billing).
///
/// The RevenueCat `appUserID` is the company id: the subscription belongs to
/// the company, not to the user.
///
/// ## API keys
///
/// Injected at build time:
/// ```bash
/// flutter build ios --dart-define=REVENUECAT_IOS_API_KEY=appl_xxx
/// flutter build appbundle --dart-define=REVENUECAT_ANDROID_API_KEY=goog_xxx
/// ```
///
/// Paid plans ([paidPlansEnabled]) need a real store key for the platform
/// (`appl_` on iOS, `goog_` on Android). Without it the app has no purchase UI
/// and no plan limits on any platform. A Test Store key (`test_`) only
/// configures the SDK in debug builds and never turns paid plans on.
///
/// ## Entitlements
///
/// `business`, `pro`, `starter` ([entitlementIds], highest plan first).
class SubscriptionService {
  static SubscriptionService? _instance;
  static SubscriptionService get instance => _instance ??= SubscriptionService._();

  SubscriptionService._();

  static const _iosApiKey = String.fromEnvironment(
    'REVENUECAT_IOS_API_KEY',
    defaultValue: '',
  );
  static const _androidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
    defaultValue: '',
  );

  /// Production entitlements, highest plan first.
  static const List<String> entitlementIds = ['business', 'pro', 'starter'];

  /// Overrides [paidPlansEnabled] in tests. Always reset to null afterwards.
  @visibleForTesting
  static bool? debugPaidPlansEnabledOverride;

  /// Single switch for paid plans: SDK, purchase UI and plan limits.
  ///
  /// `true` only when this build carries a real store key for the platform.
  static bool get paidPlansEnabled {
    final override = debugPaidPlansEnabledOverride;
    if (override != null) return override;
    if (kIsWeb) return false;
    return isPaidPlansKey(
      _platformApiKey(),
      isIOS: Platform.isIOS,
      isAndroid: Platform.isAndroid,
    );
  }

  /// Whether purchase UI (paywall, plans, upgrade CTAs) may appear.
  static bool get purchaseUiEnabled => paidPlansEnabled;

  /// Whether [apiKey] turns paid plans on for the given platform.
  @visibleForTesting
  static bool isPaidPlansKey(
    String apiKey, {
    required bool isIOS,
    required bool isAndroid,
    bool releaseMode = kReleaseMode,
  }) {
    if (!shouldConfigureSdk(apiKey, releaseMode: releaseMode)) return false;
    if (isIOS) return apiKey.startsWith('appl_');
    if (isAndroid) return apiKey.startsWith('goog_');
    return false;
  }

  /// Whether the SDK may be configured with [apiKey].
  ///
  /// Test Store keys (`test_`) only work in debug: in release builds the
  /// RevenueCat SDK (9+) terminates the app on purpose when configured with one.
  @visibleForTesting
  static bool shouldConfigureSdk(
    String apiKey, {
    bool releaseMode = kReleaseMode,
  }) {
    if (apiKey.isEmpty) return false;
    if (releaseMode && apiKey.startsWith('test_')) return false;
    return true;
  }

  static String _platformApiKey() {
    if (kIsWeb) return '';
    if (Platform.isIOS) return _iosApiKey;
    if (Platform.isAndroid) return _androidApiKey;
    return '';
  }

  /// Plan id ('business', 'pro', 'starter' or 'free') for the active
  /// entitlement ids, highest plan first.
  @visibleForTesting
  static String planForEntitlementIds(Iterable<String> activeIds) {
    for (final id in entitlementIds) {
      if (activeIds.contains(id)) return id;
    }
    return 'free';
  }

  bool _isInitialized = false;

  /// Whether the SDK was configured in this session.
  bool get isInitialized => _isInitialized;

  /// Configures the SDK for [companyId], or switches the RevenueCat customer
  /// to [companyId] when it is already configured. No-op without a key.
  Future<void> initialize(String companyId) async {
    if (_isInitialized) {
      await Purchases.logIn(companyId);
      return;
    }

    final apiKey = _platformApiKey();
    if (!shouldConfigureSdk(apiKey)) {
      if (apiKey.isEmpty) {
        debugPrint('SubscriptionService: No API key configured, skipping initialization');
      } else {
        // Test Store key in a release build: the SDK would kill the app.
        FirebaseCrashlytics.instance.recordError(
          StateError('RevenueCat Test Store API key used in release build'),
          StackTrace.current,
          reason: 'SubscriptionService',
          fatal: false,
        );
      }
      return;
    }

    final configuration = PurchasesConfiguration(apiKey)..appUserID = companyId;
    await Purchases.configure(configuration);
    _isInitialized = true;
    debugPrint('SubscriptionService: Initialized');
  }

  /// Fails in Dart when the SDK is not configured: calling the native SDK
  /// unconfigured crashes the app on iOS (`Purchases.shared` fatalError).
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('SubscriptionService: RevenueCat not initialized');
    }
  }

  Future<CustomerInfo> getCustomerInfo() async {
    _ensureInitialized();
    return Purchases.getCustomerInfo();
  }

  Future<Offerings?> getOfferings() async {
    _ensureInitialized();
    return Purchases.getOfferings();
  }

  /// Buys [package]. Throws [PlatformException] on error or cancellation.
  Future<CustomerInfo> purchasePackage(Package package) async {
    _ensureInitialized();
    final result = await Purchases.purchase(PurchaseParams.package(package));
    return result.customerInfo;
  }

  /// Restores the store purchases into the current company.
  Future<CustomerInfo> restorePurchases() async {
    _ensureInitialized();
    return Purchases.restorePurchases();
  }

  /// 'business', 'pro', 'starter' or 'free'.
  String getPlanFromEntitlements(CustomerInfo info) =>
      planForEntitlementIds(info.entitlements.active.keys);

  /// Whether [info] has an active paid plan.
  bool hasActivePlan(CustomerInfo info) => getPlanFromEntitlements(info) != 'free';

  /// Presents the RevenueCat paywall of [offering] (default: the current
  /// offering, `default`). Price, period, renewal terms, Terms, Privacy and
  /// Restore are configured in the RevenueCat dashboard.
  Future<PaywallResult> presentPaywall({Offering? offering}) async {
    _ensureInitialized();
    return RevenueCatUI.presentPaywall(
      offering: offering,
      displayCloseButton: true,
    );
  }

  /// Presents the RevenueCat Customer Center (manage, cancel, change plan).
  Future<void> presentCustomerCenter() async {
    _ensureInitialized();
    await RevenueCatUI.presentCustomerCenter();
  }

  /// Logs the RevenueCat customer out. No-op when the SDK is not configured.
  Future<void> logout() async {
    if (!_isInitialized) return;
    try {
      await Purchases.logOut();
    } catch (e) {
      // logOut throws when the current customer is already anonymous.
      debugPrint('SubscriptionService: Error logging out: $e');
    }
  }

  /// Switches the RevenueCat customer to [companyId].
  Future<CustomerInfo> logIn(String companyId) async {
    _ensureInitialized();
    final result = await Purchases.logIn(companyId);
    return result.customerInfo;
  }
}
