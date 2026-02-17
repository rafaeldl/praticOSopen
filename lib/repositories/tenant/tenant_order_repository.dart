import 'package:praticos/models/order.dart';
import 'package:praticos/repositories/tenant_repository.dart';
import 'package:praticos/repositories/repository.dart';

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

      return getQueryList(companyId, orderBy: orderBy, args: filterList);
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

      return getQueryList(companyId, orderBy: orderBy, args: filterList);
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
}
