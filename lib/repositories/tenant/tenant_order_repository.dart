import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:praticos/global.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/repositories/tenant_repository.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/utils/order_payment_math.dart';

/// Repository para Orders usando subcollections por tenant.
///
/// Path: `/companies/{companyId}/orders/{orderId}`
class TenantOrderRepository extends TenantRepository<Order?> {
  static const String collectionName = 'orders';

  TenantOrderRepository() : super(collectionName);

  @override
  Order fromJson(Map<String, dynamic> data) => Order.fromJson(data);

  @override
  Map<String, dynamic> toJson(Order? order) => order!.toJson();

  // ═══════════════════════════════════════════════════════════════════
  // Payments-safe writes
  // ═══════════════════════════════════════════════════════════════════
  //
  // Payments (transactions, paidAmount, paid, payment) are written only by
  // updatePayments / applyPaymentFieldUpdate (app) or by the server (Asaas
  // webhook). Full-order saves must not send them, or they would overwrite
  // payments made elsewhere.

  /// Creates a new order with all fields. When the order already exists,
  /// saves it without the payment fields.
  @override
  Future<void> createItem(String companyId, Order? item, {String? id}) async {
    final docId = item?.id ?? id;
    if (item != null && docId != null) {
      final ref = collectionFor(companyId).doc(docId);
      if (await _exists(ref)) {
        final json = OrderPaymentMath.stripPaymentFields(toJson(item));
        json.remove('number');
        await ref.set(json, SetOptions(merge: true));
        item.id = docId;
        return;
      }
    }
    await super.createItem(companyId, item, id: id);
  }

  /// Saves an existing order without the payment fields.
  @override
  Future<void> updateItem(String companyId, Order? item) {
    final json = OrderPaymentMath.stripPaymentFields(toJson(item));
    return collectionFor(companyId)
        .doc(item?.id)
        .set(json, SetOptions(merge: true));
  }

  /// Offline without cache, `get()` throws: treat as a new order (full write).
  Future<bool> _exists(DocumentReference<Map<String, dynamic>> ref) async {
    try {
      return (await ref.get()).exists;
    } on FirebaseException {
      return false;
    }
  }

  /// Converts the marker classes of [OrderPaymentMath] into Firestore field
  /// transforms and stamps the audit fields with the acting user (never the
  /// order's previous `updatedBy`). Without an actor, `updatedBy` is omitted.
  static Map<String, dynamic> toFirestoreUpdate(
    Map<String, dynamic> update, {
    UserAggr? actor,
  }) {
    final result = <String, dynamic>{};
    update.forEach((key, value) {
      if (value is ArrayUnionOp) {
        result[key] = FieldValue.arrayUnion(value.values);
      } else if (value is IncrementOp) {
        result[key] = FieldValue.increment(value.by);
      } else {
        result[key] = value;
      }
    });
    result.remove('updatedBy');
    if (actor != null) result['updatedBy'] = actor.toJson();
    return result;
  }

  /// Applies a payment update map (from OrderPaymentMath.addPaymentUpdate /
  /// addDiscountUpdate) with field transforms. No transaction: works offline.
  Future<void> applyPaymentFieldUpdate(
    String companyId,
    String orderId,
    Map<String, dynamic> update, {
    UserAggr? actor,
  }) {
    return collectionFor(companyId).doc(orderId).update(
          toFirestoreUpdate(update, actor: actor ?? Global.userAggr),
        );
  }

