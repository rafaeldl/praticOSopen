import 'dart:async';

import 'package:praticos/models/order.dart';
import 'package:praticos/repositories/tenant/tenant_order_repository.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/global.dart';
import 'package:mobx/mobx.dart';
import 'package:praticos/services/notification_service.dart';
import 'package:praticos/services/segment_config_service.dart';
import 'package:praticos/mobx/reminder_store.dart';

part 'agenda_store.g.dart';

class AgendaStore = _AgendaStore with _$AgendaStore;

abstract class _AgendaStore with Store {
  final TenantOrderRepository repository = TenantOrderRepository();
  final AuthorizationService _authService = AuthorizationService.instance;
  StreamSubscription<List<Order?>>? _monthSubscription;
  ReminderStore? _reminderStore;

  bool get _useScheduling => SegmentConfigService().useScheduling;

  /// Set the reminder store reference (call from UI after provider is available)
  void setReminderStore(ReminderStore store) {
    _reminderStore = store;
  }

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

  /// Returns the relevant date for an order based on scheduling mode
  DateTime? _orderDate(Order? order) {
    return _useScheduling ? order?.scheduledDate : order?.dueDate;
  }

  @computed
  List<Order?> get ordersForSelectedDate {
    final day = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final nextDay = day.add(const Duration(days: 1));

    final dayOrders = filteredOrders.where((order) {
      final date = _orderDate(order);
      if (date == null) return false;
      return date.isAfter(day.subtract(const Duration(seconds: 1))) &&
             date.isBefore(nextDay);
    }).toList();

    // Sort: orders with time (not midnight) first, then midnight ("all day") at end
    dayOrders.sort((a, b) {
      final aDate = _orderDate(a) ?? DateTime(2099);
      final bDate = _orderDate(b) ?? DateTime(2099);
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
      final date = _orderDate(order);
      if (date == null) continue;
      final dayKey = DateTime(date.year, date.month, date.day);
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
  void loadMonth(DateTime month) {
    if (companyId == null) return;

    isLoading = true;
    focusedMonth = DateTime(month.year, month.month);

    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 1);

    _monthSubscription?.cancel();

    final stream = _useScheduling
        ? repository.streamOrdersByScheduledDateRange(companyId!, startDate, endDate)
        : repository.streamOrdersByDueDateRange(companyId!, startDate, endDate);

    _monthSubscription = stream.listen(
      (result) {
        orders.clear();
        orders.addAll(result);
        isLoading = false;
        if (_useScheduling) _rescheduleReminders(result);
      },
      onError: (e) {
        print('Erro ao carregar agenda: $e');
        isLoading = false;
      },
    );
  }

  /// Reschedule reminders for all future orders with a scheduledDate
  void _rescheduleReminders(List<Order?> loadedOrders) {
    final minutes = _reminderStore?.reminderMinutes ?? 0;
    if (minutes <= 0) return;

    final now = DateTime.now();
    for (final order in loadedOrders) {
      if (order == null || order.id == null || order.scheduledDate == null) continue;
      if (order.scheduledDate!.isBefore(now)) continue;

      final orderNumber = order.number?.toString() ?? '';
      final customerName = order.customer?.name ?? '';

      NotificationService.instance.scheduleOrderReminder(
        orderId: order.id!,
        title: 'Agendamento em breve',
        body: 'OS #$orderNumber - $customerName',
        scheduledDate: order.scheduledDate!,
        minutesBefore: minutes,
        companyId: companyId,
      );
    }
  }

  void dispose() {
    _monthSubscription?.cancel();
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
