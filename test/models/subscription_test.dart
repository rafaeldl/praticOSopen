import 'dart:io' show File;

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/subscription.dart';

/// Builds `{a: {b: {c: value}}}` from `a.b.c`, like Firestore does for
/// dotted field paths in `update()`.
Map<String, dynamic> _nested(String dottedPath, Object value) {
  final parts = dottedPath.split('.');
  final root = <String, dynamic>{};
  var current = root;
  for (final part in parts.take(parts.length - 1)) {
    final next = <String, dynamic>{};
    current[part] = next;
    current = next;
  }
  current[parts.last] = value;
  return root;
}

void main() {
  final now = DateTime.utc(2026, 10, 7, 12);

  group('Subscription.fromJson with the server schema', () {
    test('parses a document written by the webhook', () {
      final sub = Subscription.fromJson({
        'plan': 'pro',
        'status': 'past_due',
        'source': 'store',
        'store': 'app_store',
        'expiresAt': '2026-11-07T12:00:00.000Z',
        'limits': {
          'photosPerMonth': 500,
          'formTemplates': 10,
          'users': 5,
          'pdfWatermark': false,
        },
        'usage': {
          'photosThisMonth': 12,
          'formTemplatesActive': 2,
          'usersActive': 3,
          'usageResetAt': '2026-10-01T00:00:00.000Z',
        },
        'rcSubscriberId': 'company-1',
        'updatedAt': '2026-10-07T12:00:00.000Z',
      });

      expect(sub.plan, SubscriptionPlan.pro);
      expect(sub.status, SubscriptionStatus.pastDue);
      expect(sub.source, SubscriptionSource.store);
      expect(sub.store, BillingStore.appStore);
      expect(sub.expiresAt!.isAtSameMomentAs(DateTime.utc(2026, 11, 7, 12)), isTrue);
      expect(sub.limits!.users, 5);
      expect(sub.limits!.photosPerMonth, 500);
      expect(sub.usage.photosThisMonth, 12);
      expect(sub.usage.formTemplatesActive, 2);
      expect(sub.usage.usersActive, 3);
      expect(sub.usage.usageResetAt!.isAtSameMomentAs(DateTime.utc(2026, 10, 1)), isTrue);
      expect(sub.rcSubscriberId, 'company-1');
      expect(sub.updatedAt!.isAtSameMomentAs(now), isTrue);
    });

    test('maps every server status', () {
      const expected = {
        'active': SubscriptionStatus.active,
        'cancelled': SubscriptionStatus.cancelled,
        'past_due': SubscriptionStatus.pastDue,
        'expired': SubscriptionStatus.expired,
      };
      expected.forEach((raw, status) {
        expect(Subscription.fromJson({'status': raw}).status, status);
      });
    });

    test('unknown status falls back to active', () {
      expect(Subscription.fromJson({'status': 'trialing'}).status, SubscriptionStatus.active);
      expect(Subscription.fromJson({'status': 'canceled'}).status, SubscriptionStatus.active);
    });

    test('unknown plan, source and store do not throw', () {
      final sub = Subscription.fromJson({'plan': 'enterprise', 'source': 'promo', 'store': 'stripe'});
      expect(sub.plan, SubscriptionPlan.free);
      expect(sub.source, isNull);
      expect(sub.store, isNull);
    });

    test('grace period document', () {
      final sub = Subscription.fromJson({
        'plan': 'pro',
        'status': 'active',
        'source': 'grace',
        'store': null,
        'expiresAt': '2026-12-06T00:00:00.000Z',
      });
      expect(sub.source, SubscriptionSource.grace);
      expect(sub.store, isNull);
      expect(sub.effectivePlan(now), SubscriptionPlan.pro);
    });

    test('reads Firestore Timestamp dates', () {
      final sub = Subscription.fromJson({
        'expiresAt': Timestamp.fromDate(DateTime.utc(2026, 11, 7)),
      });
      expect(sub.expiresAt!.isAtSameMomentAs(DateTime.utc(2026, 11, 7)), isTrue);
    });

    test('empty document is an active Free subscription with zero usage', () {
      final sub = Subscription.fromJson(<String, dynamic>{});
      expect(sub.plan, SubscriptionPlan.free);
      expect(sub.status, SubscriptionStatus.active);
      expect(sub.limits, isNull);
      expect(sub.usage.photosThisMonth, 0);
      expect(sub.usage.formTemplatesActive, 0);
      expect(sub.usage.usersActive, 0);
    });
  });

  group('legacy client format', () {
    test('reads formTemplates and collaborators usage keys', () {
      final sub = Subscription.fromJson({
        'usage': {'photosThisMonth': 4, 'formTemplates': 2, 'collaborators': 3},
      });
      expect(sub.usage.formTemplatesActive, 2);
      expect(sub.usage.usersActive, 3);
    });

    test('server keys win over legacy keys', () {
      final usage = SubscriptionUsage.fromJson({
        'formTemplates': 9,
        'formTemplatesActive': 1,
        'collaborators': 9,
        'usersActive': 1,
      });
      expect(usage.formTemplatesActive, 1);
      expect(usage.usersActive, 1);
    });

    test('reads collaborators limit as users', () {
      final limits = SubscriptionLimits.fromJson({
        'photosPerMonth': 200,
        'formTemplates': 3,
        'collaborators': 3,
        'pdfWatermark': false,
      });
      expect(limits.users, 3);
    });
  });

  group('toJson', () {
    test('writes the server keys and values', () {
      final json = Subscription(
        plan: SubscriptionPlan.business,
        status: SubscriptionStatus.pastDue,
        store: BillingStore.playStore,
        expiresAt: DateTime.utc(2026, 11, 7),
        usage: SubscriptionUsage(formTemplatesActive: 1, usersActive: 2),
      ).toJson();

      expect(json['plan'], 'business');
      expect(json['status'], 'past_due');
      expect(json['store'], 'play_store');
      expect(json['expiresAt'], '2026-11-07T00:00:00.000Z');
      final usage = json['usage'] as Map<String, dynamic>;
      expect(usage['formTemplatesActive'], 1);
      expect(usage['usersActive'], 2);
      expect(usage.containsKey('formTemplates'), isFalse);
      expect(usage.containsKey('collaborators'), isFalse);
    });
  });

  group('effectivePlan', () {
    test('returns the plan when expiresAt is null', () {
      expect(Subscription(plan: SubscriptionPlan.starter).effectivePlan(now), SubscriptionPlan.starter);
    });

    test('returns the plan while expiresAt is in the future', () {
      final sub = Subscription(
        plan: SubscriptionPlan.pro,
        status: SubscriptionStatus.cancelled,
        expiresAt: now.add(const Duration(days: 3)),
      );
      expect(sub.effectivePlan(now), SubscriptionPlan.pro);
    });

    test('returns free once expiresAt has passed', () {
      final sub = Subscription(
        plan: SubscriptionPlan.business,
        expiresAt: now.subtract(const Duration(seconds: 1)),
      );
      expect(sub.effectivePlan(now), SubscriptionPlan.free);
    });
  });

  group('effectiveLimits', () {
    test('uses limits stored by the server', () {
      const stored = SubscriptionLimits(photosPerMonth: 50, formTemplates: 2, users: 2, pdfWatermark: false);
      final sub = Subscription(plan: SubscriptionPlan.starter, limits: stored);
      expect(sub.effectiveLimits(now).photosPerMonth, 50);
    });

    test('falls back to the plan defaults', () {
      final sub = Subscription(plan: SubscriptionPlan.pro);
      expect(sub.effectiveLimits(now).photosPerMonth, 500);
      expect(sub.effectiveLimits(now).users, 5);
    });

    test('expired plan gets Free limits even with stored limits', () {
      final sub = Subscription(
        plan: SubscriptionPlan.business,
        limits: SubscriptionLimits.forPlan(SubscriptionPlan.business),
        expiresAt: now.subtract(const Duration(days: 1)),
      );
      final limits = sub.effectiveLimits(now);
      expect(limits.photosPerMonth, 30);
      expect(limits.pdfWatermark, isTrue);
    });
  });

  group('SubscriptionUsagePaths', () {
    test('counters live in the company document', () {
      expect(SubscriptionUsagePaths.collection, 'companies');
    });

    test('every counter written by the app is read back by the model', () {
      final paths = {
        SubscriptionUsagePaths.photosThisMonth: (Subscription s) => s.usage.photosThisMonth,
        SubscriptionUsagePaths.formTemplatesActive: (Subscription s) => s.usage.formTemplatesActive,
        SubscriptionUsagePaths.usersActive: (Subscription s) => s.usage.usersActive,
      };
      paths.forEach((path, read) {
        final doc = _nested(path, 7);
        final sub = Subscription.fromJson(doc['subscription'] as Map<String, dynamic>);
        expect(read(sub), 7, reason: path);
      });
    });

    test('no app code writes usage counters to the tenants collection', () {
      final source = File('lib/services/photo_service.dart').readAsStringSync();
      expect(source.contains("collection('tenants')"), isFalse);
      expect(source.contains('SubscriptionUsagePaths.photosThisMonth'), isTrue);
    });
  });

  test('plan display names', () {
    expect(SubscriptionPlan.free.displayName, 'Free');
    expect(SubscriptionPlan.business.displayName, 'Business');
  });

  group('periodState', () {
    final now = DateTime.utc(2026, 10, 9, 12);
    final later = DateTime.utc(2026, 10, 10, 12);
    final earlier = DateTime.utc(2026, 10, 8, 12);

    Subscription sub({
      SubscriptionPlan plan = SubscriptionPlan.pro,
      SubscriptionStatus status = SubscriptionStatus.active,
      SubscriptionSource? source = SubscriptionSource.store,
      DateTime? expiresAt,
    }) => Subscription(plan: plan, status: status, source: source, expiresAt: expiresAt ?? later);

    test('free plan shows no date', () {
      expect(sub(plan: SubscriptionPlan.free).periodState(now), SubscriptionPeriodState.free);
    });

    test('expired paid plan reads as free', () {
      expect(sub(expiresAt: earlier).periodState(now), SubscriptionPeriodState.free);
    });

    test('launch grace is a courtesy', () {
      expect(sub(source: SubscriptionSource.grace).periodState(now), SubscriptionPeriodState.courtesy);
    });

    test('active store subscription renews', () {
      expect(sub().periodState(now), SubscriptionPeriodState.renewsOn);
    });

    test('cancelled store subscription ends', () {
      expect(sub(status: SubscriptionStatus.cancelled).periodState(now), SubscriptionPeriodState.endsOn);
    });

    test('billing issue', () {
      expect(sub(status: SubscriptionStatus.pastDue).periodState(now), SubscriptionPeriodState.paymentIssue);
    });

    test('active plan without source ends on its date', () {
      expect(sub(source: null).periodState(now), SubscriptionPeriodState.endsOn);
    });
  });

  group('hasStoreSubscription', () {
    final now = DateTime.utc(2026, 10, 9, 12);

    test('true for a store plan in force', () {
      final s = Subscription(
        plan: SubscriptionPlan.pro,
        source: SubscriptionSource.store,
        expiresAt: DateTime.utc(2026, 10, 10),
      );
      expect(s.hasStoreSubscription(now), isTrue);
    });

    test('false for launch grace', () {
      final s = Subscription(
        plan: SubscriptionPlan.pro,
        source: SubscriptionSource.grace,
        expiresAt: DateTime.utc(2026, 12, 7),
      );
      expect(s.hasStoreSubscription(now), isFalse);
    });

    test('false once the store plan expired', () {
      final s = Subscription(
        plan: SubscriptionPlan.pro,
        source: SubscriptionSource.store,
        expiresAt: DateTime.utc(2026, 10, 8),
      );
      expect(s.hasStoreSubscription(now), isFalse);
    });
  });
}
