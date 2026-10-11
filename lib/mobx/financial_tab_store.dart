import 'package:mobx/mobx.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/repositories/v2/order_repository_v2.dart';
import 'package:praticos/utils/financial_summary.dart';

part 'financial_tab_store.g.dart';

/// Loads the orders of one month.
typedef MonthOrdersLoader = Future<List<Order?>> Function(int monthOffset);

/// Loads every order with an open payment, from any month.
typedef OpenOrdersLoader = Future<List<Order?>> Function();

enum FinancialTabStatus { loading, ready, error }

/// State of the Financeiro tab: the chosen month (never in the future) and
/// the open amounts of the whole company.
///
/// Reuses the repository queries of the dashboard (`getOrdersByCustomPeriod`)
/// and only adds the "everything open" query.
class FinancialTabStore = _FinancialTabStore with _$FinancialTabStore;

abstract class _FinancialTabStore with Store {
  _FinancialTabStore({
    MonthOrdersLoader? monthLoader,
    OpenOrdersLoader? openLoader,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    // Created on first use: tests inject loaders and never touch Firestore.
    OrderRepositoryV2? repository;
    OrderRepositoryV2 repo() => repository ??= OrderRepositoryV2();
    _monthLoader =
        monthLoader ??
        (offset) => repo().getOrdersByCustomPeriod(
          Global.companyAggr!.id!,
          'mês',
          offset,
        );
    _openLoader =
        openLoader ?? () => repo().getUnpaidOrders(Global.companyAggr!.id!);
  }

  final DateTime Function() _clock;
  late final MonthOrdersLoader _monthLoader;
  late final OpenOrdersLoader _openLoader;

  @observable
  FinancialTabStatus status = FinancialTabStatus.loading;

  /// 0 = current month, -1 = previous month, and so on.
  @observable
  int monthOffset = 0;

  @observable
  ObservableList<Order?> monthOrders = ObservableList<Order?>();

  @observable
  ObservableList<Order?> openOrders = ObservableList<Order?>();

  @computed
  DateTime get month {
    final now = _clock();
    return DateTime(now.year, now.month + monthOffset, 1);
  }

  @computed
  bool get isCurrentMonth => monthOffset == 0;

  @computed
  FinancialSummary get summary => FinancialSummary.compute(
    monthOrders: monthOrders,
    openOrders: openOrders,
  );

  /// Loads the month and the open amounts.
  @action
  Future<void> load() async {
    status = FinancialTabStatus.loading;
    try {
      final results = await Future.wait([_monthLoader(monthOffset), _openLoader()]);
      _apply(results[0], results[1]);
    } catch (_) {
      runInAction(() => status = FinancialTabStatus.error);
    }
  }

  /// Reloads without dropping the current content (pull to refresh, return
  /// from another screen). Keeps the old data if the reload fails.
  @action
  Future<void> refresh() async {
    try {
      final results = await Future.wait([_monthLoader(monthOffset), _openLoader()]);
      _apply(results[0], results[1]);
    } catch (_) {
      if (status != FinancialTabStatus.ready) {
        runInAction(() => status = FinancialTabStatus.error);
      }
    }
  }

  Future<void> previousMonth() => _goToMonth(monthOffset - 1);

  Future<void> nextMonth() {
    if (isCurrentMonth) return Future.value();
    return _goToMonth(monthOffset + 1);
  }

  Future<void> goToCurrentMonth() {
    if (isCurrentMonth) return Future.value();
    return _goToMonth(0);
  }

  Future<void> _goToMonth(int offset) async {
    runInAction(() {
      monthOffset = offset;
      status = FinancialTabStatus.loading;
    });
    try {
      final results = await Future.wait([_monthLoader(offset), _openLoader()]);
      // Ignore a late answer for a month the user already left.
      if (offset != monthOffset) return;
      _apply(results[0], results[1]);
    } catch (_) {
      if (offset == monthOffset) {
        runInAction(() => status = FinancialTabStatus.error);
      }
    }
  }

  void _apply(List<Order?> month, List<Order?> open) {
    runInAction(() {
      monthOrders = ObservableList.of(month);
      openOrders = ObservableList.of(open);
      status = FinancialTabStatus.ready;
    });
  }
}
