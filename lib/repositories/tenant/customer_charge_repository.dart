import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/customer_charge.dart';

/// Read-only access to `/companies/{companyId}/customerCharges`.
///
/// Written only by Cloud Functions. Firestore rules allow reading to the
/// same roles as the order charges (financial roles and the owner).
class CustomerChargeRepository {
  CustomerChargeRepository({FirebaseFirestore? firestore})
    : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  /// The customer's open charge (pending or overdue), or null. One equality
  /// filter: no composite index.
  Stream<CustomerCharge?> watchOpen(String companyId, String customerId) {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('customerCharges')
        .where('customer.id', isEqualTo: customerId)
        .snapshots()
        .map(
          (snap) => openOf([
            for (final doc in snap.docs)
              CustomerCharge.fromJson(doc.data(), id: doc.id),
          ]),
        );
  }

  /// Whether the customer has an open charge of several orders.
  Future<bool> hasOpen(String companyId, String customerId) async {
    final snap = await _db
        .collection('companies')
        .doc(companyId)
        .collection('customerCharges')
        .where('customer.id', isEqualTo: customerId)
        .get();
    return snap.docs.any(
      (doc) => CustomerCharge.fromJson(doc.data(), id: doc.id).isOpen,
    );
  }

  /// The server keeps at most one open charge per customer; if two show up
  /// (a race), the later due date wins.
  static CustomerCharge? openOf(List<CustomerCharge> charges) {
    final open = charges.where((c) => c.isOpen).toList()
      ..sort((a, b) => (b.dueDate ?? '').compareTo(a.dueDate ?? ''));
    return open.isEmpty ? null : open.first;
  }
}
