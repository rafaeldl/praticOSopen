import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/order_charge.dart';

/// Read-only access to `/companies/{companyId}/orders/{orderId}/charges`.
///
/// Charges are written only by Cloud Functions. Firestore rules allow
/// reading only to owner/admin/manager, so only listen when the user has
/// `PermissionType.chargeOrder`.
class OrderChargeRepository {
  OrderChargeRepository({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  static OrderCharge fromDoc(String id, Map<String, dynamic> data) {
    final json = <String, dynamic>{};
    data.forEach((key, value) {
      json[key] = value is Timestamp
          ? value.toDate().toUtc().toIso8601String()
          : value;
    });
    json['id'] = id;
    return OrderCharge.fromJson(json);
  }

  /// Charges of an order, newest first.
  Stream<List<OrderCharge>> watch(String companyId, String orderId) {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('orders')
        .doc(orderId)
        .collection('charges')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => fromDoc(doc.id, doc.data())).toList());
  }
}
