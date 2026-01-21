import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:praticos/models/order.dart';
import 'package:praticos/repositories/tenant/tenant_order_repository.dart';
import 'package:praticos/repositories/tenant_repository.dart';
import 'package:praticos/repositories/v2/repository_v2.dart';

/// Repository V2 para Orders usando subcollections por tenant.
///
/// Path: `/companies/{companyId}/orders/{orderId}`
class OrderRepositoryV2 extends RepositoryV2<Order?> {
  final TenantOrderRepository _tenant = TenantOrderRepository();

  @override
  TenantRepository<Order?> get tenantRepo => _tenant;

  // ═══════════════════════════════════════════════════════════════════
  // Order-specific methods
  // ═══════════════════════════════════════════════════════════════════

  /// Busca todas as orders do tenant.
  Future<List<Order?>> getOrders(String companyId) async {
    return await _tenant.getOrders(companyId);
  }

  /// Busca uma order pelo número.
  Future<Order?> getOrderByNumber(String companyId, int number) async {
    return await _tenant.getOrderByNumber(companyId, number);
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
    return await _tenant.getOrdersByCustomPeriod(companyId, period, offset);
  }

  /// Busca orders por intervalo de datas.
  Future<List<Order?>> getOrdersByDateRange(
    String companyId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    return await _tenant.getOrdersByDateRange(companyId, startDate, endDate);
  }

  /// Stream de orders com filtros opcionais.
  Stream<List<Order?>> streamOrders(
    String companyId, {
    String? status,
    String? payment,
    String? customerId,
  }) {
    return _tenant.streamOrders(
      companyId,
      status: status,
      payment: payment,
      customerId: customerId,
    );
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

    Query<Map<String, dynamic>> query =
        db.collection('companies').doc(companyId).collection('orders');

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

    // Ordenação baseada no filtro:
    // - Todos (null) e Não lidas ('unread'): updatedAt (atividade recente)
    // - Entrega ('due_date'): dueDate (já tratado acima)
    // - Demais filtros: createdAt (data de criação)
    if (status != 'due_date') {
      if (status == null || status == 'unread') {
        query = query.orderBy('updatedAt', descending: true);
      } else {
        query = query.orderBy('createdAt', descending: true);
      }
    }

    // Paginação
    if (startAfterDocument != null) {
      query = query.startAfterDocument(startAfterDocument);
    }

    query = query.limit(limit);

    return query.get();
  }
}
