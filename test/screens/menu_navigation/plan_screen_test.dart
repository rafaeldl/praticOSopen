import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/mobx/subscription_store.dart';
import 'package:praticos/models/subscription.dart';
import 'package:praticos/screens/menu_navigation/more/plan_screen.dart';
import 'package:praticos/services/paywall_launcher.dart';
import 'package:praticos/services/subscription_service.dart';
import 'package:provider/provider.dart';

Subscription _starter({int users = 1, int photos = 10, int forms = 1}) =>
    Subscription(
      plan: SubscriptionPlan.starter,
      source: SubscriptionSource.store,
      expiresAt: DateTime.now().add(const Duration(days: 30)),
      usage: SubscriptionUsage(
        usersActive: users,
        photosThisMonth: photos,
        formTemplatesActive: forms,
      ),
    );

Future<void> _pump(
  WidgetTester tester,
  Subscription subscription, {
  VoidCallback? onOpenTeam,
  VoidCallback? onOpenChecklists,
}) async {
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
          onOpenChecklists: onOpenChecklists,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SubscriptionService.debugPaidPlansEnabledOverride = true;
    PaywallLauncher.roleResolver = () => 'owner';
  });
  tearDown(() {
    SubscriptionService.debugPaidPlansEnabledOverride = null;
  });

  test('usage level: near from 80%, at limit when full, -1 is unlimited', () {
    expect(
      const PlanUsage(PlanResource.photos, 180, 200).level,
      PlanUsageLevel.near,
    );
    expect(
      const PlanUsage(PlanResource.team, 3, 3).level,
      PlanUsageLevel.atLimit,
    );
    expect(
      const PlanUsage(PlanResource.photos, 10, 200).level,
      PlanUsageLevel.ok,
    );
    expect(
      const PlanUsage(PlanResource.photos, 900, -1).level,
      PlanUsageLevel.unlimited,
    );
  });

  testWidgets('shows plan, renewal and what is in use, in prototype order', (
    tester,
  ) async {
    await _pump(tester, _starter(users: 2, photos: 180, forms: 2));

    expect(find.textContaining('Starter · renova em'), findsOneWidget);
    expect(find.text('O que você está usando'), findsOneWidget);
    final team = tester.getTopLeft(find.text('Pessoas na equipe')).dy;
    final photos = tester.getTopLeft(find.text('Fotos este mês')).dy;
    final forms = tester.getTopLeft(find.text('Checklists')).dy;
    expect(team < photos && photos < forms, isTrue);
    expect(find.text('2 de 3'), findsNWidgets(2));
    expect(find.text('180 de 200'), findsOneWidget);
    expect(find.text('Quase no limite'), findsOneWidget);
    // No limit reached: no block, "Ver planos" is a link.
    expect(find.byKey(const ValueKey('plan_limit_block')), findsNothing);
    expect(find.text('Ver planos'), findsOneWidget);
    expect(find.text('Gerenciar assinatura'), findsOneWidget);
    expect(find.text('Restaurar compras'), findsOneWidget);
  });

  testWidgets('a full team shows the limit block with "Ver planos"', (
    tester,
  ) async {
    await _pump(tester, _starter(users: 3));

    expect(find.text('Limite do plano'), findsOneWidget);
    expect(
      find.text(
        'A equipe já tem 3 de 3 pessoas. Para chamar mais alguém, '
        'mude de plano.',
      ),
      findsOneWidget,
    );
    expect(find.text('No limite · conta o convite'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('plan_limit_block')),
        matching: find.text('Ver planos'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('team and checklists rows open their screens', (tester) async {
    var team = 0;
    var forms = 0;
    await _pump(
      tester,
      _starter(),
      onOpenTeam: () => team++,
      onOpenChecklists: () => forms++,
    );

    await tester.tap(find.text('Pessoas na equipe'));
    await tester.tap(find.text('Checklists'));
    expect(team, 1);
    expect(forms, 1);
  });

  testWidgets('a technician is told to ask the administrator', (tester) async {
    PaywallLauncher.roleResolver = () => 'technician';
    await _pump(tester, _starter(users: 3));

    expect(find.text('Ver planos'), findsNothing);
    expect(find.text('Gerenciar assinatura'), findsNothing);
    expect(
      find.text('Peça ao administrador da conta para mudar de plano.'),
      findsOneWidget,
    );
  });

  testWidgets('back button reads the screen below', (tester) async {
    final store = SubscriptionStore()..latest = _starter();
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
              onPressed: () => Navigator.of(
                context,
              ).push(CupertinoPageRoute(builder: (_) => const PlanScreen())),
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
