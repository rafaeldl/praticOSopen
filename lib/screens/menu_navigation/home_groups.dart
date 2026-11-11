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
  mine,

  /// Quotes still waiting for an answer, the ones waiting longest first.
  quotes,

  /// Open orders marked "parada", the ones stopped longest first.
  onHold,

  /// Open orders past their due date, the most overdue first.
  late,

  /// Completed orders not received yet, the most recent first.
  unpaid;

  /// Status field understood by `OrderStore.loadOrdersInfinite`.
  String? get queryField => switch (this) {
    HomeView.open => 'open',
    HomeView.done => 'done',
    HomeView.all => null,
    HomeView.mine => 'open',
    HomeView.quotes => 'open',
    HomeView.onHold => 'open',
    HomeView.late => 'open',
    HomeView.unpaid => 'unpaid_done',
  };

  /// Views that load every open order (so counts are exact).
  bool get isOpenList =>
      this == HomeView.open ||
      this == HomeView.mine ||
      this == HomeView.quotes ||
      this == HomeView.onHold ||
      this == HomeView.late;
}

/// Urgency of an open order, in list order.
enum HomeGroup { late, dueToday, inProgress, waitingApproval, approved }

/// Pure rules for the Início list (kept out of the widget for testing).
class HomeRules {
  HomeRules._();

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool isFinished(Order o) =>
      o.status == 'done' || o.status == 'canceled';

  static bool isOverdue(Order o, DateTime now) =>
      isOverdueAt(status: o.status, due: o.dueDate, now: now);

  /// Same rule from the fields: the promised day is behind (day, not time)
  /// and the order is neither done nor canceled. The order screen uses it
  /// too, so the list and the order agree.
  static bool isOverdueAt({
    required String? status,
    required DateTime? due,
    required DateTime now,
  }) {
    if (due == null || status == 'done' || status == 'canceled') return false;
    return _day(due).isBefore(_day(now));
  }

  /// Whole days past the due date (0 when not overdue).
  static int overdueDays(Order o, DateTime now) {
    if (!isOverdue(o, now)) return 0;
    return _day(now).difference(_day(o.dueDate!)).inDays;
  }

  /// How long an order is overdue, in the unit people say out loud: days up
  /// to a month, then months, then years ("Atrasada há 6 anos", not
  /// "Atrasada 2190 dias").
  static (OverdueUnit, int) overdueSpan(Order o, DateTime now) {
    final days = overdueDays(o, now);
    if (days >= 365) return (OverdueUnit.years, days ~/ 365);
    if (days >= 30) return (OverdueUnit.months, days ~/ 30);
    return (OverdueUnit.days, days);
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

  /// Quotes without an answer, the ones waiting longest first.
  static List<Order> waitingQuotes(List<Order> orders) {
    final quotes = orders.where((o) => o.status == 'quote').toList();
    return quotes
      ..sort(
        (a, b) => (a.createdAt ?? DateTime(0)).compareTo(
          b.createdAt ?? DateTime(0),
        ),
      );
  }

  /// Orders marked "parada", the ones stopped longest first.
  static List<Order> stopped(List<Order> orders) {
    final items = orders.where((o) => o.isOnHold).toList();
    return items
      ..sort(
        (a, b) => (a.onHold!.since ?? DateTime(0)).compareTo(
          b.onHold!.since ?? DateTime(0),
        ),
      );
  }

  /// Orders past their due date, the most overdue first.
  static List<Order> overdue(List<Order> orders, DateTime now) {
    final items = orders.where((o) => isOverdue(o, now)).toList();
    return items..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
  }

  /// Completed orders not received yet ("Sem receber"), in the incoming
  /// order. The query already asks for these; the check keeps a list read
  /// with a customer filter (no status in that query) right.
  static List<Order> unpaidDone(List<Order> orders) => orders
      .where((o) => o.status == 'done' && o.payment == 'unpaid')
      .toList();

  static const _accents = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n',
  };

  /// Lower case without accents: "orcamento" finds "Orçamento".
  static String searchKey(String text) => text
      .toLowerCase()
      .split('')
      .map((c) => _accents[c] ?? c)
      .join();

  /// Whether [query] (already a [searchKey]) is in the order's number,
  /// customer, status, or any device name or serial.
  static bool matchesSearch(Order o, String query, String statusLabel) {
    final fields = [
      o.number?.toString() ?? '',
      o.customer?.name ?? '',
      statusLabel,
      for (final d in o.effectiveDevices) ...[d.name ?? '', d.serial ?? ''],
    ];
    return fields.any((field) => searchKey(field).contains(query));
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

/// Unit of [HomeRules.overdueSpan].
enum OverdueUnit { days, months, years }
