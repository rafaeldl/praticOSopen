import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/services/paywall_launcher.dart';
import 'package:praticos/services/subscription_service.dart';

void main() {
  final l10n = AppLocalizationsPt();
  final originalResolver = PaywallLauncher.roleResolver;

  tearDown(() {
    PaywallLauncher.roleResolver = originalResolver;
    SubscriptionService.debugPaidPlansEnabledOverride = null;
  });

  Future<void> tapAction(
    WidgetTester tester,
    Future<void> Function(BuildContext context) action,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CupertinoPageScaffold(
          child: Center(
            child: Builder(
              builder: (context) => CupertinoButton(
                onPressed: () => action(context),
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

  group('PaywallLauncher.canPurchase', () {
    test('owner and admin can buy', () {
      expect(PaywallLauncher.canPurchase('owner'), isTrue);
      expect(PaywallLauncher.canPurchase('admin'), isTrue);
    });

    test('other roles and no role cannot buy', () {
      for (final role in ['manager', 'supervisor', 'consultant', 'technician', null]) {
        expect(PaywallLauncher.canPurchase(role), isFalse, reason: '$role');
      }
    });
  });

  group('PaywallLauncher dialogs', () {
    testWidgets('non-admin sees "ask your admin" instead of the paywall', (tester) async {
      SubscriptionService.debugPaidPlansEnabledOverride = true;
      PaywallLauncher.roleResolver = () => 'technician';

      await tapAction(tester, PaywallLauncher.showPaywall);

      expect(find.text(l10n.askAdminToChangePlanTitle), findsOneWidget);
      expect(find.text(l10n.askAdminToChangePlan), findsOneWidget);
    });

    testWidgets('non-admin cannot open the Customer Center', (tester) async {
      SubscriptionService.debugPaidPlansEnabledOverride = true;
      PaywallLauncher.roleResolver = () => 'manager';

      await tapAction(tester, PaywallLauncher.showCustomerCenter);

      expect(find.text(l10n.askAdminToChangePlan), findsOneWidget);
    });

    testWidgets('admin without a configured SDK sees "unavailable"', (tester) async {
      SubscriptionService.debugPaidPlansEnabledOverride = true;
      PaywallLauncher.roleResolver = () => 'admin';

      await tapAction(tester, PaywallLauncher.showPaywall);

      expect(find.text(l10n.subscriptionUnavailable), findsOneWidget);
    });

    testWidgets('restore without SDK shows "unavailable" and returns false', (tester) async {
      SubscriptionService.debugPaidPlansEnabledOverride = false;
      PaywallLauncher.roleResolver = () => 'admin';
      bool? restored;

      await tapAction(tester, (context) async {
        restored = await PaywallLauncher.restore(context);
      });

      expect(find.text(l10n.subscriptionUnavailable), findsOneWidget);
      await tester.tap(find.text(l10n.ok));
      await tester.pumpAndSettle();
      expect(restored, isFalse);
    });

    testWidgets('non-admin cannot restore', (tester) async {
      SubscriptionService.debugPaidPlansEnabledOverride = true;
      PaywallLauncher.roleResolver = () => 'technician';
      bool? restored;

      await tapAction(tester, (context) async {
        restored = await PaywallLauncher.restore(context);
      });

      expect(find.text(l10n.askAdminToChangePlan), findsOneWidget);
      await tester.tap(find.text(l10n.ok));
      await tester.pumpAndSettle();
      expect(restored, isFalse);
    });
  });
}
