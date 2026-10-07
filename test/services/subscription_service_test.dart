import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/services/subscription_service.dart';

void main() {
  tearDown(() => SubscriptionService.debugPaidPlansEnabledOverride = null);

  group('SubscriptionService.shouldConfigureSdk', () {
    test('rejects an empty key', () {
      expect(SubscriptionService.shouldConfigureSdk('', releaseMode: false), isFalse);
      expect(SubscriptionService.shouldConfigureSdk('', releaseMode: true), isFalse);
    });

    test('rejects a Test Store key in release builds', () {
      // O SDK do RevenueCat (9+) encerra o app de proposito nesse caso
      expect(SubscriptionService.shouldConfigureSdk('test_abc123', releaseMode: true), isFalse);
    });

    test('accepts a Test Store key in debug builds', () {
      expect(SubscriptionService.shouldConfigureSdk('test_abc123', releaseMode: false), isTrue);
    });

    test('accepts store keys in release builds', () {
      expect(SubscriptionService.shouldConfigureSdk('goog_abc123', releaseMode: true), isTrue);
      expect(SubscriptionService.shouldConfigureSdk('appl_abc123', releaseMode: true), isTrue);
    });
  });

  group('SubscriptionService.isPaidPlansKey', () {
    test('iOS needs an App Store key', () {
      expect(
        SubscriptionService.isPaidPlansKey('appl_abc', isIOS: true, isAndroid: false, releaseMode: true),
        isTrue,
      );
      expect(
        SubscriptionService.isPaidPlansKey('goog_abc', isIOS: true, isAndroid: false, releaseMode: true),
        isFalse,
      );
    });

    test('Android needs a Play key', () {
      expect(
        SubscriptionService.isPaidPlansKey('goog_abc', isIOS: false, isAndroid: true, releaseMode: true),
        isTrue,
      );
      expect(
        SubscriptionService.isPaidPlansKey('appl_abc', isIOS: false, isAndroid: true, releaseMode: true),
        isFalse,
      );
    });

    test('Test Store keys never enable paid plans', () {
      for (final releaseMode in [true, false]) {
        expect(
          SubscriptionService.isPaidPlansKey('test_abc', isIOS: true, isAndroid: false, releaseMode: releaseMode),
          isFalse,
        );
        expect(
          SubscriptionService.isPaidPlansKey('test_abc', isIOS: false, isAndroid: true, releaseMode: releaseMode),
          isFalse,
        );
      }
    });

    test('an empty key disables paid plans', () {
      expect(
        SubscriptionService.isPaidPlansKey('', isIOS: true, isAndroid: false, releaseMode: true),
        isFalse,
      );
    });

    test('other platforms never enable paid plans', () {
      expect(
        SubscriptionService.isPaidPlansKey('appl_abc', isIOS: false, isAndroid: false, releaseMode: true),
        isFalse,
      );
    });
  });

  group('SubscriptionService.paidPlansEnabled', () {
    test('is off without a RevenueCat key (tests and local builds)', () {
      expect(SubscriptionService.paidPlansEnabled, isFalse);
      expect(SubscriptionService.purchaseUiEnabled, isFalse);
    });

    test('purchaseUiEnabled follows paidPlansEnabled', () {
      SubscriptionService.debugPaidPlansEnabledOverride = true;
      expect(SubscriptionService.paidPlansEnabled, isTrue);
      expect(SubscriptionService.purchaseUiEnabled, isTrue);
    });
  });

  group('SubscriptionService.planForEntitlementIds', () {
    test('only production entitlements, highest plan first', () {
      expect(SubscriptionService.entitlementIds, ['business', 'pro', 'starter']);
    });

    test('picks the highest active plan', () {
      expect(SubscriptionService.planForEntitlementIds(['starter', 'business']), 'business');
      expect(SubscriptionService.planForEntitlementIds(['pro']), 'pro');
    });

    test('ignores the old test entitlement', () {
      expect(SubscriptionService.planForEntitlementIds(['Rafsoft Pro']), 'free');
    });

    test('free without entitlements', () {
      expect(SubscriptionService.planForEntitlementIds(const []), 'free');
    });
  });

  group('SubscriptionService without initialization', () {
    // Sem SDK configurado, chamadas nativas derrubam o app no iOS
    // (Purchases.shared da fatalError), entao o servico deve falhar em Dart.
    final service = SubscriptionService.instance;

    test('initialize is a no-op without an API key', () async {
      await expectLater(service.initialize('company-1'), completes);
      expect(service.isInitialized, isFalse);
    });

    test('getCustomerInfo throws StateError', () {
      expect(service.getCustomerInfo, throwsStateError);
    });

    test('restorePurchases throws StateError', () {
      expect(service.restorePurchases, throwsStateError);
    });

    test('logIn throws StateError', () {
      expect(() => service.logIn('company-1'), throwsStateError);
    });

    test('presentPaywall throws StateError', () {
      expect(service.presentPaywall, throwsStateError);
    });

    test('presentCustomerCenter throws StateError', () {
      expect(service.presentCustomerCenter, throwsStateError);
    });

    test('logout is a no-op', () async {
      await expectLater(service.logout(), completes);
    });
  });
}
