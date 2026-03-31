import 'package:praticos/global.dart';
import 'package:praticos/models/financial_account.dart';
import 'package:praticos/repositories/v2/financial_account_repository_v2.dart';
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
        .fold<double>(0, (sum, a) => sum + (a!.currentBalance ?? 0));
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
}
