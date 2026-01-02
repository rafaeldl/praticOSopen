import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/config/feature_flags.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/repositories/tenant_order_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrderRepository extends Repository<Order?> {
  static String collectionName = 'orders';
  final TenantOrderRepository _tenantRepo = TenantOrderRepository();

  OrderRepository() : super(collectionName);

  @override
  Order fromJson(data) => Order.fromJson(data);

  @override
  Map<String, dynamic> toJson(Order? order) => order!.toJson();

  Future<String?> _getCompanyId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('companyId');
  }

  @override
  Future<dynamic> createItem(Order? item, {String? id}) async {
    if (FeatureFlags.useNewTenantStructure) {
      final companyId = await _getCompanyId();
      if (companyId != null && companyId.isNotEmpty) {

        // Ensure ID consistency if dual write
        if (item?.id == null && id != null) {
          item?.id = id;
        }

        await _tenantRepo.save(companyId, item!);

        // If we have dual write disabled, we stop here.
        // But we must return something similar to what base createItem returns.
        // base createItem returns Future<dynamic> which is the result of add() or set().
        if (!FeatureFlags.dualWriteEnabled) {
          return null; // or Future.value(null)
        }
      }
    }

    // Legacy/Dual Write behavior
    // We pass the ID if it was generated/assigned in the block above (item.id)
    return super.createItem(item, id: item?.id ?? id);
  }

  @override
  Future<void> updateItem(Order? item) async {
    if (FeatureFlags.useNewTenantStructure) {
      final companyId = await _getCompanyId();
      if (companyId != null && companyId.isNotEmpty) {
        await _tenantRepo.save(companyId, item!);

        if (!FeatureFlags.dualWriteEnabled) {
          return;
        }
      }
    }

    // Legacy/Dual Write behavior
    return super.updateItem(item);
  }

  @override
  Future<void> removeItem(String? id) async {
    if (id == null) return;

    if (FeatureFlags.useNewTenantStructure) {
      final companyId = await _getCompanyId();
      if (companyId != null && companyId.isNotEmpty) {
        await _tenantRepo.remove(companyId, id);

        if (!FeatureFlags.dualWriteEnabled) {
          return;
        }
      }
    }

    // Legacy/Dual Write behavior
    return super.removeItem(id);
  }

  Future<List<Order?>> getOrders() async {
    final companyId = await _getCompanyId();
    if (companyId == null) return [];

    if (FeatureFlags.useNewTenantStructure) {
      try {
        final stream = _tenantRepo.streamQuery(
          companyId,
          orderBy: [QueryOrder('createdAt', descending: true)],
        );

        if (FeatureFlags.dualReadEnabled) {
          return stream.handleError((e) {
             print('Fallback to legacy orders: $e');
             throw e; // This will be caught by the outer catch block if we await it, but here it's inside stream.
             // Since we return stream.first, the error propagates to the awaiter of first.
          }).first;
        }
        return stream.first;
      } catch (e) {
        if (FeatureFlags.dualReadEnabled) {
           // Fallthrough to legacy
        } else {
          rethrow;
        }
      }
    }

    List<QueryArgs> filterList = [QueryArgs('company.id', companyId)];
    List<OrderBy> orderBy = [OrderBy('createdAt', descending: true)];

    final stream = streamQueryList(orderBy: orderBy, args: filterList);
    final snapshot = await stream.first;
    return snapshot;
  }

  // Método para buscar uma ordem pelo número
  Future<Order?> getOrderByNumber(int number) async {
    final companyId = await _getCompanyId();
    if (companyId == null) return null;

    if (FeatureFlags.useNewTenantStructure) {
      try {
        final stream = _tenantRepo.streamQuery(
          companyId,
          filters: [QueryFilter('number', FilterOperator.isEqualTo, number)],
        );
        final list = await stream.first;
        if (list.isNotEmpty) return list.first;
         // If empty, check dual read?
         // If list is empty it means not found, not necessarily an error.
         // But if migration is partial, maybe we check legacy.
         if (!FeatureFlags.dualReadEnabled) return null;
      } catch (e) {
         if (!FeatureFlags.dualReadEnabled) rethrow;
      }
    }

    List<QueryArgs> filterList = [
      QueryArgs('company.id', companyId),
      QueryArgs('number', number)
    ];

    try {
      final orders = await getQueryList(args: filterList);
      return orders.isNotEmpty ? orders.first : null;
    } catch (e) {
      print('Erro ao buscar ordem pelo número: $e');
      return null;
    }
  }

  Future<List<Order?>> getOrdersByPeriod(String period) async {
    // Simplesmente usar o método customizado com offset zero
    return await getOrdersByCustomPeriod(period, 0);
  }

  Future<List<Order?>> getOrdersByCustomPeriod(
      String period, int offset) async {
    final companyId = await _getCompanyId();
    if (companyId == null) return [];

    // Datas de início e fim
    DateTime now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    // Definir início e fim baseado no período
    switch (period) {
      case 'hoje':
        // Simplificado: calcula o dia com o offset aplicado
        DateTime targetDay = now.add(Duration(days: offset));
        startDate = DateTime(targetDay.year, targetDay.month, targetDay.day);
        endDate = DateTime(targetDay.year, targetDay.month, targetDay.day + 1);
        break;

      case 'semana':
        // Calcula a semana do ano atual + offset
        int currentWeek =
            ((now.difference(DateTime(now.year, 1, 1)).inDays) / 7).floor();
        int targetWeek = currentWeek + offset;

        // Calcula o primeiro dia da semana alvo
        startDate =
            DateTime(now.year, 1, 1).add(Duration(days: targetWeek * 7));
        // Ajusta para domingo
        startDate = startDate.subtract(Duration(days: startDate.weekday));
        // Fim da semana (sábado)
        endDate = startDate.add(Duration(days: 7));
        break;

      case 'mês':
        // Cálculo do mês com offset // now + offset months
        startDate = DateTime(now.year, now.month + offset, 1);
        endDate = DateTime(now.year, now.month + offset + 1, 1);
        break;

      case 'ano':
        // Cálculo do ano com offset
        int targetYear = now.year + offset;
        startDate = DateTime(targetYear, 1, 1);
        endDate = DateTime(targetYear + 1, 1, 1);
        break;

      default:
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 1);
    }

    if (FeatureFlags.useNewTenantStructure) {
       try {
         final stream = _tenantRepo.streamQuery(
            companyId,
            filters: [
              // Removing .toIso8601String() to pass DateTime directly
              QueryFilter('createdAt', FilterOperator.isGreaterThanOrEqualTo, startDate),
              QueryFilter('createdAt', FilterOperator.isLessThan, endDate),
            ],
            orderBy: [QueryOrder('createdAt', descending: true)]
         );
         return await stream.first;
       } catch (e) {
          if (!FeatureFlags.dualReadEnabled) return [];
       }
    }

    try {
      // Adicionar filtros incluindo os de data
      List<QueryArgs> filterList = [
        QueryArgs('company.id', companyId),
        QueryArgs('createdAt', startDate.toIso8601String(),
            oper: 'isGreaterThanOrEqualTo'),
        QueryArgs('createdAt', endDate.toIso8601String(), oper: 'isLessThan')
      ];

      // Configurar ordenação
      List<OrderBy> orderBy = [OrderBy('createdAt', descending: true)];

      // Obter os dados
      final stream = streamQueryList(orderBy: orderBy, args: filterList);
      final snapshot = await stream.first;

      return snapshot;
    } catch (e) {
      print('Erro ao buscar ordens por período: $e');
      return [];
    }
  }

  Future<List<Order?>> getOrdersByDateRange(
      DateTime startDate, DateTime endDate) async {
    final companyId = await _getCompanyId();
    if (companyId == null) return [];

    if (FeatureFlags.useNewTenantStructure) {
       try {
         final stream = _tenantRepo.streamQuery(
            companyId,
            filters: [
              // Removing .toIso8601String() to pass DateTime directly
              QueryFilter('createdAt', FilterOperator.isGreaterThanOrEqualTo, startDate),
              QueryFilter('createdAt', FilterOperator.isLessThan, endDate),
            ],
            orderBy: [QueryOrder('createdAt', descending: true)]
         );
         return await stream.first;
       } catch (e) {
          if (!FeatureFlags.dualReadEnabled) return [];
       }
    }

    try {
      // Adicionar filtros incluindo os de data
      List<QueryArgs> filterList = [
        QueryArgs('company.id', companyId),
        QueryArgs('createdAt', startDate.toIso8601String(),
            oper: 'isGreaterThanOrEqualTo'),
        QueryArgs('createdAt', endDate.toIso8601String(), oper: 'isLessThan')
      ];

      // Configurar ordenação
      List<OrderBy> orderBy = [OrderBy('createdAt', descending: true)];

      // Obter os dados
      final stream = streamQueryList(orderBy: orderBy, args: filterList);
      final snapshot = await stream.first;

      return snapshot;
    } catch (e) {
      print('Erro ao buscar ordens por intervalo de datas: $e');
      return [];
    }
  }
}
