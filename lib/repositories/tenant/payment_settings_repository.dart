import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/payment_settings.dart';

/// Read-only access to `/companies/{companyId}/settings/payments`.
///
/// The document is written only by Cloud Functions; a missing document
/// means the integration is off.
class PaymentSettingsRepository {
  PaymentSettingsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  static PaymentSettings fromData(Map<String, dynamic>? data) {
    if (data == null) return PaymentSettings();
    return PaymentSettings.fromJson(data);
  }

  Stream<PaymentSettings> watch(String companyId) {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('settings')
        .doc('payments')
        .snapshots()
        .map((snap) => fromData(snap.data()));
  }
}
