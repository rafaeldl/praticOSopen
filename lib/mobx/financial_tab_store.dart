import 'package:mobx/mobx.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/repositories/v2/order_repository_v2.dart';
import 'package:praticos/utils/financial_summary.dart';

part 'financial_tab_store.g.dart';

/// Loads the orders of one month.
typedef MonthOrdersLoader = Future<List<Order?>> Function(int monthOffset);

/// Loads the orders that may have been paid since a date, from any month.
typedef PaidOrdersLoader = Future<List<Order?>> Function(DateTime since);

/// Loads every order with an open payment, from any month.
typedef OpenOrdersLoader = Future<List<Order?>> Function();

enum FinancialTabStatus { loading, ready, error }

/// State of the Financeiro tab: the chosen month (never in the future) and
/// the open amounts of the whole company.
///
/// Reuses the repository queries of the dashboard (`getOrdersByCustomPeriod`)
/// and adds the "everything open" and "paid since" queries.
class FinancialTabStore = _FinancialTabStore with _$FinancialTabStore;

abstract class _FinancialTabStore with Store {
  _FinancialTabStore({
    MonthOrdersLoader? monthLoader,
    OpenOrdersLoader? openLoader,
    PaidOrdersLoader? paidLoader,
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
    _paidLoader =
        paidLoader ??
        (since) =>
            repo().getOrdersUpdatedSince(Global.companyAggr!.id!, since);
  }

  final DateTime Function() _clock;
  late final MonthOrdersLoader _monthLoader;
  late final OpenOrdersLoader _openLoader;
  late final PaidOrdersLoader _paidLoader;

  @observable
  FinancialTabStatus status = FinancialTabStatus.loading;

  /// 0 = current month, -1 = previous month, and so on.
  @observable
  int monthOffset = 0;

  @observable
  ObservableList<Order?> monthOrders = ObservableList<Order?>();

  @observable
  ObservableList<Order?> openOrders = ObservableList<Order?>();

  @observable
  ObservableList<Order?> paidOrders = ObservableList<Order?>();

  @computed
  DateTime get month => _monthAt(monthOffset);

  @computed
  bool get isCurrentMonth => monthOffset == 0;

  @computed
  FinancialSummary get summary => FinancialSummary.compute(
    month: month,
    monthOrders: monthOrders,
    openOrders: openOrders,
    paidOrders: paidOrders,
  );

  /// Loads the month and the open amounts.
  @action
  Future<void> load() async {
    status = FinancialTabStatus.loading;
    try {
      _apply(await _fetch(monthOffset));
    } catch (_) {
      runInAction(() => status = FinancialTabStatus.error);
    }
  }

  /// Reloads without dropping the current content (pull to refresh, return
  /// from another screen). Keeps the old data if the reload fails.
  @action
  Future<void> refresh() async {
    try {
      _apply(await _fetch(monthOffset));
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
      final results = await _fetch(offset);
      // Ignore a late answer for a month the user already left.
      if (offset != monthOffset) return;
      _apply(results);
    } catch (_) {
      if (offset == monthOffset) {
        runInAction(() => status = FinancialTabStatus.error);
      }
    }
  }

  DateTime _monthAt(int offset) {
    final now = _clock();
    return DateTime(now.year, now.month + offset, 1);
  }

  Future<List<List<Order?>>> _fetch(int offset) => Future.wait([
    _monthLoader(offset),
    _openLoader(),
    _paidLoader(_monthAt(offset)),
  ]);

  void _apply(List<List<Order?>> results) {
    runInAction(() {
      monthOrders = ObservableList.of(results[0]);
      openOrders = ObservableList.of(results[1]);
      paidOrders = ObservableList.of(results[2]);
      status = FinancialTabStatus.ready;
    });
  }
}
