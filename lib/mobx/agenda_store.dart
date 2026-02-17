import 'package:praticos/models/order.dart';
import 'package:praticos/repositories/tenant/tenant_order_repository.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/global.dart';
import 'package:mobx/mobx.dart';

part 'agenda_store.g.dart';

class AgendaStore = _AgendaStore with _$AgendaStore;

abstract class _AgendaStore with Store {
  final TenantOrderRepository repository = TenantOrderRepository();
  final AuthorizationService _authService = AuthorizationService.instance;

  @observable
  DateTime selectedDate = DateTime.now();

  @observable
  DateTime focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @observable
  ObservableList<Order?> orders = ObservableList<Order?>();

  @observable
  String? selectedTechnicianId;

  @observable
  bool isLoading = false;

  @computed
  List<Order?> get ordersForSelectedDate {
    final day = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final nextDay = day.add(const Duration(days: 1));

    final dayOrders = filteredOrders.where((order) {
      if (order?.scheduledDate == null) return false;
      final sd = order!.scheduledDate!;
      return sd.isAfter(day.subtract(const Duration(seconds: 1))) &&
             sd.isBefore(nextDay);
    }).toList();

    // Sort: orders with time (not midnight) first, then midnight ("all day") at end
    dayOrders.sort((a, b) {
      final aDate = a?.scheduledDate ?? DateTime(2099);
      final bDate = b?.scheduledDate ?? DateTime(2099);
      final aIsMidnight = aDate.hour == 0 && aDate.minute == 0;
      final bIsMidnight = bDate.hour == 0 && bDate.minute == 0;

      if (aIsMidnight && !bIsMidnight) return 1;
      if (!aIsMidnight && bIsMidnight) return -1;
      return aDate.compareTo(bDate);
    });

    return dayOrders;
  }

  @computed
  Map<DateTime, int> get eventMarkers {
    final Map<DateTime, int> markers = {};
    for (final order in filteredOrders) {
      if (order?.scheduledDate == null) continue;
      final sd = order!.scheduledDate!;
      final dayKey = DateTime(sd.year, sd.month, sd.day);
      markers[dayKey] = (markers[dayKey] ?? 0) + 1;
    }
    return markers;
  }

  @computed
  List<Order?> get filteredOrders {
    var result = orders.toList();

    // Apply RBAC filter
    final filtered = _authService.filterOrdersByPermission(
      result.whereType<Order>().toList(),
    ).cast<Order?>();

    // Apply technician filter
    if (selectedTechnicianId != null) {
      return filtered.where((order) {
        return order?.assignedTo?.id == selectedTechnicianId;
      }).toList();
    }

    return filtered;
  }

  String? get companyId => Global.companyAggr?.id;

  @action
  Future<void> loadMonth(DateTime month) async {
    if (companyId == null) return;

    isLoading = true;
    focusedMonth = DateTime(month.year, month.month);

    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 1);

    try {
      final result = await repository.getOrdersByScheduledDateRange(
        companyId!,
        startDate,
        endDate,
      );

      orders.clear();
      orders.addAll(result);
    } catch (e) {
      print('Erro ao carregar agenda: $e');
    }

    isLoading = false;
  }

  @action
  void selectDate(DateTime date) {
    selectedDate = date;

    // If month changed, load new month data
    if (date.month != focusedMonth.month || date.year != focusedMonth.year) {
      loadMonth(date);
    }
  }

  @action
  void setTechnicianFilter(String? userId) {
    selectedTechnicianId = userId;
  }
}
