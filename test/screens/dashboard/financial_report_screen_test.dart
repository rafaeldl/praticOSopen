import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
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
import 'package:praticos/theme/app_spacing.dart';
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
    DateTime start,
    DateTime end,
  ) async {
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
        {
          'id': 'ana',
          'name': 'Ana Ribeiro',
          'total': 1000.0,
          'unpaidTotal': 0.0,
        },
        {
          'id': 'bia',
          'name': 'Bia Souza',
          'total': 500.0,
          'unpaidTotal': 500.0,
        },
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
    int initialMonthOffset = 0,
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
          home: FinancialReportScreen(
            openCustomPeriod: openCustomPeriod,
            initialMonthOffset: initialMonthOffset,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return store;
  }

  testWidgets('shows the report title, the totals and the customer ranking', (
    tester,
  ) async {
    final store = await pumpReport(tester);

    expect(find.text(l10n.financialReport), findsWidgets);
    expect(find.text(FormatService().formatCurrency(1500)), findsWidgets);
    expect(find.text(FormatService().formatCurrency(1000)), findsWidgets);
    expect(find.text('Ana Ribeiro'), findsWidgets);
    expect(find.text('Bia Souza'), findsWidgets);
    // Starts on the current month, as the tab does.
    expect(store.loads.first, 'mês/0');
  });

  testWidgets('plain words: sentence case, "OS" count and no "Ticket"', (
    tester,
  ) async {
    await pumpReport(tester);

    expect(find.text('Relatório financeiro'), findsWidgets);
    // Same words as the tab mean the same number: this screen splits Vendido.
    expect(find.text('Vendido'), findsOneWidget);
    expect(find.text('Já pago'), findsOneWidget);
    expect(find.text('Falta pagar'), findsOneWidget);
    expect(find.text('Recebido'), findsNothing);
    expect(find.text('Falta receber'), findsNothing);
    expect(find.text('Faturamento'), findsNothing);
    expect(find.textContaining('Média por OS'), findsOneWidget);
    expect(find.textContaining('Ticket'), findsNothing);
    expect(find.textContaining(RegExp(r'\bordem\b')), findsNothing);
    expect(l10n.nOrdersCount(0), '0 OS');
    expect(l10n.nOrdersCount(3), '3 OS');
  });

  testWidgets('has the "Mandar relatório em PDF" button at the bottom', (
    tester,
  ) async {
    await pumpReport(tester);

    final button = find.byKey(const Key('financialSendReportPdf'));
    expect(button, findsOneWidget);
    expect(
      find.descendant(
        of: button,
        matching: find.text('Mandar relatório em PDF'),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSize(button).height,
      greaterThanOrEqualTo(AppSizes.primaryButtonHeight),
    );
  });

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('reportMore')));
    await tester.pumpAndSettle();
  }

  testWidgets('no segmented control: other periods come from "…"', (
    tester,
  ) async {
    await pumpReport(tester);

    expect(find.byType(CupertinoSlidingSegmentedControl<String>), findsNothing);
    expect(find.text(l10n.financialOtherPeriod), findsNothing);

    await openMenu(tester);
    for (final label in [
      l10n.reportSeeOtherPeriod,
      l10n.today,
      l10n.reportThisWeek,
      l10n.reportThisMonth,
      l10n.reportThisYear,
      l10n.reportPickDates,
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('picking "Este ano" in "…" reloads the dashboard', (
    tester,
  ) async {
    final store = await pumpReport(tester);

    await openMenu(tester);
    await tester.tap(find.text(l10n.reportThisYear));
    await tester.pumpAndSettle();

    expect(store.loads.last, 'ano/0');
  });

  testWidgets('openCustomPeriod opens the dates sheet', (tester) async {
    // Wide view: the test font (Ahem) is much wider than the system font.
    await pumpReport(tester, openCustomPeriod: true, width: 2400);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(l10n.reportWhichPeriod), findsOneWidget);
    expect(find.text(l10n.reportStarts), findsOneWidget);
    expect(find.text(l10n.reportEnds), findsOneWidget);
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
  });

  testWidgets('week and previous period reload the dashboard', (tester) async {
    final store = await pumpReport(tester);

    await openMenu(tester);
    await tester.tap(find.text(l10n.reportThisWeek));
    await tester.pumpAndSettle();
    expect(store.loads.last, 'semana/0');

    await tester.tap(find.bySemanticsLabel(l10n.reportPreviousPeriod));
    await tester.pump();
    await tester.pump();
    expect(store.loads.last, 'semana/-1');
  });

  testWidgets('"Escolher datas" opens the X/✓ sheet and applies the range', (
    tester,
  ) async {
    final store = await pumpReport(tester, width: 2400);

    await openMenu(tester);
    await tester.tap(find.text(l10n.reportPickDates));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(l10n.reportWhichPeriod), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('new_order_save')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(store.loads.last, 'custom');
    expect(find.text(l10n.reportWhichPeriod), findsNothing);
  });

  testWidgets('section labels are sentence case, not uppercase', (
    tester,
  ) async {
    await pumpReport(tester);

    expect(find.text(l10n.billing), findsOneWidget);
    expect(find.text(l10n.billing.toUpperCase()), findsNothing);
    expect(find.text(l10n.customers.toUpperCase()), findsNothing);
  });

  testWidgets('tapping Recebido filters the rankings and shows a check', (
    tester,
  ) async {
    await pumpReport(tester);

    await tester.tap(find.text(l10n.financialAlreadyPaid).first);
    await tester.pump();

    expect(find.text(l10n.customersReceived), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.checkmark_alt), findsOneWidget);
  });

  testWidgets('opens in the month chosen in the tab', (tester) async {
    await pumpReport(tester, initialMonthOffset: -1);

    final now = DateTime.now();
    expect(
      find.text(FormatService().formatMonthYearTitle(
        DateTime(now.year, now.month - 1, 1),
      )),
      findsOneWidget,
    );
  });

  testWidgets('empty period shows a single sentence and no sections', (
    tester,
  ) async {
    await pumpReport(tester, empty: true);

    expect(find.text(l10n.noOrdersInPeriod), findsOneWidget);
    expect(find.text(l10n.billing), findsNothing);
    expect(find.text(l10n.customers), findsNothing);
    // The stepper and "…" stay so the person can change the period.
    expect(find.bySemanticsLabel(l10n.reportPreviousPeriod), findsOneWidget);
    expect(find.byKey(const Key('reportMore')), findsOneWidget);
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

  group('"Preparando relatório" alert', () {
    const printing = MethodChannel('net.nfet.printing');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() => messenger.setMockMethodCallHandler(printing, null));

    /// The report as the Financeiro tab opens it: pushed on the tab's own
    /// navigator, while dialogs go to the root one.
    Future<void> pumpReportInTab(
      WidgetTester tester, {
      Locale locale = const Locale('pt'),
      Future<Object?> Function(MethodCall)? onPrinting,
    }) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      messenger.setMockMethodCallHandler(
        printing,
        onPrinting ?? (_) async => 1,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<OrderStore>.value(value: _FakeOrderStore()),
            ChangeNotifierProvider<SegmentConfigProvider>(
              create: (_) => SegmentConfigProvider(),
            ),
          ],
          child: CupertinoApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CupertinoTabView(
              builder: (context) => CupertinoPageScaffold(
                child: Center(
                  child: CupertinoButton(
                    onPressed: () => Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) => const FinancialReportScreen(),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    /// Lets the PDF build, which needs real async, reach the share sheet.
    Future<void> finishSharing(WidgetTester tester) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 1)),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tapSend(WidgetTester tester) async {
      final send = find.byKey(const Key('financialSendReportPdf'));
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pump();
      await tester.pump();
    }

    for (final locale in const [Locale('pt'), Locale('en'), Locale('es')]) {
      for (final scale in const [1.0, 1.3, 2.0, 3.0]) {
        testWidgets(
          'wraps instead of overflowing (${locale.languageCode}, x$scale)',
          (tester) async {
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.platformDispatcher.clearAllTestValues);
            addTearDown(tester.view.reset);
            tester.view.physicalSize = const Size(1170, 2532);
            tester.view.devicePixelRatio = 3;

            await tester.pumpWidget(
              CupertinoApp(
                locale: locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const ReportLoadingAlert(),
              ),
            );

            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets('the text has its accent', (tester) async {
      expect(l10n.preparingReport, 'Preparando relatório...');
    });

    testWidgets('closes before the share sheet and keeps the report open', (
      tester,
    ) async {
      var alertOpenOnShare = true;
      await pumpReportInTab(
        tester,
        onPrinting: (call) async {
          if (call.method == 'sharePdf') {
            alertOpenOnShare = tester
                .state<NavigatorState>(find.byType(Navigator).first)
                .canPop();
          }
          return 1;
        },
      );

      await tapSend(tester);
      await finishSharing(tester);

      expect(alertOpenOnShare, isFalse);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(find.byType(FinancialReportScreen), findsOneWidget);
    });

    testWidgets('an error closes the alert and shows the error dialog', (
      tester,
    ) async {
      await pumpReportInTab(
        tester,
        onPrinting: (call) async => throw PlatformException(code: 'failed'),
      );

      await tapSend(tester);
      await finishSharing(tester);

      expect(find.text(l10n.preparingReport), findsNothing);
      expect(find.text(l10n.errorGeneratingReport), findsOneWidget);
      expect(find.byType(FinancialReportScreen), findsOneWidget);
    });
  });
}
