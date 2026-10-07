import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/services/deep_link_service.dart';
import 'package:praticos/services/subscription_service.dart';

void main() {
  tearDown(() => SubscriptionService.debugPaidPlansEnabledOverride = null);

  test('no subscription links while paid plans are disabled', () {
    SubscriptionService.debugPaidPlansEnabledOverride = false;

    for (final path in ['upgrade', 'plans', 'restore', 'subscription']) {
      expect(DeepLinkService.subscriptionLinkForPath(path), isNull, reason: path);
    }
  });

  test('maps paths to subscription actions', () {
    SubscriptionService.debugPaidPlansEnabledOverride = true;

    expect(DeepLinkService.subscriptionLinkForPath('upgrade'), SubscriptionDeepLink.paywall);
    expect(DeepLinkService.subscriptionLinkForPath('plans'), SubscriptionDeepLink.paywall);
    expect(DeepLinkService.subscriptionLinkForPath('subscription'), SubscriptionDeepLink.customerCenter);
    expect(DeepLinkService.subscriptionLinkForPath('restore'), SubscriptionDeepLink.restore);
    expect(DeepLinkService.subscriptionLinkForPath('orders'), isNull);
  });
}
