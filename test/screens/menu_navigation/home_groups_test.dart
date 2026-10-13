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
    test('overdue only for unfinished orders past due date', () {
      expect(HomeRules.isOverdue(order('progress', due: DateTime(2026, 10, 10)), now), isTrue);
      expect(HomeRules.isOverdue(order('done', due: DateTime(2026, 10, 10)), now), isFalse);
      expect(HomeRules.isOverdue(order('progress', due: DateTime(2026, 10, 12)), now), isFalse);
      expect(HomeRules.isOverdue(order('progress'), now), isFalse);
      expect(HomeRules.overdueDays(order('progress', due: DateTime(2026, 10, 10, 23)), now), 2);
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
      expect(HomeRules.groupOpen([order('quote')], now).keys,
          [HomeGroup.waitingApproval]);
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

    test('nextStep priority: late, then due today, then stale quotes', () {
      final late = order('progress', due: DateTime(2026, 10, 1));
      final today = order('progress', due: DateTime(2026, 10, 12));
      final stale = order('quote', created: DateTime(2026, 9, 1));

      expect(HomeRules.nextStep([late, today, stale], now)!.kind, NextStepKind.late);
      expect(HomeRules.nextStep([today, stale], now)!.kind, NextStepKind.dueToday);
      final quotes = HomeRules.nextStep([stale], now)!;
      expect(quotes.kind, NextStepKind.quotesWaiting);
      expect(quotes.target, HomeGroup.waitingApproval);
      expect(HomeRules.nextStep([order('quote', created: DateTime(2026, 10, 10))], now), isNull);
      expect(HomeRules.nextStep([], now), isNull);
    });

    test('views map to store fields', () {
      expect(HomeView.open.queryField, 'open');
      expect(HomeView.all.queryField, isNull);
      expect(HomeView.canceled.queryField, 'canceled');
      expect(HomeView.open.isSegmented, isTrue);
      expect(HomeView.canceled.isSegmented, isFalse);
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
      expect(
        HomeRules.scheduledToday([late, done, tomorrow, early], now),
        [early, late],
      );
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
