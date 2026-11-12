import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/mobx/subscription_store.dart';
import 'package:praticos/models/subscription.dart';
import 'package:praticos/screens/menu_navigation/more/plan_screen.dart';
import 'package:praticos/services/feature_gate_service.dart';
import 'package:praticos/services/paywall_launcher.dart';
import 'package:praticos/services/subscription_service.dart';
import 'package:provider/provider.dart';

/// A plan of the current table (2026-11) with this month's orders.
Subscription _sub(
  SubscriptionPlan plan, {
  int orders = 0,
  int lastMonth = 0,
  int users = 1,
}) {
  final now = DateTime.now();
  return Subscription(
    plan: plan,
    source: plan == SubscriptionPlan.free ? null : SubscriptionSource.store,
    expiresAt: plan == SubscriptionPlan.free ? null : now.add(const Duration(days: 30)),
    usage: SubscriptionUsage(usersActive: users)
      ..ordersMonth = orderMonthKey(now)
      ..ordersThisMonth = orders
      ..ordersLastMonth = lastMonth,
  );
}

Future<void> _pump(
  WidgetTester tester,
  Subscription subscription, {
  VoidCallback? onOpenTeam,
  bool canManage = true,
  int cnpjs = 0,
}) async {
  tester.view.physicalSize = const Size(1170, 4000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final store = SubscriptionStore()..latest = subscription;
  await tester.pumpWidget(
    Provider<SubscriptionStore>.value(
      value: store,
      child: CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PlanScreen(
          onOpenTeam: onOpenTeam,
          loadCnpjs: () async => cnpjs,
          hasPermission: (_) => canManage,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SubscriptionService.debugPaidPlansEnabledOverride = true;
    FeatureGateService.debugPlanLimitsEnforcedOverride = true;
    PaywallLauncher.roleResolver = () => 'owner';
  });
  tearDown(() {
    SubscriptionService.debugPaidPlansEnabledOverride = null;
    FeatureGateService.debugPlanLimitsEnforcedOverride = null;
  });

  testWidgets('new company on Free: orders and people, no limit notice, what Starter adds', (tester) async {
    await _pump(tester, _sub(SubscriptionPlan.free, orders: 1));

    expect(find.text('Free'), findsOneWidget);
    expect(find.text('OS este mês'), findsOneWidget);
    expect(find.text('1 de 10'), findsOneWidget);
    expect(find.text('Pessoas na equipe'), findsOneWidget);
    expect(find.text('1 de 1'), findsOneWidget);
    // The owner alone is not a limit (#725): no red "No limite".
    expect(find.text('No limite · conta o convite'), findsNothing);
    expect(find.byKey(const ValueKey('plan_notice_peopleAtLimit')), findsNothing);
    // Free has no nota: no CNPJ row. No assistant counter.
    expect(find.text('CNPJs na nota fiscal'), findsNothing);
    expect(find.textContaining('assistente'), findsNothing);
    expect(find.text('O que o Starter dá a mais'), findsOneWidget);
    for (final name in ['Nota fiscal', 'PDF sem a marca PraticOS', 'Checklists próprios', 'Cobrança e lembrete de pagamento']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(find.byKey(const ValueKey('plan_paywall')), findsOneWidget);
  });

  testWidgets('80% of the orders: notice with "Ver planos"', (tester) async {
    await _pump(tester, _sub(SubscriptionPlan.free, orders: 8));
    expect(find.byKey(const ValueKey('plan_notice_ordersNear')), findsOneWidget);
    expect(find.text('Você já abriu 8 de 10 OS este mês.'), findsOneWidget);
    expect(find.text('Quase no limite'), findsOneWidget);
    expect(find.text('Ver planos'), findsOneWidget);
  });

  testWidgets('over in the first month: the month of grace', (tester) async {
    await _pump(tester, _sub(SubscriptionPlan.free, orders: 12, lastMonth: 3));
    expect(
      find.text('Este mês passou de 10 OS e nada foi travado. Se passar de novo no mês que vem, a OS nova espera você mudar de plano.'),
      findsOneWidget,
    );
  });

  testWidgets('over again: the new order waits', (tester) async {
    await _pump(tester, _sub(SubscriptionPlan.free, orders: 11, lastMonth: 14));
    expect(find.byKey(const ValueKey('plan_notice_ordersBlocked')), findsOneWidget);
    expect(find.text('Passou de 10 OS de novo. As OS abertas continuam normais; a nova espera você mudar de plano.'), findsOneWidget);
  });

  testWidgets('Business over: talk to us, no paywall in the notice', (tester) async {
    await _pump(tester, _sub(SubscriptionPlan.business, orders: 510, users: 3), cnpjs: 2);
    expect(find.text('Você passou de 500 OS este mês. Fale com a gente para ajustar o plano.'), findsOneWidget);
    expect(find.text('O que o Business dá a mais'), findsNothing);
    expect(find.text('CNPJs na nota fiscal'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('Pro: CNPJs of the nota and what Business adds', (tester) async {
    await _pump(tester, _sub(SubscriptionPlan.pro, orders: 20, users: 3), cnpjs: 1);
    expect(find.text('20 de 150'), findsOneWidget);
    expect(find.text('3 de 5'), findsOneWidget);
    expect(find.text('1 de 2'), findsOneWidget);
    expect(find.text('O que o Business dá a mais'), findsOneWidget);
    expect(find.text('Ações em lote'), findsOneWidget);
    expect(find.text('ChatGPT e Claude'), findsOneWidget);
    expect(find.byKey(const ValueKey('plan_notice_ordersNear')), findsNothing);
  });

  testWidgets('a full Starter team says so; the row opens Equipe', (tester) async {
    var opened = 0;
    await _pump(tester, _sub(SubscriptionPlan.starter, users: 2), onOpenTeam: () => opened++);
    expect(find.text('A equipe já tem 2 de 2 pessoas. Para chamar mais alguém, mude de plano.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('plan_usage_people')));
    expect(opened, 1);
  });

  testWidgets('without the permission the people row opens nothing', (tester) async {
    var opened = 0;
    await _pump(tester, _sub(SubscriptionPlan.starter), onOpenTeam: () => opened++, canManage: false);
    await tester.tap(find.byKey(const ValueKey('plan_usage_people')));
    expect(opened, 0);
  });

  testWidgets('a technician is told to ask the administrator', (tester) async {
    PaywallLauncher.roleResolver = () => 'technician';
    await _pump(tester, _sub(SubscriptionPlan.free, orders: 9));
    expect(find.text('Ver planos'), findsNothing);
    expect(find.text('Gerenciar assinatura'), findsNothing);
    expect(find.text('Peça ao administrador da conta para mudar de plano.'), findsOneWidget);
  });

  testWidgets('switch off: the use without limits and no notice', (tester) async {
    FeatureGateService.debugPlanLimitsEnforcedOverride = false;
    await _pump(tester, _sub(SubscriptionPlan.free, orders: 30));
    expect(find.text('30'), findsOneWidget);
    expect(find.text('Sem limite'), findsWidgets);
    expect(find.byKey(const ValueKey('plan_notice_ordersBlocked')), findsNothing);
  });

  testWidgets('back button reads the screen below', (tester) async {
    final store = SubscriptionStore()..latest = _sub(SubscriptionPlan.starter);
    await tester.pumpWidget(
      Provider<SubscriptionStore>.value(
        value: store,
        child: CupertinoApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          onGenerateRoute: (_) => CupertinoPageRoute(
            title: 'Oficina do Zé',
            builder: (context) => CupertinoButton(
              child: const Text('open'),
              onPressed: () => Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => PlanScreen(hasPermission: (_) => true, loadCnpjs: () async => 0),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Oficina do Zé'), findsOneWidget);
  });
}
