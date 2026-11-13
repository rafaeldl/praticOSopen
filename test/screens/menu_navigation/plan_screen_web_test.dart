// Plan bought on the web (docs/WEB_CHECKOUT.md, issue #664): the app shows
// only the active plan. No "Ver planos", restore, "manage" or any word about
// the website (App Store 3.1.1 / 3.1.3).
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/mobx/subscription_store.dart';
import 'package:praticos/models/subscription.dart';
import 'package:praticos/screens/menu_navigation/more/plan_screen.dart';
import 'package:praticos/services/paywall_launcher.dart';
import 'package:praticos/services/subscription_service.dart';
import 'package:provider/provider.dart';

Subscription _pro(BillingStore store,
        {SubscriptionStatus status = SubscriptionStatus.active}) =>
    Subscription(
      plan: SubscriptionPlan.pro,
      status: status,
      source: SubscriptionSource.store,
      store: store,
      expiresAt: DateTime.now().add(const Duration(days: 30)),
    );

Future<void> _pump(WidgetTester tester, Subscription subscription) async {
  final store = SubscriptionStore()..latest = subscription;
  await tester.pumpWidget(
    Provider<SubscriptionStore>.value(
      value: store,
      child: CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PlanScreen(
          loadTaxIds: () async => 0,
          hasPermission: (_) => true,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final l10n = AppLocalizationsPt();
  final originalRole = PaywallLauncher.roleResolver;
  final originalSubscription = PaywallLauncher.subscriptionResolver;

  setUp(() {
    SubscriptionService.debugPaidPlansEnabledOverride = true;
    PaywallLauncher.roleResolver = () => 'owner';
  });
  tearDown(() {
    SubscriptionService.debugPaidPlansEnabledOverride = null;
    PaywallLauncher.roleResolver = originalRole;
    PaywallLauncher.subscriptionResolver = originalSubscription;
  });

  test('store "web" is read from Firestore and counts as a paid plan', () {
    final sub = Subscription.fromJson({
      'plan': 'pro',
      'status': 'active',
      'source': 'store',
      'store': 'web',
      'expiresAt': DateTime.now().add(const Duration(days: 3)).toIso8601String(),
      'usage': <String, dynamic>{},
    });
    final now = DateTime.now();
    expect(sub.store, BillingStore.web);
    expect(sub.toJson()['store'], 'web');
    expect(sub.hasStoreSubscription(now), isTrue);
    expect(sub.hasWebSubscription(now), isTrue);
    expect(sub.periodState(now), SubscriptionPeriodState.renewsOn);
    expect(_pro(BillingStore.appStore).hasWebSubscription(now), isFalse);
    final ended = Subscription(
      plan: SubscriptionPlan.pro,
      source: SubscriptionSource.store,
      store: BillingStore.web,
      expiresAt: now.subtract(const Duration(days: 1)),
    );
    expect(ended.hasWebSubscription(now), isFalse);
  });

  testWidgets('web subscriber: plan only, no purchase links, no site', (tester) async {
    await _pump(tester, _pro(BillingStore.web));

    expect(find.byKey(const ValueKey('plan_current')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan_paywall')), findsNothing);
    expect(find.byKey(const ValueKey('plan_manage')), findsNothing);
    expect(find.byKey(const ValueKey('plan_restore')), findsNothing);
    expect(find.text(l10n.askAdminToChangePlan), findsNothing);
    expect(find.textContaining('site'), findsNothing);
    expect(find.textContaining('web'), findsNothing);
    expect(find.textContaining('praticos.app'), findsNothing);
  });

  testWidgets('store subscriber keeps the purchase links', (tester) async {
    await _pump(tester, _pro(BillingStore.appStore));
    expect(find.byKey(const ValueKey('plan_manage')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan_restore')), findsOneWidget);
  });

  testWidgets('any paywall entry shows only "plan active" for a web subscriber', (tester) async {
    PaywallLauncher.subscriptionResolver = () => _pro(BillingStore.web);
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CupertinoPageScaffold(
          child: Center(
            child: Builder(
              builder: (context) => CupertinoButton(
                onPressed: () => PaywallLauncher.showPaywall(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.planActiveMessage('Pro')), findsOneWidget);
    expect(find.textContaining('site'), findsNothing);
    expect(find.text(l10n.subscriptionUnavailable), findsNothing);
  });
}
