import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:praticos/global.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/utils/merge_order_streams.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/repositories/tenant_repository.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/utils/contract_generation.dart';
import 'package:praticos/utils/order_field_diff.dart';
import 'package:praticos/utils/report_week.dart';
import 'package:praticos/utils/order_payment_math.dart';
import 'package:praticos/utils/order_scope.dart';
import 'package:praticos/utils/switch_stream.dart';

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
  // Query scope (Firestore rules)
  // ═══════════════════════════════════════════════════════════════════
  //
  // Consultant and technician read only some orders (the consultant the ones
  // they created, the technician also the ones assigned to them), and the
  // rules deny any list query that could return another order. So every
  // list query here gets the matching filter for them.

  /// Scope to filter list queries by, or null when the user reads every
  /// order. Replaceable in tests.
  static Future<OrderScope?> Function() creatorScope = () =>
      AuthorizationService.instance.orderCreatorFilter();

  /// [creatorScope] now and again whenever it changes (the role arrives
  /// after the query started). Live queries resubscribe on each value.
  /// Replaceable in tests.
  static Stream<OrderScope?> Function() creatorScopeChanges = () =>
      AuthorizationService.instance.orderCreatorFilterChanges();

  /// Operator of the [QueryArgs] that filters "created by or assigned to"
  /// its value (see `TenantRepository`).
  static const String createdOrAssignedOper = 'createdOrAssigned';

  /// [args] plus the [scope] filter: `createdBy.id == uid`, or
  /// `createdBy.id == uid OR assignedTo.id == uid` for the technician. Kept
  /// as is when [scope] is null or the query already filters `createdBy.id`.
  static List<QueryArgs> scopedArgs(List<QueryArgs>? args, OrderScope? scope) {
    final list = [...?args];
    if (scope == null || list.any((a) => a.key == 'createdBy.id')) {
      return list;
    }
    return list..add(
      scope.assigned
          ? QueryArgs('createdBy.id', scope.uid, oper: createdOrAssignedOper)
          : QueryArgs('createdBy.id', scope.uid),
    );
  }

  /// [query] filtered by [scope] (same filter as [scopedArgs]).
  static Query<Map<String, dynamic>> applyScope(
    Query<Map<String, dynamic>> query,
    OrderScope? scope,
  ) {
    if (scope == null) return query;
    if (!scope.assigned) {
      return query.where('createdBy.id', isEqualTo: scope.uid);
    }
    return query.where(createdOrAssignedFilter(scope.uid));
  }

  /// `createdBy.id == uid OR assignedTo.id == uid`.
  static Filter createdOrAssignedFilter(String uid) => Filter.or(
    Filter('createdBy.id', isEqualTo: uid),
    Filter('assignedTo.id', isEqualTo: uid),
  );

  @override
  Future<List<Order?>> getQueryList(
    String companyId, {
    List<OrderBy>? orderBy,
    List<QueryArgs>? args,
    int? limit,
    dynamic startAfter,
  }) async {
    final creator = await creatorScope();
    return super.getQueryList(
      companyId,
      orderBy: orderBy,
      args: scopedArgs(args, creator),
      limit: limit,
      startAfter: startAfter,
    );
  }

  @override
  Stream<List<Order?>> streamQueryList(
    String companyId, {
    List<OrderBy>? orderBy,
    List<QueryArgs>? args,
    int? limit,
  }) {
    return switchStream(
      creatorScopeChanges(),
      (OrderScope? creator) => super.streamQueryList(
        companyId,
        orderBy: orderBy,
        args: scopedArgs(args, creator),
        limit: limit,
      ),
    );
  }

  @override
  Stream<List<Order?>> streamList(String companyId) =>
      streamQueryList(companyId);

  @override
  Future<List<Order?>> getListFromTo(
    String companyId,
    String field,
    DateTime from,
    DateTime to, {
    List<QueryArgs> args = const [],
  }) async {
    final creator = await creatorScope();
    return super.getListFromTo(
      companyId,
      field,
      from,
      to,
      args: scopedArgs(args, creator),
    );
  }

  @override
  Stream<List<Order?>> streamListFromTo(
    String companyId,
    String field,
    DateTime from,
    DateTime to, {
    List<QueryArgs> args = const [],
  }) {
    return switchStream(
      creatorScopeChanges(),
      (OrderScope? creator) => super.streamListFromTo(
        companyId,
        field,
        from,
        to,
        args: scopedArgs(args, creator),
      ),
    );
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> getQueryWithPagination(
    String companyId, {
    List<OrderBy>? orderBy,
    List<QueryArgs>? args,
    int? limit,
    DocumentSnapshot? startAfterDocument,
  }) async {
    final creator = await creatorScope();
    return super.getQueryWithPagination(
      companyId,
      orderBy: orderBy,
      args: scopedArgs(args, creator),
      limit: limit,
      startAfterDocument: startAfterDocument,
    );
  }

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
    return collectionFor(
      companyId,
    ).doc(item?.id).set(json, SetOptions(merge: true));
  }

  /// Writes only [fields] of an existing order (from
  /// [OrderFieldDiff.changedFields]), stamping `updatedAt`/`updatedBy` with
  /// the acting user. Fields written elsewhere (items by the web, payments by
  /// the server) are left as they are. No transaction: works offline.
  Future<void> updateFields(
    String companyId,
    String orderId,
    Map<String, dynamic> fields, {
    UserAggr? actor,
  }) {
    return collectionFor(
      companyId,
    ).doc(orderId).update(fieldUpdateOf(fields, actor: actor ?? Global.userAggr));
  }

  /// How long [updateMoney] waits for the server before writing offline.
  static const Duration moneyTransactionTimeout = Duration(seconds: 5);

  /// Whether a failed money transaction means "no server now" (then the
  /// local copy is written); anything else (rules, missing order) is real.
  static bool isOfflineFailure(Object error) {
    if (error is TimeoutException) return true;
    if (error is FirebaseException) {
      return const {'unavailable', 'deadline-exceeded'}.contains(error.code);
    }
    return false;
  }

  /// Saves [fields] together with the money of the order. Online, a
  /// transaction reads the order, applies the items and discount the app
  /// changed ([appMoney]) and recomputes the total from that
  /// ([OrderFieldDiff.mergeMoney]): an item added elsewhere stays and the
  /// total counts it.
  ///
  /// Offline the order can't be read in a transaction. Then the four money
  /// fields go as the app has them ([localMoney]), so the stored total
  /// always matches the stored items and discount (an item added elsewhere
  /// in the meantime is replaced, as the old full save did). Not awaited:
  /// offline the write completes only once synced.
  Future<void> updateMoney(
    String companyId,
    String orderId,
    Map<String, dynamic> fields, {
    required Map<String, dynamic> appMoney,
    required Map<String, dynamic> localMoney,
    UserAggr? actor,
  }) async {
    final ref = collectionFor(companyId).doc(orderId);
    final user = actor ?? Global.userAggr;
    try {
      await firestore.runTransaction<void>(timeout: moneyTransactionTimeout, (
        tx,
      ) async {
        final snap = await tx.get(ref);
        if (!snap.exists) {
          throw StateError('Order $orderId does not exist');
        }
        final money = OrderFieldDiff.mergeMoney(snap.data()!, appMoney);
        tx.update(ref, fieldUpdateOf({...fields, ...money}, actor: user));
      });
    } catch (e) {
      if (!isOfflineFailure(e)) rethrow;
      unawaited(
        ref
            .update(fieldUpdateOf({...fields, ...localMoney}, actor: user))
            .catchError((Object e) {
              debugPrint('Offline order money write failed: $e');
            }),
      );
    }
  }

  /// Firestore map for [updateFields]: [DeleteFieldOp] becomes
  /// `FieldValue.delete()`, payment fields are dropped and the audit fields
  /// are the acting user's.
  static Map<String, dynamic> fieldUpdateOf(
    Map<String, dynamic> fields, {
    UserAggr? actor,
    DateTime? now,
  }) {
    final result = <String, dynamic>{};
    fields.forEach((key, value) {
      if (OrderFieldDiff.ignoredFields.contains(key)) return;
      result[key] = value is DeleteFieldOp ? FieldValue.delete() : value;
    });
    result['updatedAt'] = (now ?? DateTime.now()).toIso8601String();
    if (actor != null) result['updatedBy'] = actor.toJson();
    return result;
  }

  /// Generates the order of the due date [due] of contract [templateId] in
  /// one transaction, like the server job (contract.service.ts): reads the
  /// template again, checks it still generates that date
  /// ([contractAdvanceUpdate]: running, not paused, same next date), creates
  /// the order with [build] from the fresh template (id from
  /// `contractOrderId`, the same the server uses) unless it already exists,
  /// and writes only the `contract.*` fields that move. Returns the order
  /// created here, or null.
  ///
  /// The list of templates may come from the cache: a contract stopped or
  /// paused on the web since then gets no order and is not turned back on.
  Future<Order?> createContractOrder(
    String companyId, {
    required String templateId,
    required DateTime due,
    required DateTime now,
    required Order Function(Order template) build,
  }) async {
    final collection = collectionFor(companyId);
    final orderRef = collection.doc(contractOrderId(templateId, due));
    final templateRef = collection.doc(templateId);
    // Everyone who generates (admin, supervisor or the template's author)
    // can read the order of the due date before it exists (the rules allow
    // `get` of a missing `contract_*` order), so it is always a transaction.
    return firestore.runTransaction<Order?>((tx) async {
      final templateSnap = await tx.get(templateRef);
      final existing = await tx.get(orderRef);
      final data = templateSnap.data();
      final update = contractAdvanceUpdate(
        data,
        due: due,
        now: now,
        orderExists: existing.exists,
      );
      if (update == null) return null;
      Order? created;
      if (!existing.exists) {
        final template = fromJson({...data!, 'id': templateId});
        created = build(template)..id = orderRef.id;
        tx.set(orderRef, toJson(created)..remove('id'));
      }
      tx.update(templateRef, update);
      return created;
    });
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
    return collectionFor(companyId)
        .doc(orderId)
        .update(toFirestoreUpdate(update, actor: actor ?? Global.userAggr));
  }

  /// Saves the "parada" mark on its own, or removes it when [hold] is null:
  /// `Order.toJson` leaves it out, so a full save never touches it. No
  /// transaction: works offline.
  Future<void> setHold(
    String companyId,
    String orderId,
    OrderHold? hold, {
    UserAggr? actor,
  }) {
    final user = actor ?? Global.userAggr;
    return collectionFor(companyId).doc(orderId).update({
      'onHold': hold == null ? FieldValue.delete() : hold.toJson(),
      'updatedAt': DateTime.now().toIso8601String(),
      if (user != null) 'updatedBy': user.toJson(),
    });
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
    final snap = await collectionFor(
      companyId,
    ).doc(orderId).get(const GetOptions(source: Source.server));
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
        final week = reportWeek(now, offset);
        startDate = week.start;
        endDate = week.end;
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
    // Errors are not swallowed: an empty list here showed R$ 0 for a month
    // that failed to load; callers show the error and offer to retry.
    final List<QueryArgs> filterList = [
      QueryArgs(
        'createdAt',
        startDate.toIso8601String(),
        oper: 'isGreaterThanOrEqualTo',
      ),
      QueryArgs('createdAt', endDate.toIso8601String(), oper: 'isLessThan'),
    ];

    final List<OrderBy> orderBy = [OrderBy('createdAt', descending: true)];

    return getQueryList(companyId, orderBy: orderBy, args: filterList);
  }

  /// Busca todas as orders que não estão pagas, de qualquer período. Covers
  /// the legacy 'partial' and active orders with `payment: null`, which an
  /// order approved outside the app keeps (that write sets only the status).
  /// Orders without the field at all need the backfill script. Equality
  /// filters only: no composite index. Errors are not swallowed so callers
  /// can show a retry state.
  Future<List<Order?>> getUnpaidOrders(String companyId) async {
    final results = await Future.wait([
      getQueryList(
        companyId,
        args: [
          QueryArgs('payment', ['unpaid', 'partial'], oper: 'whereIn'),
        ],
      ),
      getQueryList(
        companyId,
        args: [
          QueryArgs('payment', true, oper: 'isNull'),
          QueryArgs('status', [
            'approved',
            'progress',
            'done',
          ], oper: 'whereIn'),
        ],
      ),
    ]);
    return results.expand((orders) => orders).toList();
  }

  /// Orders with a payment dated from [since] on, whenever they were
  /// created. `lastPaymentAt` is a UTC ISO string kept by the server.
  /// Single-field range: needs no composite index. Errors are not swallowed
  /// so callers can show a retry state.
  Future<List<Order?>> getOrdersPaidSince(String companyId, DateTime since) {
    return getQueryList(
      companyId,
      args: [
        QueryArgs(
          'lastPaymentAt',
          since.toUtc().toIso8601String(),
          oper: 'isGreaterThanOrEqualTo',
        ),
      ],
    );
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
      QueryArgs('scheduledDate', endDate.toIso8601String(), oper: 'isLessThan'),
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
      QueryArgs('dueDate', endDate.toIso8601String(), oper: 'isLessThan'),
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
    String? createdById,
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

    // Only the orders this user created (consultant/technician: the rules
    // deny any query that could return someone else's order). Equality
    // filters only, so no composite index is needed; newest first is sorted
    // here instead of in the query.
    if (createdById != null) {
      filterList.add(QueryArgs('createdBy.id', createdById));
      return streamQueryList(companyId, args: filterList).map(
        (list) => list.toList()
          ..sort(
            (a, b) => (b?.createdAt ?? DateTime(0)).compareTo(
              a?.createdAt ?? DateTime(0),
            ),
          ),
      );
    }

    return streamQueryList(companyId, orderBy: orderBy, args: filterList);
  }

  /// Stream de orders que contêm um device específico.
  ///
  /// Older orders have only `device` (no `deviceIds`), so both are queried
  /// and merged; otherwise the vehicle screen missed most of its history.
  Stream<List<Order?>> streamOrdersByDevice(String companyId, String deviceId) {
    return mergeOrderStreams(
      streamQueryList(
        companyId,
        args: [QueryArgs('deviceIds', deviceId, oper: 'arrayContains')],
      ),
      streamQueryList(companyId, args: [QueryArgs('device.id', deviceId)]),
    );
  }

  /// The device's orders once, from both the current and the legacy field.
  Future<List<Order>> getOrdersByDevice(
    String companyId,
    String deviceId,
  ) async {
    final lists = await Future.wait([
      getQueryList(
        companyId,
        args: [QueryArgs('deviceIds', deviceId, oper: 'arrayContains')],
      ),
      getQueryList(companyId, args: [QueryArgs('device.id', deviceId)]),
    ]);
    final byId = <String?, Order>{};
    for (final order in lists.expand((list) => list).whereType<Order>()) {
      byId[order.id] = order;
    }
    return byId.values.toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  // Child orders (generated from contract templates)
  // ═══════════════════════════════════════════════════════════════════

  /// Stream of orders generated from a contract template.
  /// No orderBy to avoid composite index requirement — sorted client-side.
  Stream<List<Order?>> streamChildOrders(
    String companyId,
    String parentOrderId,
  ) {
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
    return streamQueryList(companyId, args: [QueryArgs('isContract', true)]);
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
