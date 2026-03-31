// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'financial_payment_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$FinancialPaymentStore on _FinancialPaymentStore, Store {
  Computed<double>? _$profitComputed;

  @override
  double get profit => (_$profitComputed ??= Computed<double>(
    () => super.profit,
    name: '_FinancialPaymentStore.profit',
  )).value;
  Computed<double>? _$todayProfitComputed;

  @override
  double get todayProfit => (_$todayProfitComputed ??= Computed<double>(
    () => super.todayProfit,
    name: '_FinancialPaymentStore.todayProfit',
  )).value;

  late final _$paymentListAtom = Atom(
    name: '_FinancialPaymentStore.paymentList',
    context: context,
  );

  @override
  ObservableStream<List<FinancialPayment?>>? get paymentList {
    _$paymentListAtom.reportRead();
    return super.paymentList;
  }

  @override
  set paymentList(ObservableStream<List<FinancialPayment?>>? value) {
    _$paymentListAtom.reportWrite(value, super.paymentList, () {
      super.paymentList = value;
    });
  }

  late final _$totalIncomeAtom = Atom(
    name: '_FinancialPaymentStore.totalIncome',
    context: context,
  );

  @override
  double get totalIncome {
    _$totalIncomeAtom.reportRead();
    return super.totalIncome;
  }

  @override
  set totalIncome(double value) {
    _$totalIncomeAtom.reportWrite(value, super.totalIncome, () {
      super.totalIncome = value;
    });
  }

  late final _$totalExpenseAtom = Atom(
    name: '_FinancialPaymentStore.totalExpense',
    context: context,
  );

  @override
  double get totalExpense {
    _$totalExpenseAtom.reportRead();
    return super.totalExpense;
  }

  @override
  set totalExpense(double value) {
    _$totalExpenseAtom.reportWrite(value, super.totalExpense, () {
      super.totalExpense = value;
    });
  }

  late final _$todayIncomeAtom = Atom(
    name: '_FinancialPaymentStore.todayIncome',
    context: context,
  );

  @override
  double get todayIncome {
    _$todayIncomeAtom.reportRead();
    return super.todayIncome;
  }

  @override
  set todayIncome(double value) {
    _$todayIncomeAtom.reportWrite(value, super.todayIncome, () {
      super.todayIncome = value;
    });
  }

  late final _$todayExpenseAtom = Atom(
    name: '_FinancialPaymentStore.todayExpense',
    context: context,
  );

  @override
  double get todayExpense {
    _$todayExpenseAtom.reportRead();
    return super.todayExpense;
  }

  @override
  set todayExpense(double value) {
    _$todayExpenseAtom.reportWrite(value, super.todayExpense, () {
      super.todayExpense = value;
    });
  }

  late final _$payEntryAsyncAction = AsyncAction(
    '_FinancialPaymentStore.payEntry',
    context: context,
  );

  @override
  Future<void> payEntry(
    FinancialEntry entry, {
    required double amount,
    required String accountId,
    required FinancialAccountAggr account,
    required PaymentMethod method,
    DateTime? paymentDate,
    double? discount,
    String? description,
    String? notes,
  }) {
    return _$payEntryAsyncAction.run(
      () => super.payEntry(
        entry,
        amount: amount,
        accountId: accountId,
        account: account,
        method: method,
        paymentDate: paymentDate,
        discount: discount,
        description: description,
        notes: notes,
      ),
    );
  }

  late final _$transferAsyncAction = AsyncAction(
    '_FinancialPaymentStore.transfer',
    context: context,
  );

  @override
  Future<void> transfer({
    required String fromAccountId,
    required FinancialAccountAggr fromAccount,
    required String toAccountId,
    required FinancialAccountAggr toAccount,
    required double amount,
    String? description,
  }) {
    return _$transferAsyncAction.run(
      () => super.transfer(
        fromAccountId: fromAccountId,
        fromAccount: fromAccount,
        toAccountId: toAccountId,
        toAccount: toAccount,
        amount: amount,
        description: description,
      ),
    );
  }

  late final _$_FinancialPaymentStoreActionController = ActionController(
    name: '_FinancialPaymentStore',
    context: context,
  );

  @override
  void loadPayments(DateTime start, DateTime end) {
    final _$actionInfo = _$_FinancialPaymentStoreActionController.startAction(
      name: '_FinancialPaymentStore.loadPayments',
    );
    try {
      return super.loadPayments(start, end);
    } finally {
      _$_FinancialPaymentStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void loadKPIs(DateTime start, DateTime end) {
    final _$actionInfo = _$_FinancialPaymentStoreActionController.startAction(
      name: '_FinancialPaymentStore.loadKPIs',
    );
    try {
      return super.loadKPIs(start, end);
    } finally {
      _$_FinancialPaymentStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
paymentList: ${paymentList},
totalIncome: ${totalIncome},
totalExpense: ${totalExpense},
todayIncome: ${todayIncome},
todayExpense: ${todayExpense},
profit: ${profit},
todayProfit: ${todayProfit}
    ''';
  }
}
