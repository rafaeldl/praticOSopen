import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/financial_account.dart';
import 'package:praticos/models/financial_entry.dart';
import 'package:praticos/models/financial_payment.dart';
import 'package:praticos/models/payment_method.dart';
import 'package:praticos/repositories/v2/financial_payment_repository_v2.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'financial_payment_store.g.dart';

class FinancialPaymentStore = _FinancialPaymentStore
    with _$FinancialPaymentStore;

abstract class _FinancialPaymentStore with Store {
  final FinancialPaymentRepositoryV2 repository =
      FinancialPaymentRepositoryV2();

  @observable
  ObservableStream<List<FinancialPayment?>>? paymentList;

  @observable
  double totalIncome = 0;

  @observable
  double totalExpense = 0;

  @observable
  double todayIncome = 0;

  @observable
  double todayExpense = 0;

  @computed
  double get profit => totalIncome - totalExpense;

  @computed
  double get todayProfit => todayIncome - todayExpense;

  String? companyId;

  _FinancialPaymentStore() {
    SharedPreferences.getInstance().then((value) {
      companyId = value.getString('companyId');
    });
  }

  @action
  void loadPayments(DateTime start, DateTime end) {
    if (companyId == null) return;
    paymentList =
        repository.streamByDateRange(companyId!, start, end).asObservable();
  }

  @action
  void loadKPIs(DateTime start, DateTime end) {
    if (companyId == null) return;
    repository.streamByDateRange(companyId!, start, end).listen((payments) {
      final active = payments
          .where((p) =>
              p != null &&
              p.status == FinancialPaymentStatus.completed &&
              p.deletedAt == null)
          .cast<FinancialPayment>();

      totalIncome = active
          .where((p) => p.type == FinancialPaymentType.income)
          .fold<double>(0, (acc, p) => acc + (p.amount ?? 0));

      totalExpense = active
          .where((p) => p.type == FinancialPaymentType.expense)
          .fold<double>(0, (acc, p) => acc + (p.amount ?? 0));

      // Today KPIs
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      final todayPayments = active.where((p) =>
          p.paymentDate != null &&
          p.paymentDate!.isAfter(todayStart) &&
          p.paymentDate!.isBefore(todayEnd));

      todayIncome = todayPayments
          .where((p) => p.type == FinancialPaymentType.income)
          .fold<double>(0, (acc, p) => acc + (p.amount ?? 0));

      todayExpense = todayPayments
          .where((p) => p.type == FinancialPaymentType.expense)
          .fold<double>(0, (acc, p) => acc + (p.amount ?? 0));
    });
  }

  @action
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
  }) async {
    if (companyId == null) return;

    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    final now = DateTime.now();
    final effectiveDate = paymentDate ?? now;

    // 1. Create payment
    final paymentType = entry.direction == FinancialEntryDirection.payable
        ? FinancialPaymentType.expense
        : FinancialPaymentType.income;

    final paymentRef = db
        .collection('companies')
        .doc(companyId)
        .collection('financialPayments')
        .doc();

    batch.set(paymentRef, {
      'id': paymentRef.id,
      'type': paymentType.name,
      'status': 'completed',
      'amount': amount,
      'discount': discount ?? 0,
      'paymentDate': Timestamp.fromDate(effectiveDate),
      'paymentMethod': method.name,
      'description': description ?? entry.description,
      'notes': notes,
      'entryId': entry.id,
      'accountId': accountId,
      'account': account.toJson(),
      'orderId': entry.orderId,
      'orderNumber': entry.orderNumber,
      'customer': entry.customer?.toJson(),
      'supplier': entry.supplier,
      'category': entry.category,
      'syncSource': null,
      'company': Global.companyAggr?.toJson(),
      'createdAt': Timestamp.fromDate(now),
      'createdBy': Global.userAggr?.toJson(),
      'updatedAt': Timestamp.fromDate(now),
      'updatedBy': Global.userAggr?.toJson(),
    });

    // 2. Update entry
    final entryRef = db
        .collection('companies')
        .doc(companyId)
        .collection('financialEntries')
        .doc(entry.id);

    final newPaidAmount = (entry.paidAmount ?? 0) + amount;
    final newDiscountAmount = (entry.discountAmount ?? 0) + (discount ?? 0);
    final isFullyPaid =
        newPaidAmount + newDiscountAmount >= (entry.amount ?? 0);

    batch.update(entryRef, {
      'paidAmount': FieldValue.increment(amount),
      'discountAmount':
          discount != null && discount > 0 ? FieldValue.increment(discount) : (entry.discountAmount ?? 0),
      'status': isFullyPaid ? 'paid' : 'pending',
      'paidDate': isFullyPaid ? Timestamp.fromDate(effectiveDate) : null,
      'updatedAt': Timestamp.fromDate(now),
      'updatedBy': Global.userAggr?.toJson(),
    });

    // 3. Update account balance
    final accountRef = db
        .collection('companies')
        .doc(companyId)
        .collection('financialAccounts')
        .doc(accountId);

    final balanceChange =
        entry.direction == FinancialEntryDirection.payable ? -amount : amount;
    batch.update(accountRef, {
      'currentBalance': FieldValue.increment(balanceChange),
    });

    await batch.commit();
  }
}
