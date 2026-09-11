import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/services/subscription_service.dart';

void main() {
  group('SubscriptionService.shouldConfigureSdk', () {
    test('RevenueCat is disabled for now', () {
      // Cobranca ainda nao esta ativa no app. Ao reativar, trocar os secrets
      // pelas keys reais (goog_/appl_) e atualizar este teste.
      expect(SubscriptionService.revenueCatEnabled, isFalse);
    });

    test('never configures when RevenueCat is disabled', () {
      expect(
        SubscriptionService.shouldConfigureSdk(
          'goog_abc123',
          enabled: false,
          releaseMode: true,
        ),
        isFalse,
      );
    });

    test('rejects an empty key', () {
      expect(
        SubscriptionService.shouldConfigureSdk('', enabled: true, releaseMode: false),
        isFalse,
      );
      expect(
        SubscriptionService.shouldConfigureSdk('', enabled: true, releaseMode: true),
        isFalse,
      );
    });

    test('rejects a Test Store key in release builds', () {
      // O SDK do RevenueCat (9+) encerra o app de proposito nesse caso
      expect(
        SubscriptionService.shouldConfigureSdk(
          'test_abc123',
          enabled: true,
          releaseMode: true,
        ),
        isFalse,
      );
    });

    test('accepts a Test Store key in debug builds', () {
      expect(
        SubscriptionService.shouldConfigureSdk(
          'test_abc123',
          enabled: true,
          releaseMode: false,
        ),
        isTrue,
      );
    });

    test('accepts store keys in release builds', () {
      expect(
        SubscriptionService.shouldConfigureSdk(
          'goog_abc123',
          enabled: true,
          releaseMode: true,
        ),
        isTrue,
      );
      expect(
        SubscriptionService.shouldConfigureSdk(
          'appl_abc123',
          enabled: true,
          releaseMode: true,
        ),
        isTrue,
      );
    });
  });

  group('SubscriptionService without initialization', () {
    // Sem SDK configurado, chamadas nativas derrubam o app no iOS
    // (Purchases.shared da fatalError), entao o servico deve falhar em Dart.
    final service = SubscriptionService.instance;

    test('initialize is a no-op while RevenueCat is disabled', () async {
      await expectLater(service.initialize('company-1'), completes);
      expect(service.isInitialized, isFalse);
    });

    test('getCustomerInfo throws StateError', () {
      expect(service.getCustomerInfo, throwsStateError);
    });

    test('getOfferings throws StateError', () {
      expect(service.getOfferings, throwsStateError);
    });

    test('restorePurchases throws StateError', () {
      expect(service.restorePurchases, throwsStateError);
    });

    test('logIn throws StateError', () {
      expect(() => service.logIn('company-1'), throwsStateError);
    });

    test('presentCustomerCenter throws StateError', () {
      expect(service.presentCustomerCenter, throwsStateError);
    });

    test('logout is a no-op', () async {
      await expectLater(service.logout(), completes);
    });
  });
}
