import 'package:praticos/models/order.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrderRepository extends Repository<Order?> {
  static String collectionName = 'orders';

  OrderRepository() : super(collectionName);

  @override
  Order fromJson(data) => Order.fromJson(data);

  @override
  Map<String, dynamic> toJson(Order? order) => order!.toJson();

  Future<List<Order?>> getOrders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? companyId = prefs.getString('companyId');

    List<QueryArgs> filterList = [QueryArgs('company.id', companyId)];
    List<OrderBy> orderBy = [OrderBy('createdAt', descending: true)];

    final stream = streamQueryList(orderBy: orderBy, args: filterList);
    final snapshot = await stream.first;
    return snapshot;
  }

  // Método para buscar uma ordem pelo número
  Future<Order?> getOrderByNumber(int number) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? companyId = prefs.getString('companyId');
    if (companyId == null) companyId = '';

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
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? companyId = prefs.getString('companyId');
    if (companyId == null) companyId = '';

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
}
