import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/utils/report_week.dart';

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

class _RangeStore extends OrderStore {
  final ranges = <(DateTime, DateTime)>[];

  @override
  Future<void> loadOrdersForDashboardCustomRange(
    DateTime start,
    DateTime end,
  ) async {
    ranges.add((start, end));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestFirebaseCoreHostApi.setUp(_FirebaseCoreMockWithBucket());
    await Firebase.initializeApp();
  });

  setUp(() => Global.companyAggr = CompanyAggr()..id = 'c1');
  tearDown(() => Global.companyAggr = null);

  test('reloading a custom period keeps the chosen dates', () async {
    final store = _RangeStore();
    final start = DateTime(2026, 9, 3);
    final end = DateTime(2026, 9, 20);
    store.setCustomDateRange(start, end);

    // Filter, customer or pull to refresh.
    await store.loadOrdersForDashboard();

    expect(store.ranges, [(start, end), (start, end)]);
    expect(store.selectedDashboardPeriod, 'custom');
  });

  group('report week', () {
    test('Sunday to next Sunday, the week of today', () {
      // Tuesday, 3 Nov 2026.
      final week = reportWeek(DateTime(2026, 11, 3, 15), 0);
      expect(week.start, DateTime(2026, 11, 1));
      expect(week.end, DateTime(2026, 11, 8));
      expect(reportWeekLastDay(DateTime(2026, 11, 3), 0), DateTime(2026, 11, 7));
    });

    test('on a Sunday the week starts that day', () {
      final week = reportWeek(DateTime(2026, 11, 1, 9), 0);
      expect(week.start, DateTime(2026, 11, 1));
    });

    test('offset moves whole weeks, across the year', () {
      final week = reportWeek(DateTime(2026, 1, 2), -1);
      expect(week.start, DateTime(2025, 12, 21));
      expect(week.end, DateTime(2025, 12, 28));
    });
  });
}
