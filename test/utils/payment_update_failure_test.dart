import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/utils/order_payment_math.dart';
import 'package:praticos/utils/payment_update_failure.dart';

void main() {
  group('classifyPaymentUpdateFailure', () {
    FirebaseException firestoreError(String code) =>
        FirebaseException(plugin: 'cloud_firestore', code: code);

    test('Firestore unavailable (offline) requires connection', () {
      expect(
        classifyPaymentUpdateFailure(firestoreError('unavailable')),
        PaymentUpdateFailure.requiresConnection,
      );
    });

    test('Firestore deadline-exceeded (transaction timeout) requires connection',
        () {
      expect(
        classifyPaymentUpdateFailure(firestoreError('deadline-exceeded')),
        PaymentUpdateFailure.requiresConnection,
      );
    });

    test('TimeoutException and SocketException require connection', () {
      expect(
        classifyPaymentUpdateFailure(TimeoutException('t')),
        PaymentUpdateFailure.requiresConnection,
      );
      expect(
        classifyPaymentUpdateFailure(const SocketException('s')),
        PaymentUpdateFailure.requiresConnection,
      );
    });

    test('Asaas transaction lock is reported as such', () {
      expect(
        classifyPaymentUpdateFailure(
            const AsaasTransactionLockedException('asaas_pay_1')),
        PaymentUpdateFailure.asaasLocked,
      );
    });

    test('other errors are a generic failure', () {
      expect(
        classifyPaymentUpdateFailure(firestoreError('permission-denied')),
        PaymentUpdateFailure.failed,
      );
      expect(
        classifyPaymentUpdateFailure(StateError('x')),
        PaymentUpdateFailure.failed,
      );
    });
  });
}
