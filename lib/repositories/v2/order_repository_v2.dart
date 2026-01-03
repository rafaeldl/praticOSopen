import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:praticos/config/feature_flags.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/repositories/order_repository.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/repositories/tenant/tenant_order_repository.dart';
import 'package:praticos/repositories/tenant_repository.dart';
import 'package:praticos/repositories/v2/repository_v2.dart';

/// Repository V2 para Orders com suporte a dual-write/dual-read.
class OrderRepositoryV2 extends RepositoryV2<Order?> {
  final OrderRepository _legacy = OrderRepository();
  final TenantOrderRepository _tenant = TenantOrderRepository();

  @override
  Repository<Order?> get legacyRepo => _legacy;

  @override
  TenantRepository<Order?> get tenantRepo => _tenant;

  // ═══════════════════════════════════════════════════════════════════
  // Order-specific methods
  // ═══════════════════════════════════════════════════════════════════

  /// Busca todas as orders do tenant.
  Future<List<Order?>> getOrders(String companyId) async {
    if (FeatureFlags.shouldReadFromNew) {
      try {
        return await _tenant.getOrders(companyId);
      } catch (e) {
        if (FeatureFlags.shouldFallbackToLegacy) {
          print('[OrderRepositoryV2] Fallback getOrders: $e');
          return await _legacy.getOrders();
        }
        rethrow;
      }
    }
    return await _legacy.getOrders();
  }

  /// Busca uma order pelo número.
  Future<Order?> getOrderByNumber(String companyId, int number) async {
    if (FeatureFlags.shouldReadFromNew) {
      try {
        return await _tenant.getOrderByNumber(companyId, number);
      } catch (e) {
        if (FeatureFlags.shouldFallbackToLegacy) {
          print('[OrderRepositoryV2] Fallback getOrderByNumber: $e');
          return await _legacy.getOrderByNumber(number);
        }
        rethrow;
      }
    }
    return await _legacy.getOrderByNumber(number);
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
    if (FeatureFlags.shouldReadFromNew) {
      try {
        return await _tenant.getOrdersByCustomPeriod(companyId, period, offset);
      } catch (e) {
        if (FeatureFlags.shouldFallbackToLegacy) {
          print('[OrderRepositoryV2] Fallback getOrdersByCustomPeriod: $e');
          return await _legacy.getOrdersByCustomPeriod(period, offset);
        }
        rethrow;
      }
    }
    return await _legacy.getOrdersByCustomPeriod(period, offset);
  }

  /// Busca orders por intervalo de datas.
  Future<List<Order?>> getOrdersByDateRange(
    String companyId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (FeatureFlags.shouldReadFromNew) {
      try {
        return await _tenant.getOrdersByDateRange(companyId, startDate, endDate);
      } catch (e) {
        if (FeatureFlags.shouldFallbackToLegacy) {
          print('[OrderRepositoryV2] Fallback getOrdersByDateRange: $e');
          return await _legacy.getOrdersByDateRange(startDate, endDate);
        }
        rethrow;
      }
    }
    return await _legacy.getOrdersByDateRange(startDate, endDate);
  }

  /// Stream de orders com filtros opcionais.
  Stream<List<Order?>> streamOrders(
    String companyId, {
    String? status,
    String? payment,
    String? customerId,
  }) {
    if (FeatureFlags.shouldReadFromNew) {
      final stream = _tenant.streamOrders(
        companyId,
        status: status,
        payment: payment,
        customerId: customerId,
      );

      if (FeatureFlags.shouldFallbackToLegacy) {
        return stream.handleError((error) {
          print('[OrderRepositoryV2] Fallback streamOrders: $error');
          // Fallback para método legado
          List<QueryArgs> filterList = [QueryArgs('company.id', companyId)];
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

          if (customerId != null) {
            filterList.add(QueryArgs('customer.id', customerId));
          }

          return _legacy.streamQueryList(orderBy: orderBy, args: filterList);
        });
      }

      return stream;
    }

    // Estrutura legada
    List<QueryArgs> filterList = [QueryArgs('company.id', companyId)];
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

    if (customerId != null) {
      filterList.add(QueryArgs('customer.id', customerId));
    }

    return _legacy.streamQueryList(orderBy: orderBy, args: filterList);
  }

  // ═══════════════════════════════════════════════════════════════════
  // Pagination Support
  // ═══════════════════════════════════════════════════════════════════

  /// Busca orders com paginação (para scroll infinito).
  Future<QuerySnapshot<Map<String, dynamic>>> getOrdersWithPagination(
    String companyId, {
    String? status,
    String? customerId,
    int limit = 10,
    DocumentSnapshot? startAfterDocument,
  }) async {
    final FirebaseFirestore db = FirebaseFirestore.instance;

    Query<Map<String, dynamic>> query;

    if (FeatureFlags.shouldReadFromNew) {
      // Nova estrutura: subcollection
      query = db.collection('companies').doc(companyId).collection('orders');
    } else {
      // Estrutura legada: collection raiz com filtro
      query = db.collection('orders').where('company.id', isEqualTo: companyId);
    }

    // Aplicar filtros
    if (status != null) {
      if (['paid', 'unpaid'].contains(status)) {
        query = query.where('payment', isEqualTo: status);
      } else if (status == 'due_date') {
        query = query.where('status', whereIn: ['approved', 'progress']);
        query = query.orderBy('dueDate');
      } else if (status != 'Todos') {
        query = query.where('status', isEqualTo: status);
      }
    }

    if (customerId != null) {
      query = query.where('customer.id', isEqualTo: customerId);
    }

    // Ordenação padrão (se não for due_date)
    if (status != 'due_date') {
      query = query.orderBy('createdAt', descending: true);
    }

    // Paginação
    if (startAfterDocument != null) {
      query = query.startAfterDocument(startAfterDocument);
    }

    query = query.limit(limit);

    return query.get();
  }
}
