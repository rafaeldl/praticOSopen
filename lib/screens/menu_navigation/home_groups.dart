import 'package:praticos/models/order.dart';

/// Which list the Início screen is showing (the filter buttons).
enum HomeView {
  /// Quotes, approved and in progress orders, overdue first.
  open,

  /// Completed orders, most recent first.
  done,

  /// Every order (canceled included), one section per month.
  all,

  /// Technician: the open orders assigned to them ("Minhas").
  mine;

  /// Status field understood by `OrderStore.loadOrdersInfinite`.
  String? get queryField => switch (this) {
    HomeView.open => 'open',
    HomeView.done => 'done',
    HomeView.all => null,
    HomeView.mine => 'open',
  };

  /// Views that load every open order (so counts are exact).
  bool get isOpenList => this == HomeView.open || this == HomeView.mine;
}

/// Urgency of an open order, in list order.
enum HomeGroup { late, dueToday, inProgress, waitingApproval, approved }

/// Pure rules for the Início list (kept out of the widget for testing).
class HomeRules {
  HomeRules._();

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool isFinished(Order o) =>
      o.status == 'done' || o.status == 'canceled';

  static bool isOverdue(Order o, DateTime now) {
    final due = o.dueDate;
    if (due == null || isFinished(o)) return false;
    return _day(due).isBefore(_day(now));
  }

  /// Whole days past the due date (0 when not overdue).
  static int overdueDays(Order o, DateTime now) {
    if (!isOverdue(o, now)) return 0;
    return _day(now).difference(_day(o.dueDate!)).inDays;
  }

  static bool isDueToday(Order o, DateTime now) {
    final due = o.dueDate;
    if (due == null || isFinished(o)) return false;
    return _day(due) == _day(now);
  }

  /// Section of an open order.
  static HomeGroup groupOf(Order o, DateTime now) {
    if (isOverdue(o, now)) return HomeGroup.late;
    if (isDueToday(o, now)) return HomeGroup.dueToday;
    switch (o.status) {
      case 'progress':
        return HomeGroup.inProgress;
      case 'quote':
        return HomeGroup.waitingApproval;
      default:
        return HomeGroup.approved;
    }
  }

  /// Groups open orders; empty groups are absent. Late and due-today sections
  /// are ordered by due date, the rest keeps the incoming order.
  static Map<HomeGroup, List<Order>> groupOpen(
    List<Order> orders,
    DateTime now,
  ) {
    final result = <HomeGroup, List<Order>>{};
    for (final group in HomeGroup.values) {
      final items = orders.where((o) => groupOf(o, now) == group).toList();
      if (group == HomeGroup.late || group == HomeGroup.dueToday) {
        items.sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
      }
      if (items.isNotEmpty) result[group] = items;
    }
    return result;
  }

  /// Orders grouped by creation month, keeping the incoming order. Orders
  /// without a creation date go in a trailing `null` group.
  static List<MapEntry<DateTime?, List<Order>>> groupByMonth(
    List<Order> orders,
  ) {
    final result = <MapEntry<DateTime?, List<Order>>>[];
    for (final o in orders) {
      final created = o.createdAt;
      final key = created == null
          ? null
          : DateTime(created.year, created.month);
      if (result.isNotEmpty && result.last.key == key) {
        result.last.value.add(o);
      } else {
        result.add(MapEntry(key, [o]));
      }
    }
    return result;
  }

  /// Open orders in list order: overdue first (oldest due date first),
  /// then due today, then the rest as they came (newest first).
  static List<Order> sortOpen(List<Order> orders, DateTime now) {
    final groups = groupOpen(orders, now);
    final urgent = [...?groups[HomeGroup.late], ...?groups[HomeGroup.dueToday]];
    return [...urgent, ...orders.where((o) => !urgent.contains(o))];
  }

  /// Overdue orders among [orders].
  static int lateCount(List<Order> orders, DateTime now) =>
      orders.where((o) => isOverdue(o, now)).length;

  /// Orders assigned to [userId] ("Minhas").
  static List<Order> assignedTo(List<Order> orders, String? userId) {
    if (userId == null) return const [];
    return orders.where((o) => o.assignedTo?.id == userId).toList();
  }

  static bool isScheduledToday(Order o, DateTime now) {
    final at = o.scheduledDate;
    if (at == null || isFinished(o)) return false;
    return _day(at) == _day(now);
  }

  /// Unfinished orders scheduled for today, by time.
  static List<Order> scheduledToday(List<Order> orders, DateTime now) {
    final items = orders.where((o) => isScheduledToday(o, now)).toList()
      ..sort((a, b) => a.scheduledDate!.compareTo(b.scheduledDate!));
    return items;
  }

  /// The technician's "Agora" order: today's first visit not started yet,
  /// else the first one still running. Null when nothing is scheduled today.
  static Order? nextVisit(List<Order> orders, DateTime now) {
    final today = scheduledToday(orders, now);
    if (today.isEmpty) return null;
    return today.firstWhere(
      (o) => o.status != 'progress',
      orElse: () => today.first,
    );
  }
}
