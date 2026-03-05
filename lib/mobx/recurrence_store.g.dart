// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recurrence_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$RecurrenceStore on _RecurrenceStore, Store {
  late final _$ruleListAtom = Atom(
    name: '_RecurrenceStore.ruleList',
    context: context,
  );

  @override
  ObservableStream<List<RecurrenceRule?>>? get ruleList {
    _$ruleListAtom.reportRead();
    return super.ruleList;
  }

  @override
  set ruleList(ObservableStream<List<RecurrenceRule?>>? value) {
    _$ruleListAtom.reportWrite(value, super.ruleList, () {
      super.ruleList = value;
    });
  }

  late final _$isLoadingAtom = Atom(
    name: '_RecurrenceStore.isLoading',
    context: context,
  );

  @override
  bool get isLoading {
    _$isLoadingAtom.reportRead();
    return super.isLoading;
  }

  @override
  set isLoading(bool value) {
    _$isLoadingAtom.reportWrite(value, super.isLoading, () {
      super.isLoading = value;
    });
  }

  late final _$saveRuleAsyncAction = AsyncAction(
    '_RecurrenceStore.saveRule',
    context: context,
  );

  @override
  Future<void> saveRule(RecurrenceRule rule) {
    return _$saveRuleAsyncAction.run(() => super.saveRule(rule));
  }

  late final _$deleteRuleAsyncAction = AsyncAction(
    '_RecurrenceStore.deleteRule',
    context: context,
  );

  @override
  Future<void> deleteRule(RecurrenceRule rule) {
    return _$deleteRuleAsyncAction.run(() => super.deleteRule(rule));
  }

  late final _$toggleActiveAsyncAction = AsyncAction(
    '_RecurrenceStore.toggleActive',
    context: context,
  );

  @override
  Future<void> toggleActive(RecurrenceRule rule) {
    return _$toggleActiveAsyncAction.run(() => super.toggleActive(rule));
  }

  late final _$generateOrderFromRuleAsyncAction = AsyncAction(
    '_RecurrenceStore.generateOrderFromRule',
    context: context,
  );

  @override
  Future<Order?> generateOrderFromRule(RecurrenceRule rule) {
    return _$generateOrderFromRuleAsyncAction.run(
      () => super.generateOrderFromRule(rule),
    );
  }

  late final _$checkAndGenerateDueOrdersAsyncAction = AsyncAction(
    '_RecurrenceStore.checkAndGenerateDueOrders',
    context: context,
  );

  @override
  Future<int> checkAndGenerateDueOrders() {
    return _$checkAndGenerateDueOrdersAsyncAction.run(
      () => super.checkAndGenerateDueOrders(),
    );
  }

  late final _$_RecurrenceStoreActionController = ActionController(
    name: '_RecurrenceStore',
    context: context,
  );

  @override
  void loadRules() {
    final _$actionInfo = _$_RecurrenceStoreActionController.startAction(
      name: '_RecurrenceStore.loadRules',
    );
    try {
      return super.loadRules();
    } finally {
      _$_RecurrenceStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void loadActiveRules() {
    final _$actionInfo = _$_RecurrenceStoreActionController.startAction(
      name: '_RecurrenceStore.loadActiveRules',
    );
    try {
      return super.loadActiveRules();
    } finally {
      _$_RecurrenceStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
ruleList: ${ruleList},
isLoading: ${isLoading}
    ''';
  }
}
