import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/nfse.dart';

/// [day] as the YYYY-MM-DD text of `effectiveDate`.
String nfseDayKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// Read-only access to `/companies/{companyId}/invoices` (NFS-e).
///
/// Written only by Cloud Functions. Firestore rules allow reading to the
/// same roles as the charges (financial roles and the owner).
class NfseInvoiceRepository {
  NfseInvoiceRepository({FirebaseFirestore? firestore})
    : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _invoices(String companyId) =>
      _db.collection('companies').doc(companyId).collection('invoices');

  static List<NfseInvoice> _parse(QuerySnapshot<Map<String, dynamic>> snap) => [
    for (final doc in snap.docs) NfseInvoice.fromJson(doc.data(), id: doc.id),
  ];

  /// Notas covering [orderId] (one or several orders each). One
  /// array-contains filter: no composite index.
  Stream<List<NfseInvoice>> watchOfOrder(String companyId, String orderId) =>
      _invoices(
        companyId,
      ).where('orderIds', arrayContains: orderId).snapshots().map(_parse);

  /// Notas of a customer (for "uma nota com várias OS").
  Stream<List<NfseInvoice>> watchOfCustomer(
    String companyId,
    String customerId,
  ) => _invoices(
    companyId,
  ).where('customer.id', isEqualTo: customerId).snapshots().map(_parse);

  /// Notas dated from [since] on. `effectiveDate` is a YYYY-MM-DD text and
  /// one range filter needs no composite index.
  Stream<List<NfseInvoice>> watchSince(String companyId, DateTime since) =>
      _invoices(companyId)
          .where('effectiveDate', isGreaterThanOrEqualTo: nfseDayKey(since))
          .snapshots()
          .map(_parse);

  /// One nota, live (null when it does not exist).
  Stream<NfseInvoice?> watch(String companyId, String invoiceId) =>
      _invoices(companyId)
          .doc(invoiceId)
          .snapshots()
          .map(
            (doc) => doc.exists
                ? NfseInvoice.fromJson(doc.data()!, id: doc.id)
                : null,
          );
}
