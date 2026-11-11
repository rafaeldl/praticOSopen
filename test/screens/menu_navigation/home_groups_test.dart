import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/screens/menu_navigation/home_groups.dart';

Order order(String status, {DateTime? due, DateTime? created, int? number}) {
  return Order()
    ..status = status
    ..dueDate = due
    ..createdAt = created
    ..number = number;
}

void main() {
  final now = DateTime(2026, 10, 12, 15);

  group('HomeRules', () {
    test('stopped: only marked open orders, the oldest first', () {
      OrderHold since(DateTime date) => OrderHold()
        ..reason = OrderHoldReason.part
        ..since = date;
      final recent = order('progress')..onHold = since(DateTime(2026, 10, 11));
      final old = order('approved')..onHold = since(DateTime(2026, 10, 2));
      final leftover = order('done')..onHold = since(DateTime(2026, 10, 1));

      expect(HomeRules.stopped([recent, order('progress'), old, leftover]), [
        old,
        recent,
      ]);
    });

    test('Paradas loads the open orders', () {
      expect(HomeView.onHold.queryField, 'open');
      expect(HomeView.onHold.isOpenList, isTrue);
    });

    test('overdue only for unfinished orders past due date', () {
      expect(
        HomeRules.isOverdue(
          order('progress', due: DateTime(2026, 10, 10)),
          now,
        ),
        isTrue,
      );
      expect(
        HomeRules.isOverdue(order('done', due: DateTime(2026, 10, 10)), now),
        isFalse,
      );
      expect(
        HomeRules.isOverdue(
          order('progress', due: DateTime(2026, 10, 12)),
          now,
        ),
        isFalse,
      );
      expect(HomeRules.isOverdue(order('progress'), now), isFalse);
      expect(
        HomeRules.overdueDays(
          order('progress', due: DateTime(2026, 10, 10, 23)),
          now,
        ),
        2,
      );
      expect(
        HomeRules.overdueSpan(
          order('progress', due: DateTime(2026, 9, 13)),
          now,
        ),
        (OverdueUnit.days, 29),
      );
      expect(
        HomeRules.overdueSpan(
          order('progress', due: DateTime(2026, 3, 1)),
          now,
        ),
        (OverdueUnit.months, 7),
      );
      expect(
        HomeRules.overdueSpan(
          order('progress', due: DateTime(2020, 10, 1)),
          now,
        ),
        (OverdueUnit.years, 6),
      );
    });

    test('groupOpen puts orders in their sections and omits empty ones', () {
      final groups = HomeRules.groupOpen([
        order('quote'),
        order('approved'),
        order('progress'),
        order('progress', due: DateTime(2026, 10, 12)),
        order('approved', due: DateTime(2026, 10, 1)),
      ], now);
      expect(groups.keys.toList(), [
        HomeGroup.late,
        HomeGroup.dueToday,
        HomeGroup.inProgress,
        HomeGroup.waitingApproval,
        HomeGroup.approved,
      ]);
      expect(HomeRules.groupOpen([order('quote')], now).keys, [
        HomeGroup.waitingApproval,
      ]);
      expect(HomeRules.groupOpen([], now), isEmpty);
    });

    test('late section is ordered by due date', () {
      final a = order('progress', due: DateTime(2026, 10, 9), number: 1);
      final b = order('progress', due: DateTime(2026, 10, 3), number: 2);
      final groups = HomeRules.groupOpen([a, b], now);
      expect(groups[HomeGroup.late]!.map((o) => o.number), [2, 1]);
    });

    test('groupByMonth makes one continuous list with a section per month', () {
      final groups = HomeRules.groupByMonth([
        order('done', created: DateTime(2026, 10, 5), number: 1),
        order('done', created: DateTime(2026, 10, 1), number: 2),
        order('done', created: DateTime(2026, 9, 28), number: 3),
      ]);
      expect(groups.length, 2);
      expect(groups[0].key, DateTime(2026, 10));
      expect(groups[0].value.length, 2);
      expect(groups[1].key, DateTime(2026, 9));
    });

    test('sortOpen puts overdue first, then due today, then the rest', () {
      final fresh = order('quote', number: 1);
      final today = order('progress', due: DateTime(2026, 10, 12), number: 2);
      final lateNew = order('approved', due: DateTime(2026, 10, 10), number: 3);
      final lateOld = order('progress', due: DateTime(2026, 10, 1), number: 4);

      final sorted = HomeRules.sortOpen([fresh, today, lateNew, lateOld], now);
      expect(sorted.map((o) => o.number), [4, 3, 2, 1]);
      expect(HomeRules.lateCount(sorted, now), 2);
    });

    test('views map to store fields', () {
      expect(HomeView.open.queryField, 'open');
      expect(HomeView.done.queryField, 'done');
      expect(HomeView.all.queryField, isNull);
      expect(HomeView.mine.queryField, 'open');
      expect(HomeView.open.isOpenList, isTrue);
      expect(HomeView.done.isOpenList, isFalse);
      expect(HomeView.late.queryField, 'open');
      expect(HomeView.late.isOpenList, isTrue);
      expect(HomeView.unpaid.queryField, 'unpaid_done');
      expect(HomeView.unpaid.isOpenList, isFalse);
    });

    test('overdue keeps the late ones, the most overdue first', () {
      final fresh = order('quote', number: 1);
      final lateNew = order('approved', due: DateTime(2026, 10, 10), number: 2);
      final lateOld = order('progress', due: DateTime(2026, 10, 1), number: 3);
      expect(
        HomeRules.overdue([fresh, lateNew, lateOld], now).map((o) => o.number),
        [3, 2],
      );
    });

    test('unpaidDone keeps completed orders not received', () {
      final owed = order('done', number: 1)..payment = 'unpaid';
      final paid = order('done', number: 2)..payment = 'paid';
      final quote = order('quote', number: 3)..payment = 'unpaid';
      expect(
        HomeRules.unpaidDone([owed, paid, quote]).map((o) => o.number),
        [1],
      );
    });
  });

  group('technician rules', () {
    final now = DateTime(2026, 10, 12, 9);
    Order visit(String status, int hour, {String user = 'u1'}) => Order()
      ..status = status
      ..scheduledDate = DateTime(2026, 10, 12, hour)
      ..assignedTo = (UserAggr()..id = user);

    test('assignedTo keeps only the user orders', () {
      final mine = visit('approved', 8);
      final other = visit('approved', 9, user: 'u2');
      expect(HomeRules.assignedTo([mine, other], 'u1'), [mine]);
      expect(HomeRules.assignedTo([mine], null), isEmpty);
    });

    test('scheduledToday sorts by time and skips finished or other days', () {
      final late = visit('approved', 14);
      final early = visit('progress', 8);
      final done = visit('done', 7);
      final tomorrow = Order()
        ..status = 'approved'
        ..scheduledDate = DateTime(2026, 10, 13, 8);
      expect(HomeRules.scheduledToday([late, done, tomorrow, early], now), [
        early,
        late,
      ]);
    });

    test('nextVisit is the first visit not started yet', () {
      final running = visit('progress', 8);
      final next = visit('approved', 10);
      expect(HomeRules.nextVisit([next, running], now), next);
      expect(HomeRules.nextVisit([running], now), running);
      expect(HomeRules.nextVisit([], now), isNull);
    });
  });
}
