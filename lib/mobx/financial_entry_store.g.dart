// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'financial_entry_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$FinancialEntryStore on _FinancialEntryStore, Store {
  late final _$entryListAtom = Atom(
    name: '_FinancialEntryStore.entryList',
    context: context,
  );

  @override
  ObservableStream<List<FinancialEntry?>>? get entryList {
    _$entryListAtom.reportRead();
    return super.entryList;
  }

  @override
  set entryList(ObservableStream<List<FinancialEntry?>>? value) {
    _$entryListAtom.reportWrite(value, super.entryList, () {
      super.entryList = value;
    });
  }

  late final _$monthEntryListAtom = Atom(
    name: '_FinancialEntryStore.monthEntryList',
    context: context,
  );

  @override
  ObservableStream<List<FinancialEntry?>>? get monthEntryList {
    _$monthEntryListAtom.reportRead();
    return super.monthEntryList;
  }

  @override
  set monthEntryList(ObservableStream<List<FinancialEntry?>>? value) {
    _$monthEntryListAtom.reportWrite(value, super.monthEntryList, () {
      super.monthEntryList = value;
    });
  }

  late final _$totalPayableAtom = Atom(
    name: '_FinancialEntryStore.totalPayable',
    context: context,
  );

  @override
  double get totalPayable {
    _$totalPayableAtom.reportRead();
    return super.totalPayable;
  }

  @override
  set totalPayable(double value) {
    _$totalPayableAtom.reportWrite(value, super.totalPayable, () {
      super.totalPayable = value;
    });
  }

  late final _$totalReceivableAtom = Atom(
    name: '_FinancialEntryStore.totalReceivable',
    context: context,
  );

  @override
  double get totalReceivable {
    _$totalReceivableAtom.reportRead();
    return super.totalReceivable;
  }

  @override
  set totalReceivable(double value) {
    _$totalReceivableAtom.reportWrite(value, super.totalReceivable, () {
      super.totalReceivable = value;
    });
  }

  late final _$overdueCountAtom = Atom(
    name: '_FinancialEntryStore.overdueCount',
    context: context,
  );

  @override
  int get overdueCount {
    _$overdueCountAtom.reportRead();
    return super.overdueCount;
  }

  @override
  set overdueCount(int value) {
    _$overdueCountAtom.reportWrite(value, super.overdueCount, () {
      super.overdueCount = value;
    });
  }

  late final _$createEntryAsyncAction = AsyncAction(
    '_FinancialEntryStore.createEntry',
    context: context,
  );

  @override
  Future<void> createEntry(FinancialEntry entry) {
    return _$createEntryAsyncAction.run(() => super.createEntry(entry));
  }

  late final _$createInstallmentsAsyncAction = AsyncAction(
    '_FinancialEntryStore.createInstallments',
    context: context,
  );

  @override
  Future<void> createInstallments(FinancialEntry baseEntry, int count) {
    return _$createInstallmentsAsyncAction.run(
      () => super.createInstallments(baseEntry, count),
    );
  }

  late final _$updateEntryAsyncAction = AsyncAction(
    '_FinancialEntryStore.updateEntry',
    context: context,
  );

  @override
  Future<void> updateEntry(FinancialEntry entry) {
    return _$updateEntryAsyncAction.run(() => super.updateEntry(entry));
  }

  late final _$deleteEntryAsyncAction = AsyncAction(
    '_FinancialEntryStore.deleteEntry',
    context: context,
  );

  @override
  Future<void> deleteEntry(FinancialEntry entry) {
    return _$deleteEntryAsyncAction.run(() => super.deleteEntry(entry));
  }

  late final _$cancelEntryAsyncAction = AsyncAction(
    '_FinancialEntryStore.cancelEntry',
    context: context,
  );

  @override
  Future<void> cancelEntry(FinancialEntry entry) {
    return _$cancelEntryAsyncAction.run(() => super.cancelEntry(entry));
  }

  late final _$_FinancialEntryStoreActionController = ActionController(
    name: '_FinancialEntryStore',
    context: context,
  );

  @override
  void load({String? direction, String? status}) {
    final _$actionInfo = _$_FinancialEntryStoreActionController.startAction(
      name: '_FinancialEntryStore.load',
    );
    try {
      return super.load(direction: direction, status: status);
    } finally {
      _$_FinancialEntryStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void loadByDueDateRange(DateTime start, DateTime end) {
    final _$actionInfo = _$_FinancialEntryStoreActionController.startAction(
      name: '_FinancialEntryStore.loadByDueDateRange',
    );
    try {
      return super.loadByDueDateRange(start, end);
    } finally {
      _$_FinancialEntryStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void calculateEntryKPIs(List<FinancialEntry?> entries) {
    final _$actionInfo = _$_FinancialEntryStoreActionController.startAction(
      name: '_FinancialEntryStore.calculateEntryKPIs',
    );
    try {
      return super.calculateEntryKPIs(entries);
    } finally {
      _$_FinancialEntryStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
entryList: ${entryList},
monthEntryList: ${monthEntryList},
totalPayable: ${totalPayable},
totalReceivable: ${totalReceivable},
overdueCount: ${overdueCount}
    ''';
  }
}
