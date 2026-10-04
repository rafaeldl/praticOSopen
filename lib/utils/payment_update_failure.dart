import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:praticos/utils/order_payment_math.dart';

/// Why a payment write (OrderStore) could not be saved. The UI maps it to
/// a localized message.
enum PaymentUpdateFailure {
  /// Firestore transactions need the server: the device is offline.
  requiresConnection,

  /// Tried to remove a payment received through Asaas (`asaas_*`).
  asaasLocked,

  /// Anything else (permissions, missing order, unexpected errors).
  failed,
}

/// Firestore error codes raised when the server can't be reached
/// (offline read inside a transaction, or the transaction timeout).
const _offlineFirestoreCodes = {'unavailable', 'deadline-exceeded'};

PaymentUpdateFailure classifyPaymentUpdateFailure(Object error) {
  if (error is AsaasTransactionLockedException) {
    return PaymentUpdateFailure.asaasLocked;
  }
  if (error is FirebaseException &&
      _offlineFirestoreCodes.contains(error.code)) {
    return PaymentUpdateFailure.requiresConnection;
  }
  if (error is TimeoutException || error is SocketException) {
    return PaymentUpdateFailure.requiresConnection;
  }
  return PaymentUpdateFailure.failed;
}
