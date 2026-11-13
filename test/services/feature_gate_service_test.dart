import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/subscription.dart';
import 'package:praticos/services/feature_gate_service.dart';
import 'package:praticos/services/subscription_service.dart';

void main() {
  group('FeatureGateService', () {
    setUp(() => FeatureGateService.debugPlanLimitsEnforcedOverride = true);
    tearDown(() => FeatureGateService.debugPlanLimitsEnforcedOverride = null);

    final now = DateTime.utc(2026, 11, 20, 15);
    SubscriptionUsage orders(int thisMonth, {int lastMonth = 0}) =>
        SubscriptionUsage(ordersMonth: '2026-11', ordersThisMonth: thisMonth, ordersLastMonth: lastMonth);

    test('canCreateOrder allows within the month (Free 10)', () {
      final result = FeatureGateService.canCreateOrder(Subscription(usage: orders(5)), now: now);

      expect(result.isAllowed, isTrue);
      expect(result.currentUsage, 5);
      expect(result.limit, 10);
      expect(result.level, 'ok');
      expect(result.grace, isFalse);
    });

    test('canCreateOrder warns at 80% and at 100%', () {
      expect(FeatureGateService.canCreateOrder(Subscription(usage: orders(7)), now: now).level, 'near');
      expect(FeatureGateService.canCreateOrder(Subscription(usage: orders(9)), now: now).level, 'atLimit');
    });

    test('canCreateOrder: the first month over has a month of grace', () {
      final result = FeatureGateService.canCreateOrder(Subscription(usage: orders(10, lastMonth: 3)), now: now);

      expect(result.isAllowed, isTrue);
      expect(result.grace, isTrue);
      expect(result.level, 'over');
    });

    test('canCreateOrder: over again the month after asks for a plan', () {
      final result = FeatureGateService.canCreateOrder(Subscription(usage: orders(10, lastMonth: 11)), now: now);

      expect(result.isAllowed, isFalse);
      expect(result.suggestedUpgrade, SubscriptionPlan.starter);
    });

    test('canCreateOrder: a new month starts from zero', () {
      final result = FeatureGateService.canCreateOrder(
        Subscription(usage: orders(10, lastMonth: 11)),
        now: DateTime.utc(2026, 12, 2),
      );

      expect(result.currentUsage, 0);
      expect(result.isAllowed, isTrue);
    });

    test('canCreateOrder: Business past 500 is not blocked, it says to talk to us', () {
      final result = FeatureGateService.canCreateOrder(
        Subscription(plan: SubscriptionPlan.business, usage: orders(600, lastMonth: 600)),
        now: now,
      );

      expect(result.isAllowed, isTrue);
      expect(result.contactUs, isTrue);
    });

    test('photos have no limit on any plan', () {
      final result = FeatureGateService.canAddPhotos(
        Subscription(usage: SubscriptionUsage(photosThisMonth: 5000)),
        100,
      );

      expect(result.isAllowed, isTrue);
      expect(result.isUnlimited, isTrue);
    });

    test('Free cannot create its own checklist; Starter can', () {
      expect(FeatureGateService.canCreateFormTemplate(Subscription()).isAllowed, isFalse);
      expect(FeatureGateService.canCreateFormTemplate(Subscription()).suggestedUpgrade, SubscriptionPlan.starter);
      expect(
        FeatureGateService.canCreateFormTemplate(
          Subscription(plan: SubscriptionPlan.starter, usage: SubscriptionUsage(formTemplatesActive: 30)),
        ).isAllowed,
        isTrue,
      );
    });

    test('canAddCollaborator checks collaborator limit (Free)', () {
      final subscription = Subscription(
        plan: SubscriptionPlan.free,
        usage: SubscriptionUsage(usersActive: 1),
      );

      final result = FeatureGateService.canAddCollaborator(subscription);

      expect(result.isAllowed, isFalse);
      expect(result.isAtLimit, isTrue);
      expect(result.suggestedUpgrade, equals(SubscriptionPlan.starter));
    });

    test('shouldShowPdfWatermark returns true for Free and false for Starter', () {
      expect(FeatureGateService.shouldShowPdfWatermark(Subscription(plan: SubscriptionPlan.free)), isTrue);
      expect(FeatureGateService.shouldShowPdfWatermark(Subscription(plan: SubscriptionPlan.starter)), isFalse);
    });
  });

  group('FeatureGateService with paid plans disabled (no store key)', () {
    setUp(() => FeatureGateService.debugPlanLimitsEnforcedOverride = false);
    tearDown(() => FeatureGateService.debugPlanLimitsEnforcedOverride = null);

    final exhausted = Subscription(
      plan: SubscriptionPlan.free,
      usage: SubscriptionUsage(
        photosThisMonth: 9999,
        formTemplatesActive: 9999,
        usersActive: 9999,
      ),
    );

    test('photos are unlimited', () {
      final single = FeatureGateService.canAddPhoto(exhausted);
      final many = FeatureGateService.canAddPhotos(exhausted, 500);

      expect(single.isAllowed, isTrue);
      expect(single.isUnlimited, isTrue);
      expect(single.message, isNull);
      expect(many.isAllowed, isTrue);
    });

    test('form templates and collaborators are unlimited', () {
      expect(FeatureGateService.canCreateFormTemplate(exhausted).isAllowed, isTrue);
      expect(FeatureGateService.canAddCollaborator(exhausted).isAllowed, isTrue);
    });

    test('never suggests an upgrade nor flags near limit', () {
      final result = FeatureGateService.canAddPhoto(exhausted);

      expect(result.isNearLimit, isFalse);
      expect(result.isAtLimit, isFalse);
      expect(result.suggestedUpgrade, isNull);
    });

    test('PDF has no watermark even on the Free plan', () {
      expect(FeatureGateService.shouldShowPdfWatermark(null), isFalse);
    });
  });

  group('FeatureGateService uses the effective plan', () {
    setUp(() => FeatureGateService.debugPlanLimitsEnforcedOverride = true);
    tearDown(() => FeatureGateService.debugPlanLimitsEnforcedOverride = null);

    test('expired paid plan falls back to Free limits', () {
      final sub = Subscription(
        plan: SubscriptionPlan.business,
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        usage: SubscriptionUsage(usersActive: 1),
      );

      final result = FeatureGateService.canAddCollaborator(sub);

      expect(result.isAllowed, isFalse);
      expect(result.limit, 1);
      expect(result.currentPlan, SubscriptionPlan.free);
    });

    test('grace period Pro keeps Pro limits until expiresAt', () {
      final sub = Subscription(
        plan: SubscriptionPlan.pro,
        source: SubscriptionSource.grace,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        usage: SubscriptionUsage(usersActive: 4),
      );

      final result = FeatureGateService.canAddCollaborator(sub);

      expect(result.isAllowed, isTrue);
      expect(result.limit, 5);
    });

    test('a stored limit more generous than the table is kept (a subscriber never loses)', () {
      final sub = Subscription(
        plan: SubscriptionPlan.starter,
        limits: const SubscriptionLimits(
          ordersPerMonth: 50,
          photosPerMonth: 200,
          formTemplates: 3,
          users: 3,
          pdfWatermark: false,
        ),
        usage: SubscriptionUsage(usersActive: 2, photosThisMonth: 500),
      );

      expect(FeatureGateService.canAddCollaborator(sub).limit, 3);
      expect(FeatureGateService.canAddCollaborator(sub).isAllowed, isTrue);
      // The table has no photo limit: the stored 200 gives way.
      expect(FeatureGateService.canAddPhoto(sub).limit, -1);
    });

    test('form templates and users read the server usage keys', () {
      final sub = Subscription(
        usage: SubscriptionUsage(formTemplatesActive: 1, usersActive: 1),
      );

      expect(FeatureGateService.canCreateFormTemplate(sub).isAllowed, isFalse);
      expect(FeatureGateService.canAddCollaborator(sub).isAllowed, isFalse);
    });

    test('expired plan shows the PDF watermark again', () {
      final sub = Subscription(
        plan: SubscriptionPlan.pro,
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      expect(FeatureGateService.shouldShowPdfWatermark(sub), isTrue);
    });
  });

  group('FeatureGateService.planLimitsEnforced: the switch and a build that sells', () {
    tearDown(() {
      SubscriptionService.debugPaidPlansEnabledOverride = null;
      FeatureGateService.debugPlanLimitsEnforcedOverride = null;
      FeatureGateService.limitsSwitchOn = false;
    });

    test('limits apply with config/paidPlans on and paid plans enabled', () {
      SubscriptionService.debugPaidPlansEnabledOverride = true;
      FeatureGateService.limitsSwitchOn = true;

      expect(FeatureGateService.planLimitsEnforced, isTrue);
      final result = FeatureGateService.canAddCollaborator(
        Subscription(usage: SubscriptionUsage(usersActive: 1)),
      );
      expect(result.isAllowed, isFalse);
    });

    test('the switch off turns every limit off, even in a build that sells', () {
      SubscriptionService.debugPaidPlansEnabledOverride = true;
      FeatureGateService.limitsSwitchOn = false;

      expect(FeatureGateService.planLimitsEnforced, isFalse);
    });

    test('everything is unlimited when paid plans are disabled', () {
      SubscriptionService.debugPaidPlansEnabledOverride = false;

      expect(FeatureGateService.planLimitsEnforced, isFalse);
      final result = FeatureGateService.canAddPhoto(
        Subscription(usage: SubscriptionUsage(photosThisMonth: 9999)),
      );
      expect(result.isAllowed, isTrue);
      expect(FeatureGateService.shouldShowPdfWatermark(null), isFalse);
    });

    test('a build without RevenueCat key has no limits', () {
      expect(SubscriptionService.paidPlansEnabled, isFalse);
      expect(FeatureGateService.planLimitsEnforced, isFalse);
    });
  });
}