  /// Reads the order inside a Firestore transaction, applies [mutate] to the
  /// fresh copy and writes only payment fields, discount, total and audit
  /// (`updatedBy` is the acting user, not the previous one).
  /// Returns the updated order, or null when it does not exist.
  /// Errors thrown by [mutate] (e.g. AsaasTransactionLockedException) propagate.
  Future<Order?> updatePayments(
    String companyId,
    String orderId,
    Order Function(Order fresh) mutate, {
    UserAggr? actor,
  }) {
    final ref = collectionFor(companyId).doc(orderId);
    final user = actor ?? Global.userAggr;
    return firestore.runTransaction<Order?>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return null;
      final fresh = fromJson({...snap.data()!, 'id': snap.id});
      final updated = mutate(fresh);
      updated.updatedAt = DateTime.now();
      updated.updatedBy = user;
      final data = OrderPaymentMath.paymentUpdateOf(updated);
      if (user == null) data.remove('updatedBy');
      tx.update(ref, data);
      return updated;
    });
  }

  /// Reads the order from the server, skipping the local cache (e.g. after
  /// an Asaas webhook changed its payments). Throws when offline.
  Future<Order?> getFromServer(String companyId, String orderId) async {
    final snap = await collectionFor(companyId)
        .doc(orderId)
        .get(const GetOptions(source: Source.server));
    if (!snap.exists) return null;
    return fromJson({...snap.data()!, 'id': snap.id});
  }

  // ═══════════════════════════════════════════════════════════════════
  // Order-specific methods
  // ═══════════════════════════════════════════════════════════════════

  /// Busca todas as orders do tenant.
  Future<List<Order?>> getOrders(String companyId) async {
    final List<OrderBy> orderBy = [OrderBy('createdAt', descending: true)];
    return getQueryList(companyId, orderBy: orderBy);
  }

  /// Busca uma order pelo número.
  Future<Order?> getOrderByNumber(String companyId, int number) async {
    final List<QueryArgs> filterList = [QueryArgs('number', number)];

    try {
      final orders = await getQueryList(companyId, args: filterList);
      return orders.isNotEmpty ? orders.first : null;
    } catch (e) {
      print('Erro ao buscar ordem pelo número: $e');
      return null;
    }
  }

  /// Busca orders por período.
  Future<List<Order?>> getOrdersByPeriod(String companyId, String period) {
    return getOrdersByCustomPeriod(companyId, period, 0);
  }

  /// Busca orders por período customizado com offset.
  Future<List<Order?>> getOrdersByCustomPeriod(
    String companyId,
    String period,
    int offset,
  ) async {
    DateTime now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    switch (period) {
      case 'hoje':
        DateTime targetDay = now.add(Duration(days: offset));
        startDate = DateTime(targetDay.year, targetDay.month, targetDay.day);
        endDate = DateTime(targetDay.year, targetDay.month, targetDay.day + 1);
        break;

      case 'semana':
        int currentWeek =
            ((now.difference(DateTime(now.year, 1, 1)).inDays) / 7).floor();
        int targetWeek = currentWeek + offset;
        startDate =
            DateTime(now.year, 1, 1).add(Duration(days: targetWeek * 7));
        startDate = startDate.subtract(Duration(days: startDate.weekday));
        endDate = startDate.add(Duration(days: 7));
        break;

      case 'mês':
        startDate = DateTime(now.year, now.month + offset, 1);
        endDate = DateTime(now.year, now.month + offset + 1, 1);
        break;

      case 'ano':
        int targetYear = now.year + offset;
        startDate = DateTime(targetYear, 1, 1);
        endDate = DateTime(targetYear + 1, 1, 1);
        break;

      default:
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 1);
    }

    return getOrdersByDateRange(companyId, startDate, endDate);
  }

  /// Busca orders por intervalo de datas.
  Future<List<Order?>> getOrdersByDateRange(
    String companyId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final List<QueryArgs> filterList = [
        QueryArgs(
          'createdAt',
          startDate.toIso8601String(),
          oper: 'isGreaterThanOrEqualTo',
        ),
        QueryArgs(
          'createdAt',
          endDate.toIso8601String(),
          oper: 'isLessThan',
        ),
      ];

      final List<OrderBy> orderBy = [OrderBy('createdAt', descending: true)];

      return await getQueryList(companyId, orderBy: orderBy, args: filterList);
    } catch (e) {
      print('Erro ao buscar ordens por intervalo de datas: $e');
      return [];
    }
  }

  /// Busca orders por intervalo de scheduledDate.
  Future<List<Order?>> getOrdersByScheduledDateRange(
    String companyId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final List<QueryArgs> filterList = [
        QueryArgs(
          'scheduledDate',
          startDate.toIso8601String(),
          oper: 'isGreaterThanOrEqualTo',
        ),
        QueryArgs(
          'scheduledDate',
          endDate.toIso8601String(),
          oper: 'isLessThan',
        ),
      ];

      final List<OrderBy> orderBy = [OrderBy('scheduledDate')];

      return await getQueryList(companyId, orderBy: orderBy, args: filterList);
    } catch (e) {
      print('Erro ao buscar ordens por scheduledDate: $e');
      return [];
    }
  }

  /// Stream de orders por intervalo de scheduledDate.
  Stream<List<Order?>> streamOrdersByScheduledDateRange(
    String companyId,
    DateTime startDate,
    DateTime endDate,
  ) {
    final List<QueryArgs> filterList = [
      QueryArgs(
        'scheduledDate',
        startDate.toIso8601String(),
        oper: 'isGreaterThanOrEqualTo',
      ),
      QueryArgs(
        'scheduledDate',
        endDate.toIso8601String(),
        oper: 'isLessThan',
      ),
    ];

    final List<OrderBy> orderBy = [OrderBy('scheduledDate')];

    return streamQueryList(companyId, orderBy: orderBy, args: filterList);
  }

  /// Stream de orders por intervalo de dueDate.
  Stream<List<Order?>> streamOrdersByDueDateRange(
    String companyId,
    DateTime startDate,
    DateTime endDate,
  ) {
    final List<QueryArgs> filterList = [
      QueryArgs(
        'dueDate',
        startDate.toIso8601String(),
        oper: 'isGreaterThanOrEqualTo',
      ),
      QueryArgs(
        'dueDate',
        endDate.toIso8601String(),
        oper: 'isLessThan',
      ),
    ];

    final List<OrderBy> orderBy = [OrderBy('dueDate')];

    return streamQueryList(companyId, orderBy: orderBy, args: filterList);
  }

  /// Stream de orders com filtros opcionais.
  Stream<List<Order?>> streamOrders(
    String companyId, {
    String? status,
    String? payment,
    String? customerId,
  }) {
    List<QueryArgs> filterList = [];
    List<OrderBy> orderBy = [OrderBy('createdAt', descending: true)];

    if (status != null) {
      if (['paid', 'unpaid'].contains(status)) {
        filterList.add(QueryArgs('payment', status));
      } else if (status == 'due_date') {
        filterList.add(
          QueryArgs('status', ['approved', 'progress'], oper: 'whereIn'),
        );
        orderBy = [OrderBy('dueDate')];
      } else {
        filterList.add(QueryArgs('status', status));
      }
    }

    if (payment != null) {
      filterList.add(QueryArgs('payment', payment));
    }

    if (customerId != null) {
      filterList.add(QueryArgs('customer.id', customerId));
    }

    return streamQueryList(companyId, orderBy: orderBy, args: filterList);
  }

  /// Stream de orders que contêm um device específico
  Stream<List<Order?>> streamOrdersByDevice(
    String companyId,
    String deviceId,
  ) {
    return streamQueryList(
      companyId,
      args: [QueryArgs('deviceIds', deviceId, oper: 'arrayContains')],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Child orders (generated from contract templates)
  // ═══════════════════════════════════════════════════════════════════

  /// Stream of orders generated from a contract template.
  /// No orderBy to avoid composite index requirement — sorted client-side.
  Stream<List<Order?>> streamChildOrders(String companyId, String parentOrderId) {
    return streamQueryList(
      companyId,
      args: [QueryArgs('contract.parentOrderId', parentOrderId)],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Contract queries
  // ═══════════════════════════════════════════════════════════════════

  /// All orders with active contract (for list and auto-generation)
  Stream<List<Order?>> streamContractOrders(String companyId) {
    return streamQueryList(
      companyId,
      args: [QueryArgs('isContract', true)],
    );
  }

  /// Orders with contract linked to a specific device
  Stream<List<Order?>> streamContractsByDevice(
    String companyId,
    String deviceId,
  ) {
    return streamQueryList(
      companyId,
      args: [
        QueryArgs('isContract', true),
        QueryArgs('deviceIds', deviceId, oper: 'arrayContains'),
      ],
    );
  }
}
