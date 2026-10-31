import 'package:mobx/mobx.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/repositories/tenant/customer_charge_repository.dart';
import 'package:praticos/repositories/tenant/order_charge_repository.dart';
import 'package:praticos/repositories/v2/order_repository_v2.dart';
import 'package:praticos/utils/financial_summary.dart';
import 'package:praticos/utils/next_charge.dart';

part 'financial_tab_store.g.dart';

/// Loads the orders of one month.
typedef MonthOrdersLoader = Future<List<Order?>> Function(int monthOffset);

/// Loads the orders that may have been paid since a date, from any month.
typedef PaidOrdersLoader = Future<List<Order?>> Function(DateTime since);

/// Loads every order with an open payment, from any month.
typedef OpenOrdersLoader = Future<List<Order?>> Function();

/// Whether a customer already has a payment link open.
typedef OpenChargeChecker = Future<bool> Function(Debtor debtor);

enum FinancialTabStatus { loading, ready, error }

/// State of the Financeiro tab: the chosen month (never in the future), the
/// open amounts of the whole company, which do not depend on it, and the next
/// customer to charge.
///
/// Reuses the repository queries of the dashboard (`getOrdersByCustomPeriod`)
/// and adds the "everything open" and "paid since" queries.
class FinancialTabStore = _FinancialTabStore with _$FinancialTabStore;

abstract class _FinancialTabStore with Store {
  _FinancialTabStore({
    MonthOrdersLoader? monthLoader,
    OpenOrdersLoader? openLoader,
    PaidOrdersLoader? paidLoader,
    OpenChargeChecker? openChargeChecker,
    NextChargeSnoozes? snoozes,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       _hasOpenCharge = openChargeChecker ?? _defaultHasOpenCharge,
       _snoozes = snoozes ?? NextChargeSnoozes(clock: clock) {
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
        (since) => repo().getOrdersPaidSince(Global.companyAggr!.id!, since);
  }

  final DateTime Function() _clock;
  final OpenChargeChecker _hasOpenCharge;
  final NextChargeSnoozes _snoozes;
  late final MonthOrdersLoader _monthLoader;
  late final OpenOrdersLoader _openLoader;
  late final PaidOrdersLoader _paidLoader;

  @observable
  FinancialTabStatus status = FinancialTabStatus.loading;

  /// 0 = current month, -1 = previous month, and so on.
  @observable
  int monthOffset = 0;

  /// The month changed and its numbers are on the way. The rest of the tab
  /// stays: it does not depend on the month.
  @observable
  bool monthLoading = false;

  @observable
  ObservableList<Order?> monthOrders = ObservableList<Order?>();

  @observable
  ObservableList<Order?> openOrders = ObservableList<Order?>();

  @observable
  ObservableList<Order?> paidOrders = ObservableList<Order?>();

  /// Who Próxima cobrança suggests; null hides the section.
  @observable
  Debtor? nextCharge;

  /// Bumped on each search for [nextCharge]: only the latest one counts.
  int _nextChargeRun = 0;

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
    final offset = monthOffset;
    try {
      await _reload();
    } catch (_) {
      if (offset == monthOffset) {
        runInAction(() => status = FinancialTabStatus.error);
      }
    }
  }

  /// Reloads without dropping the current content (pull to refresh, return
  /// from another screen). Keeps the old data if the reload fails.
  @action
  Future<void> refresh() async {
    try {
      await _reload();
    } catch (_) {
      if (status != FinancialTabStatus.ready) {
        runInAction(() => status = FinancialTabStatus.error);
      }
    }
  }

  /// "Agora não": pauses [debtor] and moves on to the next customer.
  Future<void> snoozeNextCharge(Debtor debtor) async {
    await _snoozes.snooze(debtor.key);
    await _resolveNextCharge();
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

  /// Loads only what depends on the month: the rest of the tab stays as is.
  Future<void> _goToMonth(int offset) async {
    runInAction(() {
      monthOffset = offset;
      monthLoading = status == FinancialTabStatus.ready;
    });
    if (status != FinancialTabStatus.ready) return load();
    try {
      final results = await _fetchMonth(offset);
      // Ignore a late answer for a month the user already left.
      if (offset != monthOffset) return;
      _applyMonth(results);
    } catch (_) {
      if (offset == monthOffset) {
        runInAction(() {
          monthLoading = false;
          status = FinancialTabStatus.error;
        });
      }
    }
  }

  DateTime _monthAt(int offset) {
    final now = _clock();
    return DateTime(now.year, now.month + offset, 1);
  }

  Future<List<List<Order?>>> _fetchMonth(int offset) => Future.wait([
    _monthLoader(offset),
    _paidLoader(_monthAt(offset)),
  ]);

  void _applyMonth(List<List<Order?>> results) {
    runInAction(() {
      monthOrders = ObservableList.of(results[0]);
      paidOrders = ObservableList.of(results[1]);
      monthLoading = false;
    });
  }

  Future<void> _reload() async {
    final offset = monthOffset;
    final (results, open) = await (_fetchMonth(offset), _openLoader()).wait;
    runInAction(() {
      openOrders = ObservableList.of(open);
      // The user may have moved to another month in the meantime: whoever
      // loads that month settles the status.
      if (offset == monthOffset) {
        _applyMonth(results);
        status = FinancialTabStatus.ready;
      }
      // Until the links are read, keep showing what is true now.
      final current = nextCharge;
      if (current != null) {
        nextCharge = summary.debtors
            .where((d) => d.key == current.key)
            .firstOrNull;
      }
    });
    await _resolveNextCharge();
  }

  /// The first candidate without an open link. Links are read only until one
  /// is found. If they cannot be read the section hides: suggesting a charge
  /// could duplicate one.
  Future<void> _resolveNextCharge() async {
    final run = ++_nextChargeRun;
    Debtor? next;
    try {
      final candidates = nextChargeCandidates(
        summary.debtors,
        now: _clock(),
        snoozed: await _snoozes.active(),
      );
      for (final debtor in candidates) {
        final hasLink = await _hasOpenCharge(
          debtor,
        ).timeout(const Duration(seconds: 8));
        if (run != _nextChargeRun) return;
        if (!hasLink) {
          next = debtor;
          break;
        }
      }
    } catch (_) {
      next = null;
    }
    if (run == _nextChargeRun) runInAction(() => nextCharge = next);
  }

  /// Any open order of the customer, or their charge of several orders.
  static Future<bool> _defaultHasOpenCharge(Debtor debtor) async {
    final companyId = Global.companyAggr!.id!;
    final customerId = debtor.customerId;
    if (customerId != null &&
        await CustomerChargeRepository().hasOpen(companyId, customerId)) {
      return true;
    }
    final orderCharges = OrderChargeRepository();
    for (final order in debtor.openOrders) {
      if (await orderCharges.hasOpen(companyId, order.id!)) return true;
    }
    return false;
  }
}
