import 'package:praticos/models/order.dart';

/// Which list the Início screen is showing.
enum HomeView {
  /// Quotes, approved and in progress orders, grouped by urgency.
  open,

  /// Every order, one continuous list with a section per month.
  all,

  /// Canceled orders ("…" menu).
  canceled;

  /// Status field understood by `OrderStore.loadOrdersInfinite`.
  String? get queryField => switch (this) {
    HomeView.open => 'open',
    HomeView.all => null,
    HomeView.canceled => 'canceled',
  };

  /// Whether the "Em aberto | Todas" toggle is shown in this view.
  bool get isSegmented => this == HomeView.open || this == HomeView.all;
}

/// Urgency sections of the "Em aberto" list, in display order.
enum HomeGroup { late, dueToday, inProgress, waitingApproval, approved }

/// What the "next step" block asks the owner to look at.
enum NextStepKind { late, dueToday, quotesWaiting }

class NextStep {
  const NextStep(this.kind, this.count, this.target);

  final NextStepKind kind;
  final int count;

  /// Section the link scrolls to.
  final HomeGroup target;
}

/// Pure rules for the Início list (kept out of the widget for testing).
class HomeRules {
  HomeRules._();

  /// Quotes/approved orders older than this many days count as "waiting".
  static const int staleQuoteDays = 7;

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
  static Map<HomeGroup, List<Order>> groupOpen(List<Order> orders, DateTime now) {
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
      final key = created == null ? null : DateTime(created.year, created.month);
      if (result.isNotEmpty && result.last.key == key) {
        result.last.value.add(o);
      } else {
        result.add(MapEntry(key, [o]));
      }
    }
    return result;
  }

  /// The one sentence for the next-step block, by priority: late, due today,
  /// stale quotes. Null when there is nothing to say.
  static NextStep? nextStep(List<Order> orders, DateTime now) {
    final open = orders.where((o) => !isFinished(o)).toList();
    final late = open.where((o) => isOverdue(o, now)).length;
    if (late > 0) return NextStep(NextStepKind.late, late, HomeGroup.late);
    final today = open.where((o) => isDueToday(o, now)).length;
    if (today > 0) {
      return NextStep(NextStepKind.dueToday, today, HomeGroup.dueToday);
    }
    final limit = now.subtract(const Duration(days: staleQuoteDays));
    final stale = open
        .where(
          (o) =>
              (o.status == 'quote' || o.status == 'approved') &&
              o.createdAt != null &&
              o.createdAt!.isBefore(limit),
        )
        .toList();
    if (stale.isNotEmpty) {
      final target = stale.any((o) => groupOf(o, now) == HomeGroup.waitingApproval)
          ? HomeGroup.waitingApproval
          : HomeGroup.approved;
      return NextStep(NextStepKind.quotesWaiting, stale.length, target);
    }
    return null;
  }
}
