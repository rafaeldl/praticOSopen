import 'package:praticos/models/receipt.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/repositories/tenant/tenant_order_repository.dart';
import 'package:praticos/repositories/tenant_repository.dart';
import 'package:praticos/utils/receipt_plan.dart';
import 'package:praticos/utils/receipt_undo.dart';

/// Customer receipts: `/companies/{companyId}/receipts/{receiptId}`.
///
/// A receipt is written together with the payment of every order it covers,
/// in one WriteBatch (all or nothing, queued offline). Never hard-deleted:
/// undo is a soft delete (`status: 'canceled'`, see [cancel]).
class TenantReceiptRepository extends TenantRepository<Receipt> {
  static const String collectionName = 'receipts';

  TenantReceiptRepository() : super(collectionName);

  @override
  Receipt fromJson(Map<String, dynamic> data) => Receipt.fromJson(data);

  @override
  Map<String, dynamic> toJson(Receipt receipt) => receipt.toJson();

  /// New receipt id (generated locally, works offline). Firestore auto ids
  /// are 20 letters/digits, so they never start with `asaas_` (reserved for
  /// receipts of Asaas payments; the rules and the server refuse it).
  String newId(String companyId) => collectionFor(companyId).doc().id;

  /// Writes [plan] in one batch: the receipt document and the payment update
  /// of each order (arrayUnion/increment, stamped with [actor]).
  ///
  /// The returned Future completes only when the server acknowledges the
  /// batch; offline it stays pending while the writes are already applied
  /// to the local cache. Callers should not await it to unblock the UI.
  Future<void> save(String companyId, ReceiptPlan plan, {UserAggr? actor}) {
    final batch = firestore.batch();
    final receiptJson = toJson(plan.receipt)..remove('id');
    batch.set(collectionFor(companyId).doc(plan.receipt.id), receiptJson);

    final orders = firestore
        .collection('companies')
        .doc(companyId)
        .collection(TenantOrderRepository.collectionName);
    plan.orderUpdates.forEach((orderId, update) {
      batch.update(
        orders.doc(orderId),
        TenantOrderRepository.toFirestoreUpdate(update, actor: actor),
      );
    });
    return batch.commit();
  }

  /// Undoes a receipt in one batch: `status: 'canceled'` on the receipt and
  /// the recomputed payment fields of each order ([buildReceiptUndo]).
  /// Like [save], the Future completes only when the server acknowledges.
  Future<void> cancel(
    String companyId,
    String receiptId,
    ReceiptUndoPlan plan, {
    UserAggr? actor,
  }) {
    final batch = firestore.batch();
    final receiptUpdate = Map<String, dynamic>.from(plan.receiptUpdate);
    if (actor != null) receiptUpdate['updatedBy'] = actor.toJson();
    batch.update(collectionFor(companyId).doc(receiptId), receiptUpdate);

    final orders = firestore
        .collection('companies')
        .doc(companyId)
        .collection(TenantOrderRepository.collectionName);
    plan.orderUpdates.forEach((orderId, update) {
      batch.update(
        orders.doc(orderId),
        TenantOrderRepository.toFirestoreUpdate(update, actor: actor),
      );
    });
    return batch.commit();
  }

  /// Active receipts of a customer, newest first (filtered and sorted here:
  /// one equality filter, no composite index).
  Stream<List<Receipt>> watchActiveOfCustomer(
    String companyId,
    String customerId,
  ) {
    return collectionFor(companyId)
        .where('customer.id', isEqualTo: customerId)
        .snapshots()
        .map((snap) {
      final list = [
        for (final doc in snap.docs)
          fromJson({...doc.data(), 'id': doc.id}),
      ].where((r) => r.status == ReceiptStatus.active).toList()
        ..sort((a, b) => (b.paidAt ?? b.createdAt ?? DateTime(0))
            .compareTo(a.paidAt ?? a.createdAt ?? DateTime(0)));
      return list;
    });
  }
}
