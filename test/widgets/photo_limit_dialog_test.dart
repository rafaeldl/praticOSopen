import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/models/subscription.dart';
import 'package:praticos/services/feature_gate_service.dart';
import 'package:praticos/services/paywall_launcher.dart';
import 'package:praticos/services/subscription_service.dart';
import 'package:praticos/widgets/photo_limit_dialog.dart';

void main() {
  final l10n = AppLocalizationsPt();
  final originalResolver = PaywallLauncher.roleResolver;

  tearDown(() {
    PaywallLauncher.roleResolver = originalResolver;
    SubscriptionService.debugPaidPlansEnabledOverride = null;
  });

  FeatureGateResult limitReached(FeatureType type) => FeatureGateResult(
        isAllowed: false,
        currentUsage: 1,
        limit: 1,
        featureType: type,
        currentPlan: SubscriptionPlan.free,
      );

  Future<void> open(WidgetTester tester, FeatureGateResult result) async {
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CupertinoPageScaffold(
          child: Center(
            child: Builder(
              builder: (context) => CupertinoButton(
                onPressed: () => showFeatureLimitDialog(context, result),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('without paid plans: only OK, no plans', (tester) async {
    SubscriptionService.debugPaidPlansEnabledOverride = false;
    PaywallLauncher.roleResolver = () => 'admin';

    await open(tester, limitReached(FeatureType.photo));

    expect(find.text(l10n.ok), findsOneWidget);
    expect(find.text(l10n.viewPlans), findsNothing);
    expect(find.text(l10n.photoLimitUpgradeHint), findsNothing);
  });

  testWidgets('admin sees "View plans" and the upgrade hint', (tester) async {
    SubscriptionService.debugPaidPlansEnabledOverride = true;
    PaywallLauncher.roleResolver = () => 'admin';

    await open(tester, limitReached(FeatureType.photo));

    expect(find.text(l10n.viewPlans), findsOneWidget);
    expect(find.text(l10n.notNow), findsOneWidget);
    expect(find.text(l10n.photoLimitUpgradeHint), findsOneWidget);
  });

  testWidgets('member sees "ask your admin" and no buy button', (tester) async {
    SubscriptionService.debugPaidPlansEnabledOverride = true;
    PaywallLauncher.roleResolver = () => 'technician';

    await open(tester, limitReached(FeatureType.photo));

    expect(find.text(l10n.askAdminToChangePlan), findsOneWidget);
    expect(find.text(l10n.viewPlans), findsNothing);
    expect(find.text(l10n.ok), findsOneWidget);
  });

  testWidgets('form template limit uses the generic message', (tester) async {
    SubscriptionService.debugPaidPlansEnabledOverride = true;
    PaywallLauncher.roleResolver = () => 'admin';

    await open(tester, limitReached(FeatureType.formTemplate));

    expect(find.text(l10n.featureLimitReached(l10n.formTemplates)), findsOneWidget);
    expect(find.text(l10n.planLimitUpgradeHint), findsOneWidget);
  });

  testWidgets('"View plans" goes through PaywallLauncher', (tester) async {
    SubscriptionService.debugPaidPlansEnabledOverride = true;
    PaywallLauncher.roleResolver = () => 'admin';

    await open(tester, limitReached(FeatureType.collaborator));
    await tester.tap(find.text(l10n.viewPlans));
    await tester.pumpAndSettle();

    // SDK is not configured in tests, so the launcher reports "unavailable".
    expect(find.text(l10n.subscriptionUnavailable), findsOneWidget);
  });
}
