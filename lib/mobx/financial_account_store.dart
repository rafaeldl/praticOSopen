import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/financial_account.dart';
import 'package:praticos/models/financial_payment.dart';
import 'package:praticos/repositories/v2/financial_account_repository_v2.dart';
import 'package:praticos/repositories/v2/financial_payment_repository_v2.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'financial_account_store.g.dart';

class FinancialAccountStore = _FinancialAccountStore
    with _$FinancialAccountStore;

abstract class _FinancialAccountStore with Store {
  final FinancialAccountRepositoryV2 repository =
      FinancialAccountRepositoryV2();

  @observable
  ObservableStream<List<FinancialAccount?>>? accountList;

  String? companyId;

  _FinancialAccountStore() {
    SharedPreferences.getInstance().then((value) {
      companyId = value.getString('companyId');
    });
  }

  @computed
  double get totalBalance {
    final accounts = accountList?.value ?? [];
    return accounts
        .where((a) => a != null && (a.active ?? false))
        .fold<double>(0, (acc, a) => acc + (a!.currentBalance ?? 0));
  }

  @action
  void load() {
    if (companyId == null) return;
    accountList = repository.streamActive(companyId!).asObservable();
  }

  @action
  Future<void> createAccount(FinancialAccount account) async {
    if (companyId == null) return;
    account.createdAt = DateTime.now();
    account.createdBy = Global.userAggr;
    account.company = Global.companyAggr;
    account.updatedAt = DateTime.now();
    account.updatedBy = Global.userAggr;
    account.active ??= true;
    account.currency ??= 'BRL';
    account.currentBalance ??= account.initialBalance ?? 0;
    await repository.createItem(companyId!, account);
  }

  @action
  Future<void> updateAccount(FinancialAccount account) async {
    if (companyId == null) return;
    account.updatedAt = DateTime.now();
    account.updatedBy = Global.userAggr;
    await repository.updateItem(companyId!, account);
  }

  @action
  Future<double> calculateRealBalance(String accountId) async {
    if (companyId == null) return 0;

    final paymentRepo = FinancialPaymentRepositoryV2();
    final account = await repository.getSingle(companyId!, accountId);
    final payments =
        await paymentRepo.streamByAccount(companyId!, accountId).first;

    double balance = account?.initialBalance ?? 0;
    for (final p in payments) {
      if (p == null || p.deletedAt != null) continue;
      if (p.status == FinancialPaymentStatus.reversed) continue;
      if (p.type == FinancialPaymentType.income) balance += p.amount ?? 0;
      if (p.type == FinancialPaymentType.expense) balance -= p.amount ?? 0;
      if (p.type == FinancialPaymentType.transfer) {
        if (p.transferDirection == 'out') balance -= p.amount ?? 0;
        if (p.transferDirection == 'in') balance += p.amount ?? 0;
      }
    }
    return balance;
  }

  @action
  Future<void> reconcileBalance(
      String accountId, double realBalance) async {
    if (companyId == null) return;
    final db = FirebaseFirestore.instance;
    await db
        .collection('companies')
        .doc(companyId)
        .collection('financialAccounts')
        .doc(accountId)
        .update({
      'currentBalance': realBalance,
      'lastReconciledAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      'updatedBy': Global.userAggr?.toJson(),
    });
  }
}
