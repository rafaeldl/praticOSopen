// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'financial_account_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$FinancialAccountStore on _FinancialAccountStore, Store {
  Computed<double>? _$totalBalanceComputed;

  @override
  double get totalBalance => (_$totalBalanceComputed ??= Computed<double>(
    () => super.totalBalance,
    name: '_FinancialAccountStore.totalBalance',
  )).value;

  late final _$accountListAtom = Atom(
    name: '_FinancialAccountStore.accountList',
    context: context,
  );

  @override
  ObservableStream<List<FinancialAccount?>>? get accountList {
    _$accountListAtom.reportRead();
    return super.accountList;
  }

  @override
  set accountList(ObservableStream<List<FinancialAccount?>>? value) {
    _$accountListAtom.reportWrite(value, super.accountList, () {
      super.accountList = value;
    });
  }

  late final _$createAccountAsyncAction = AsyncAction(
    '_FinancialAccountStore.createAccount',
    context: context,
  );

  @override
  Future<void> createAccount(FinancialAccount account) {
    return _$createAccountAsyncAction.run(() => super.createAccount(account));
  }

  late final _$updateAccountAsyncAction = AsyncAction(
    '_FinancialAccountStore.updateAccount',
    context: context,
  );

  @override
  Future<void> updateAccount(FinancialAccount account) {
    return _$updateAccountAsyncAction.run(() => super.updateAccount(account));
  }

  late final _$_FinancialAccountStoreActionController = ActionController(
    name: '_FinancialAccountStore',
    context: context,
  );

  @override
  void load() {
    final _$actionInfo = _$_FinancialAccountStoreActionController.startAction(
      name: '_FinancialAccountStore.load',
    );
    try {
      return super.load();
    } finally {
      _$_FinancialAccountStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
accountList: ${accountList},
totalBalance: ${totalBalance}
    ''';
  }
}
