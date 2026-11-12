import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/mobx/subscription_store.dart';
import 'package:praticos/models/subscription.dart';
import 'package:praticos/services/feature_gate_service.dart';
import 'package:praticos/services/paywall_launcher.dart';
import 'package:praticos/widgets/plan_feature_notice.dart';
import 'package:provider/provider.dart';

/// Pumps a button that runs [ensurePlanFeature] for [feature] on [plan].
Future<List<bool>> _pump(WidgetTester tester, SubscriptionPlan plan, PlanFeature feature) async {
  final results = <bool>[];
  final store = SubscriptionStore()..latest = Subscription(plan: plan);
  await tester.pumpWidget(
    Provider<SubscriptionStore>.value(
      value: store,
      child: CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => CupertinoButton(
            child: const Text('go'),
            onPressed: () => results.add(ensurePlanFeature(context, feature)),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
  return results;
}

void main() {
  tearDown(() {
    FeatureGateService.debugPlanLimitsEnforcedOverride = null;
    PaywallLauncher.roleResolver = () => 'owner';
  });

  testWidgets('switch off: allowed, no notice', (tester) async {
    FeatureGateService.debugPlanLimitsEnforcedOverride = false;
    final results = await _pump(tester, SubscriptionPlan.free, PlanFeature.contracts);
    expect(results, [true]);
    expect(find.byKey(const ValueKey('plan_feature_notice')), findsNothing);
  });

  testWidgets('switch on, Starter, contracts: notice with the plan that has it', (tester) async {
    FeatureGateService.debugPlanLimitsEnforcedOverride = true;
    PaywallLauncher.roleResolver = () => 'owner';
    final results = await _pump(tester, SubscriptionPlan.starter, PlanFeature.contracts);
    expect(results, [false]);
    expect(find.text('Recurso do plano Pro'), findsOneWidget);
    expect(find.text('Contratos. Para usar, mude para o plano Pro. O que você já tem continua.'), findsOneWidget);
    expect(find.byKey(const ValueKey('plan_feature_view_plans')), findsOneWidget);
  });

  testWidgets('switch on, a technician asks the owner, no plans button', (tester) async {
    FeatureGateService.debugPlanLimitsEnforcedOverride = true;
    PaywallLauncher.roleResolver = () => 'technician';
    await _pump(tester, SubscriptionPlan.pro, PlanFeature.bulkActions);
    expect(find.text('Recurso do plano Business'), findsOneWidget);
    expect(find.text('Ações em lote. Peça ao dono da empresa para mudar para o plano Business.'), findsOneWidget);
    expect(find.byKey(const ValueKey('plan_feature_view_plans')), findsNothing);
  });

  testWidgets('switch on, Pro has contracts: allowed', (tester) async {
    FeatureGateService.debugPlanLimitsEnforcedOverride = true;
    final results = await _pump(tester, SubscriptionPlan.pro, PlanFeature.contracts);
    expect(results, [true]);
  });

  test('every feature of the table has a name and a plan to move to', () {
    for (final feature in PlanFeature.values) {
      expect(FeatureGateService.requiredPlanFor(feature.name), isNotNull, reason: feature.name);
    }
    expect(FeatureGateService.requiredPlanFor('charges'), SubscriptionPlan.starter);
    expect(FeatureGateService.requiredPlanFor('teamRoles'), SubscriptionPlan.pro);
    expect(FeatureGateService.requiredPlanFor('api'), SubscriptionPlan.business);
  });
}
