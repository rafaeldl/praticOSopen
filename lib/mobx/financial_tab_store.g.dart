// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'financial_tab_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$FinancialTabStore on _FinancialTabStore, Store {
  Computed<DateTime>? _$monthComputed;

  @override
  DateTime get month => (_$monthComputed ??= Computed<DateTime>(
    () => super.month,
    name: '_FinancialTabStore.month',
  )).value;
  Computed<bool>? _$isCurrentMonthComputed;

  @override
  bool get isCurrentMonth => (_$isCurrentMonthComputed ??= Computed<bool>(
    () => super.isCurrentMonth,
    name: '_FinancialTabStore.isCurrentMonth',
  )).value;
  Computed<FinancialSummary>? _$summaryComputed;

  @override
  FinancialSummary get summary =>
      (_$summaryComputed ??= Computed<FinancialSummary>(
        () => super.summary,
        name: '_FinancialTabStore.summary',
      )).value;

  late final _$statusAtom = Atom(
    name: '_FinancialTabStore.status',
    context: context,
  );

  @override
  FinancialTabStatus get status {
    _$statusAtom.reportRead();
    return super.status;
  }

  @override
  set status(FinancialTabStatus value) {
    _$statusAtom.reportWrite(value, super.status, () {
      super.status = value;
    });
  }

  late final _$monthOffsetAtom = Atom(
    name: '_FinancialTabStore.monthOffset',
    context: context,
  );

  @override
  int get monthOffset {
    _$monthOffsetAtom.reportRead();
    return super.monthOffset;
  }

  @override
  set monthOffset(int value) {
    _$monthOffsetAtom.reportWrite(value, super.monthOffset, () {
      super.monthOffset = value;
    });
  }

  late final _$monthOrdersAtom = Atom(
    name: '_FinancialTabStore.monthOrders',
    context: context,
  );

  @override
  ObservableList<Order?> get monthOrders {
    _$monthOrdersAtom.reportRead();
    return super.monthOrders;
  }

  @override
  set monthOrders(ObservableList<Order?> value) {
    _$monthOrdersAtom.reportWrite(value, super.monthOrders, () {
      super.monthOrders = value;
    });
  }

  late final _$openOrdersAtom = Atom(
    name: '_FinancialTabStore.openOrders',
    context: context,
  );

  @override
  ObservableList<Order?> get openOrders {
    _$openOrdersAtom.reportRead();
    return super.openOrders;
  }

  @override
  set openOrders(ObservableList<Order?> value) {
    _$openOrdersAtom.reportWrite(value, super.openOrders, () {
      super.openOrders = value;
    });
  }

  late final _$loadAsyncAction = AsyncAction(
    '_FinancialTabStore.load',
    context: context,
  );

  @override
  Future<void> load() {
    return _$loadAsyncAction.run(() => super.load());
  }

  late final _$refreshAsyncAction = AsyncAction(
    '_FinancialTabStore.refresh',
    context: context,
  );

  @override
  Future<void> refresh() {
    return _$refreshAsyncAction.run(() => super.refresh());
  }

  @override
  String toString() {
    return '''
status: ${status},
monthOffset: ${monthOffset},
monthOrders: ${monthOrders},
openOrders: ${openOrders},
month: ${month},
isCurrentMonth: ${isCurrentMonth},
summary: ${summary}
    ''';
  }
}
