import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/dashboard/financial_report_screen.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:provider/provider.dart';

/// Firebase core mock whose default app has a storage bucket.
class _FirebaseCoreMockWithBucket extends MockFirebaseApp {
  @override
  Future<List<CoreInitializeResponse>> initializeCore() async => [
        CoreInitializeResponse(
          name: defaultFirebaseAppName,
          options: CoreFirebaseOptions(
            apiKey: '123',
            projectId: '123',
            appId: '123',
            messagingSenderId: '123',
            storageBucket: 'test.appspot.com',
          ),
          pluginConstants: {},
        ),
      ];
}

/// Dashboard store that fills its totals from memory instead of Firestore.
class _FakeOrderStore extends OrderStore {
  final List<String> loads = [];
  bool empty = false;

  @override
  Future<void> loadOrdersForDashboardCustomRange(
      DateTime start, DateTime end) async {
    loads.add('custom');
  }

  @override
  Future<void> loadOrdersForDashboard() async {
    loads.add('$selectedDashboardPeriod/$periodOffset');
    if (empty) {
      totalRevenue = 0;
      totalPaidAmount = 0;
      totalUnpaidAmount = 0;
      recentOrders.clear();
      customerRanking.clear();
      return;
    }
    totalRevenue = 1500;
    totalPaidAmount = 1000;
    totalUnpaidAmount = 500;
    recentOrders
      ..clear()
      ..addAll([
        Order()
          ..id = 'o1'
          ..number = 7
          ..total = 1000
          ..payment = 'paid'
          ..customer = (CustomerAggr()
            ..id = 'ana'
            ..name = 'Ana Ribeiro'),
        Order()
          ..id = 'o2'
          ..number = 8
          ..total = 500
          ..payment = 'unpaid'
          ..customer = (CustomerAggr()
            ..id = 'bia'
            ..name = 'Bia Souza'),
      ]);
    customerRanking
      ..clear()
      ..addAll([
        {'id': 'ana', 'name': 'Ana Ribeiro', 'total': 1000.0, 'unpaidTotal': 0.0},
        {'id': 'bia', 'name': 'Bia Souza', 'total': 500.0, 'unpaidTotal': 500.0},
      ]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l10n = AppLocalizationsPt();

  setUpAll(() async {
    TestFirebaseCoreHostApi.setUp(_FirebaseCoreMockWithBucket());
    await Firebase.initializeApp();
    await initializeDateFormatting('pt_BR');
    FormatService().setLocale('pt');
  });

  Future<_FakeOrderStore> pumpReport(
    WidgetTester tester, {
    bool openCustomPeriod = false,
    Brightness brightness = Brightness.light,
    double width = 800,
    bool empty = false,
  }) async {
    tester.view.physicalSize = Size(width, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final store = _FakeOrderStore()..empty = empty;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<OrderStore>.value(value: store),
          ChangeNotifierProvider<SegmentConfigProvider>(
            create: (_) => SegmentConfigProvider(),
          ),
        ],
        child: CupertinoApp(
          locale: const Locale('pt'),
          theme: CupertinoThemeData(brightness: brightness),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FinancialReportScreen(openCustomPeriod: openCustomPeriod),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return store;
  }

  testWidgets('shows the report title, the totals and the customer ranking',
      (tester) async {
    final store = await pumpReport(tester);

    expect(find.text(l10n.financialReport), findsWidgets);
    expect(find.text(FormatService().formatCurrency(1500)), findsWidgets);
    expect(find.text(FormatService().formatCurrency(1000)), findsWidgets);
    expect(find.text('Ana Ribeiro'), findsWidgets);
    expect(find.text('Bia Souza'), findsWidgets);
    // Starts on the current month, as the tab does.
    expect(store.loads.first, 'mês/0');
  });

  testWidgets('keeps the period choices (day, week, month, year, other)',
      (tester) async {
    await pumpReport(tester);

    for (final label in [
      l10n.today,
      l10n.week,
      l10n.month,
      l10n.year,
      l10n.financialOtherPeriod,
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
  });

  testWidgets('switching the period reloads the dashboard', (tester) async {
    final store = await pumpReport(tester);

    await tester.tap(find.text(l10n.year).first);
    await tester.pump();
    await tester.pump();

    expect(store.loads.last, 'ano/0');
  });

  testWidgets('openCustomPeriod opens the date range picker', (tester) async {
    // Wide view: the test font (Ahem) is much wider than the system font.
    await pumpReport(tester, openCustomPeriod: true, width: 2400);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(l10n.selectPeriod), findsOneWidget);
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
  });

  testWidgets('week and previous period reload the dashboard', (tester) async {
    final store = await pumpReport(tester);

    await tester.tap(find.text(l10n.week).first);
    await tester.pump();
    await tester.pump();
    expect(store.loads.last, 'semana/0');

    await tester.tap(find.bySemanticsLabel(l10n.reportPreviousPeriod));
    await tester.pump();
    await tester.pump();
    expect(store.loads.last, 'semana/-1');
  });

  testWidgets('"Outro período" opens a sheet and applies the range',
      (tester) async {
    final store = await pumpReport(tester, width: 2400);

    await tester.tap(find.text(l10n.financialOtherPeriod));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(l10n.selectPeriod), findsOneWidget);

    await tester.tap(find.text(l10n.ok));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(store.loads.last, 'custom');
    expect(find.text(l10n.selectPeriod), findsNothing);
  });

  testWidgets('section labels are sentence case, not uppercase',
      (tester) async {
    await pumpReport(tester);

    expect(find.text(l10n.billing), findsOneWidget);
    expect(find.text(l10n.billing.toUpperCase()), findsNothing);
    expect(find.text(l10n.customers.toUpperCase()), findsNothing);
  });

  testWidgets('tapping Recebido filters the rankings and shows a check',
      (tester) async {
    await pumpReport(tester);

    await tester.tap(find.text(l10n.received).first);
    await tester.pump();

    expect(find.text(l10n.customersReceived), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.checkmark_alt), findsOneWidget);
  });

  testWidgets('empty period shows a single sentence and no sections',
      (tester) async {
    await pumpReport(tester, empty: true);

    expect(find.text(l10n.noOrdersInPeriod), findsOneWidget);
    expect(find.text(l10n.billing), findsNothing);
    expect(find.text(l10n.customers), findsNothing);
    // The period selector stays so the person can change the period.
    expect(find.text(l10n.week), findsWidgets);
  });

  testWidgets('renders in dark mode with dark role colors', (tester) async {
    await pumpReport(tester, brightness: Brightness.dark);

    expect(find.text(l10n.financialReport), findsWidgets);
    final ana = tester.widget<Text>(find.text('Ana Ribeiro').first);
    expect(ana.style!.color!.toARGB32(), AppColors.text.darkColor.toARGB32());
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty state renders in dark mode', (tester) async {
    await pumpReport(tester, brightness: Brightness.dark, empty: true);

    final empty = tester.widget<Text>(find.text(l10n.noOrdersInPeriod));
    expect(empty.style!.color!.toARGB32(), AppColors.text.darkColor.toARGB32());
    expect(tester.takeException(), isNull);
  });

  testWidgets('large Dynamic Type does not overflow', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await pumpReport(tester, width: 1200);

    expect(tester.takeException(), isNull);
  });
}
