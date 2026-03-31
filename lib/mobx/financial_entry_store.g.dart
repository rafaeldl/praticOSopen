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
  String toString() {
    return '''
entryList: ${entryList}
    ''';
  }
}
