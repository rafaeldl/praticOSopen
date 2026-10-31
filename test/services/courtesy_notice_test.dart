import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/subscription.dart';
import 'package:praticos/services/courtesy_notice.dart';

void main() {
  final end = DateTime.utc(2026, 12, 7, 12);
  DateTime daysBefore(int days) => end.subtract(Duration(days: days));
  Subscription grace({SubscriptionSource? source = SubscriptionSource.grace}) =>
      Subscription(plan: SubscriptionPlan.pro, source: source, expiresAt: end);

  group('CourtesyNotice.of', () {
    test('stays quiet before the window', () {
      expect(CourtesyNotice.of(grace(), daysBefore(16)), isNull);
    });

    test('shows the days left inside the window', () {
      expect(CourtesyNotice.of(grace(), daysBefore(15))?.daysLeft, 15);
      expect(CourtesyNotice.of(grace(), daysBefore(1))?.daysLeft, 1);
    });

    test('counts a partial day as a day', () {
      final now = end.subtract(const Duration(hours: 30));
      expect(CourtesyNotice.of(grace(), now)?.daysLeft, 2);
    });

    test('stays quiet after the end and for a store subscription', () {
      expect(CourtesyNotice.of(grace(), end), isNull);
      expect(
        CourtesyNotice.of(
          grace(source: SubscriptionSource.store),
          daysBefore(3),
        ),
        isNull,
      );
      expect(CourtesyNotice.of(null, daysBefore(3)), isNull);
    });

    test('"Agora não" hides it until the last days or a new date', () {
      final first = CourtesyNotice.of(grace(), daysBefore(10))!;
      final last = CourtesyNotice.of(grace(), daysBefore(3))!;
      final moved = CourtesyNotice(10, end.add(const Duration(days: 21)));
      expect(last.isLast, isTrue);
      expect(first.isLast, isFalse);
      expect(first.dismissKey, isNot(last.dismissKey));
      expect(first.dismissKey, isNot(moved.dismissKey));
    });
  });

  group('recommendedPlan', () {
    SubscriptionUsage usage({int users = 1, int photos = 0, int forms = 0}) =>
        SubscriptionUsage(
          usersActive: users,
          photosThisMonth: photos,
          formTemplatesActive: forms,
        );

    test('is null while Free covers the use', () {
      expect(recommendedPlan(usage(), 10), isNull);
    });

    test('picks the smallest plan that covers every resource', () {
      expect(recommendedPlan(usage(), 11), SubscriptionPlan.starter);
      expect(recommendedPlan(usage(users: 2), 0), SubscriptionPlan.starter);
      expect(recommendedPlan(usage(), 151), SubscriptionPlan.pro);
      expect(recommendedPlan(usage(users: 5), 0), SubscriptionPlan.pro);
      expect(recommendedPlan(usage(photos: 501), 0), SubscriptionPlan.business);
      expect(recommendedPlan(usage(users: 6), 0), SubscriptionPlan.business);
    });
  });
}
