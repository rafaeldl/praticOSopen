import 'package:praticos/models/receipt.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/repositories/tenant/tenant_order_repository.dart';
import 'package:praticos/repositories/tenant_repository.dart';
import 'package:praticos/utils/receipt_plan.dart';

/// Customer receipts: `/companies/{companyId}/receipts/{receiptId}`.
///
/// A receipt is written together with the payment of every order it covers,
/// in one WriteBatch (all or nothing, queued offline). Never hard-deleted:
/// undo is a soft delete (`status: 'canceled'`, phase 2).
class TenantReceiptRepository extends TenantRepository<Receipt> {
  static const String collectionName = 'receipts';

  TenantReceiptRepository() : super(collectionName);

  @override
  Receipt fromJson(Map<String, dynamic> data) => Receipt.fromJson(data);

  @override
  Map<String, dynamic> toJson(Receipt receipt) => receipt.toJson();

  /// New receipt id (generated locally, works offline).
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
}
