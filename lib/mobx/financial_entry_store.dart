import 'package:praticos/global.dart';
import 'package:praticos/models/financial_entry.dart';
import 'package:praticos/repositories/v2/financial_entry_repository_v2.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';
part 'financial_entry_store.g.dart';

class FinancialEntryStore = _FinancialEntryStore with _$FinancialEntryStore;

abstract class _FinancialEntryStore with Store {
  final FinancialEntryRepositoryV2 repository = FinancialEntryRepositoryV2();

  @observable
  ObservableStream<List<FinancialEntry?>>? entryList;

  String? companyId;

  _FinancialEntryStore() {
    SharedPreferences.getInstance().then((value) {
      companyId = value.getString('companyId');
    });
  }

  @action
  void load({String? direction, String? status}) {
    if (companyId == null) return;
    if (direction != null) {
      entryList = repository
          .streamByDirection(companyId!, direction, status: status)
          .asObservable();
    } else {
      entryList = repository.streamPending(companyId!).asObservable();
    }
  }

  @action
  Future<void> createEntry(FinancialEntry entry) async {
    if (companyId == null) return;
    _applyAuditFields(entry);
    entry.status ??= FinancialEntryStatus.pending;
    entry.paidAmount ??= 0;
    entry.discountAmount ??= 0;
    entry.competenceDate ??= entry.dueDate;
    await repository.createItem(companyId!, entry);
  }

  @action
  Future<void> createInstallments(FinancialEntry baseEntry, int count) async {
    if (companyId == null) return;
    final groupId = DateTime.now().millisecondsSinceEpoch.toString();
    final totalAmount = baseEntry.amount ?? 0;
    final installmentAmount =
        double.parse((totalAmount / count).toStringAsFixed(2));
    final baseDate = baseEntry.dueDate ?? DateTime.now();

    for (var i = 1; i <= count; i++) {
      final entry = FinancialEntry()
        ..direction = baseEntry.direction
        ..description = '${baseEntry.description} $i/$count'
        ..amount = installmentAmount
        ..dueDate = DateTime(baseDate.year, baseDate.month + (i - 1), baseDate.day)
        ..competenceDate =
            DateTime(baseDate.year, baseDate.month + (i - 1), baseDate.day)
        ..category = baseEntry.category
        ..accountId = baseEntry.accountId
        ..account = baseEntry.account
        ..supplier = baseEntry.supplier
        ..customer = baseEntry.customer
        ..notes = baseEntry.notes
        ..installmentGroupId = groupId
        ..installmentNumber = i
        ..installmentTotal = count
        ..status = FinancialEntryStatus.pending
        ..paidAmount = 0
        ..discountAmount = 0;
      _applyAuditFields(entry);
      await repository.createItem(companyId!, entry);
    }
  }

  @action
  Future<void> updateEntry(FinancialEntry entry) async {
    if (companyId == null) return;
    entry.updatedAt = DateTime.now();
    entry.updatedBy = Global.userAggr;
    await repository.updateItem(companyId!, entry);
  }

  @action
  Future<void> deleteEntry(FinancialEntry entry) async {
    if (companyId == null) return;
    entry.deletedAt = DateTime.now();
    entry.deletedBy = Global.userAggr;
    await repository.updateItem(companyId!, entry);
  }

  Future<List<FinancialEntry?>> getInstallmentGroup(String groupId) async {
    if (companyId == null) return [];
    return repository.getByInstallmentGroup(companyId!, groupId);
  }

  void _applyAuditFields(FinancialEntry entry) {
    entry.createdAt = DateTime.now();
    entry.createdBy = Global.userAggr;
    entry.company = Global.companyAggr;
    entry.updatedAt = DateTime.now();
    entry.updatedBy = Global.userAggr;
  }
}
