import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/subscription.dart';
import 'package:praticos/screens/widgets/free_limits_banner.dart';
import 'package:praticos/services/feature_gate_service.dart';
import 'package:praticos/services/paid_plans_config.dart';
import 'package:praticos/services/paywall_launcher.dart';
import 'package:praticos/services/subscription_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _start = DateTime.utc(2026, 12, 15, 15);

Future<void> _pump(WidgetTester tester, FreeLimitsNotice notice, {VoidCallback? onViewPlans}) async {
  await tester.pumpWidget(
    CupertinoApp(
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CupertinoPageScaffold(
        child: Center(
          child: FreeLimitsBanner(notice: notice, companyId: 'c1', onViewPlans: onViewPlans),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SubscriptionService.debugPaidPlansEnabledOverride = true;
    PaywallLauncher.roleResolver = () => 'owner';
    FeatureGateService.paidPlansConfig = PaidPlansConfig(limitsStartAt: _start);
  });

  tearDown(() {
    SubscriptionService.debugPaidPlansEnabledOverride = null;
    FeatureGateService.paidPlansConfig = PaidPlansConfig.off;
  });

  group('noticeFor', () {
    final now = _start.subtract(const Duration(days: 10));

    test('Free company in the 15 days before limitsStartAt', () {
      expect(FreeLimitsBanner.noticeFor(null, now)?.daysLeft, 10);
    });

    test('nothing without the date in config/paidPlans', () {
      FeatureGateService.paidPlansConfig = PaidPlansConfig.off;
      expect(FreeLimitsBanner.noticeFor(null, now), isNull);
    });

    test('nothing for a paid plan in force', () {
      final pro = Subscription(plan: SubscriptionPlan.pro, expiresAt: _start.add(const Duration(days: 30)));
      expect(FreeLimitsBanner.noticeFor(pro, now), isNull);
    });

    test('nothing for who cannot buy, nor in a build that does not sell', () {
      PaywallLauncher.roleResolver = () => 'technician';
      expect(FreeLimitsBanner.noticeFor(null, now), isNull);
      PaywallLauncher.roleResolver = () => 'owner';
      SubscriptionService.debugPaidPlansEnabledOverride = false;
      expect(FreeLimitsBanner.noticeFor(null, now), isNull);
    });
  });

  testWidgets('says the day and the work orders of Free, and opens the plans', (tester) async {
    var opened = 0;
    await _pump(tester, FreeLimitsNotice(_start, 10), onViewPlans: () => opened++);
    expect(find.textContaining('A partir de 15/12/2026, o plano Free tem 10 OS por mês.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('free_limits_view_plans')));
    expect(opened, 1);
  });

  testWidgets('"Agora não" hides it for this date', (tester) async {
    await _pump(tester, FreeLimitsNotice(_start, 10));
    await tester.tap(find.text('Agora não'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('free_limits_banner')), findsNothing);

    await _pump(tester, FreeLimitsNotice(_start, 9));
    expect(find.byKey(const ValueKey('free_limits_banner')), findsNothing);
  });
}
