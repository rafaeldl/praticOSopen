import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/subscription.dart';
import 'package:praticos/services/feature_gate_service.dart';

void main() {
  group('FeatureGateService', () {
    test('canAddPhoto allows photo when within limit (Free)', () {
      final subscription = Subscription(
        plan: SubscriptionPlan.free,
        usage: SubscriptionUsage(photosThisMonth: 10),
      );

      final result = FeatureGateService.canAddPhoto(subscription);

      expect(result.isAllowed, isTrue);
      expect(result.currentUsage, 10);
      expect(result.limit, 30);
      expect(result.isAtLimit, isFalse);
      expect(result.isNearLimit, isFalse);
    });

    test('canAddPhoto denies photo when at limit (Free)', () {
      final subscription = Subscription(
        plan: SubscriptionPlan.free,
        usage: SubscriptionUsage(photosThisMonth: 30),
      );

      final result = FeatureGateService.canAddPhoto(subscription);

      expect(result.isAllowed, isFalse);
      expect(result.isAtLimit, isTrue);
      expect(result.message, contains('Limite de fotos atingido (30/30)'));
    });

    test('canAddPhoto identifies near limit (Free, 80%)', () {
      final subscription = Subscription(
        plan: SubscriptionPlan.free,
        usage: SubscriptionUsage(photosThisMonth: 24), // 24/30 = 80%
      );

      final result = FeatureGateService.canAddPhoto(subscription);

      expect(result.isNearLimit, isTrue);
      expect(result.isAtLimit, isFalse);
    });

    test('canAddPhoto suggests upgrade when near limit', () {
      final subscription = Subscription(
        plan: SubscriptionPlan.free,
        usage: SubscriptionUsage(photosThisMonth: 25),
      );

      final result = FeatureGateService.canAddPhoto(subscription);

      expect(result.suggestedUpgrade, equals(SubscriptionPlan.starter));
    });

    test('canAddPhoto is unlimited for Business plan', () {
      final subscription = Subscription(
        plan: SubscriptionPlan.business,
        usage: SubscriptionUsage(photosThisMonth: 1000),
      );

      final result = FeatureGateService.canAddPhoto(subscription);

      expect(result.isAllowed, isTrue);
      expect(result.isUnlimited, isTrue);
      expect(result.limit, -1);
    });

    test('canAddPhotos checks for multiple photos', () {
      final subscription = Subscription(
        plan: SubscriptionPlan.free,
        usage: SubscriptionUsage(photosThisMonth: 28),
      );

      // Pode adicionar 2, mas nao 3
      expect(FeatureGateService.canAddPhotos(subscription, 2).isAllowed, isTrue);
      expect(FeatureGateService.canAddPhotos(subscription, 3).isAllowed, isFalse);
    });

    test('canAddCollaborator checks collaborator limit (Free)', () {
      final subscription = Subscription(
        plan: SubscriptionPlan.free,
        usage: SubscriptionUsage(collaborators: 1),
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
}
