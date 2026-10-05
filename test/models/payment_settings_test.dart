import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/payment_settings.dart';

void main() {
  group('PaymentSettings', () {
    test('documento vazio vira tudo desligado', () {
      final settings = PaymentSettings.fromJson({});

      expect(settings.asaasEnabled, isFalse);
      expect(settings.asaasConnected, isFalse);
      expect(settings.asaasAccountName, isNull);
      expect(settings.isSandbox, isFalse);
    });

    test('lê conta conectada no sandbox', () {
      final settings = PaymentSettings.fromJson({
        'asaasEnabled': true,
        'asaasConnected': true,
        'asaasAccountName': 'Rafsoft',
        'asaasEnvironment': 'sandbox',
      });

      expect(settings.asaasEnabled, isTrue);
      expect(settings.asaasConnected, isTrue);
      expect(settings.asaasAccountName, 'Rafsoft');
      expect(settings.isSandbox, isTrue);
    });

    test('produção não é sandbox', () {
      final settings = PaymentSettings(
        asaasEnabled: true,
        asaasConnected: true,
        asaasEnvironment: 'production',
      );

      expect(settings.isSandbox, isFalse);
    });
  });
}
