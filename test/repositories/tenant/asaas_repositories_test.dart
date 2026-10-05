import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/order_charge.dart';
import 'package:praticos/repositories/tenant/order_charge_repository.dart';
import 'package:praticos/repositories/tenant/payment_settings_repository.dart';

void main() {
  group('PaymentSettingsRepository.fromData', () {
    test('documento ausente vira settings desligado', () {
      final settings = PaymentSettingsRepository.fromData(null);

      expect(settings.asaasEnabled, isFalse);
      expect(settings.asaasConnected, isFalse);
    });

    test('lê os campos do documento', () {
      final settings = PaymentSettingsRepository.fromData({
        'asaasEnabled': true,
        'asaasConnected': true,
        'asaasAccountName': 'Rafsoft',
        'asaasEnvironment': 'production',
      });

      expect(settings.asaasEnabled, isTrue);
      expect(settings.asaasConnected, isTrue);
      expect(settings.asaasAccountName, 'Rafsoft');
      expect(settings.isSandbox, isFalse);
    });
  });

  group('OrderChargeRepository.fromDoc', () {
    test('usa o id do documento', () {
      final charge = OrderChargeRepository.fromDoc('ch1', {
        'status': 'paid',
        'value': 300,
        'createdAt': '2026-10-04T12:00:00.000Z',
      });

      expect(charge.id, 'ch1');
      expect(charge.status, ChargeStatus.paid);
      expect(charge.value, 300.0);
    });

    test('converte Timestamp em data', () {
      final charge = OrderChargeRepository.fromDoc('ch1', {
        'status': 'pending',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 4, 12)),
      });

      expect(charge.createdAt!.toUtc(), DateTime.utc(2026, 10, 4, 12));
    });
  });
}
