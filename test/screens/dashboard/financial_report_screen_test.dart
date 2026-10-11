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

  @override
  Future<void> loadOrdersForDashboard() async {
    loads.add('$selectedDashboardPeriod/$periodOffset');
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
  }) async {
    tester.view.physicalSize = Size(width, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final store = _FakeOrderStore();
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
      l10n.period,
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

  testWidgets('renders in dark mode without exceptions', (tester) async {
    await pumpReport(tester, brightness: Brightness.dark);

    expect(find.text(l10n.financialReport), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
