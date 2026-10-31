import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/subscription.dart';
import 'package:praticos/screens/widgets/courtesy_banner.dart';
import 'package:praticos/services/ai_order_assist_service.dart';
import 'package:praticos/services/analytics_service.dart';
import 'package:praticos/services/paywall_launcher.dart';
import 'package:praticos/services/subscription_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Subscription _grace({int days = 10, int users = 1}) => Subscription(
  plan: SubscriptionPlan.pro,
  source: SubscriptionSource.grace,
  expiresAt: DateTime.now().add(Duration(days: days, minutes: -1)),
  usage: SubscriptionUsage(usersActive: users),
);

Future<void> _pump(
  WidgetTester tester,
  Subscription subscription, {
  int aiUsed = 0,
  VoidCallback? onViewPlans,
}) async {
  await tester.pumpWidget(
    CupertinoApp(
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CupertinoPageScaffold(
        child: Center(
          child: CourtesyBanner(
            subscription: subscription,
            loadAiStatus: () async =>
                AiStatus(enabled: true, used: aiUsed, limit: 400),
            onViewPlans: onViewPlans,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final events = <String, Map<String, Object>>{};

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SubscriptionService.debugPaidPlansEnabledOverride = true;
    PaywallLauncher.roleResolver = () => 'owner';
    events.clear();
    AnalyticsService.debugAiEventSink = (name, parameters) =>
        events[name] = parameters;
  });

  tearDown(() {
    SubscriptionService.debugPaidPlansEnabledOverride = null;
    AnalyticsService.debugAiEventSink = null;
  });

  testWidgets('shows the real use against Free and the plan that covers it', (
    tester,
  ) async {
    await _pump(tester, _grace(), aiUsed: 87);
    expect(
      find.text(
        'Acaba em 10 dias. Neste mês você usou o assistente 87 vezes; '
        'no Free são 10. O plano Starter cobre o seu uso.',
      ),
      findsOneWidget,
    );
    expect(events['upgrade_modal_shown']?['trigger'], 'courtesy_first');
  });

  testWidgets('without assistant use it just says what happens', (tester) async {
    await _pump(tester, _grace(days: 3));
    expect(
      find.text('Acaba em 3 dias. Depois disso, o app volta para o plano Free.'),
      findsOneWidget,
    );
    expect(events['upgrade_modal_shown']?['trigger'], 'courtesy_last');
  });

  testWidgets('"Ver planos" opens the paywall', (tester) async {
    var opened = 0;
    await _pump(tester, _grace(), onViewPlans: () => opened++);
    await tester.tap(find.byKey(const ValueKey('courtesy_view_plans')));
    expect(opened, 1);
  });

  testWidgets('"Agora não" hides it until the last days', (tester) async {
    final first = _grace();
    await _pump(tester, first);
    await tester.tap(find.text('Agora não'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('courtesy_banner')), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await _pump(tester, first);
    expect(find.byKey(const ValueKey('courtesy_banner')), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await _pump(tester, _grace(days: 3));
    expect(find.byKey(const ValueKey('courtesy_banner')), findsOneWidget);
  });

  test('applies only to whoever can buy, inside the window', () {
    final now = DateTime.now();
    expect(CourtesyBanner.applies(_grace(), now), isTrue);
    expect(CourtesyBanner.applies(_grace(days: 30), now), isFalse);
    PaywallLauncher.roleResolver = () => 'technician';
    expect(CourtesyBanner.applies(_grace(), now), isFalse);
    PaywallLauncher.roleResolver = () => 'owner';
    SubscriptionService.debugPaidPlansEnabledOverride = false;
    expect(CourtesyBanner.applies(_grace(), now), isFalse);
  });
}
