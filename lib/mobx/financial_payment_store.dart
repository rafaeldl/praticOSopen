import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/financial_account.dart';
import 'package:praticos/models/financial_entry.dart';
import 'package:praticos/models/financial_payment.dart';
import 'package:praticos/models/payment_method.dart';
import 'package:praticos/repositories/v2/financial_payment_repository_v2.dart';
import 'package:praticos/mobx/financial_entry_store.dart';
import 'package:praticos/utils/financial_utils.dart';
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
      final kpis = FinancialUtils.computeKPIs(payments);
      totalIncome = kpis.totalIncome;
      totalExpense = kpis.totalExpense;
      todayIncome = kpis.todayIncome;
      todayExpense = kpis.todayExpense;
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

  @action
  Future<void> transfer({
    required String fromAccountId,
    required FinancialAccountAggr fromAccount,
    required String toAccountId,
    required FinancialAccountAggr toAccount,
    required double amount,
    String? description,
  }) async {
    if (companyId == null) return;

    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    final now = DateTime.now();
    final groupId = now.millisecondsSinceEpoch.toString();

    final paymentsCol = db
        .collection('companies')
        .doc(companyId)
        .collection('financialPayments');

    final desc = description ??
        'Transfer ${fromAccount.name} \u2192 ${toAccount.name}';

    // Payment 1: outgoing from source
    final p1Ref = paymentsCol.doc();
    batch.set(p1Ref, {
      'id': p1Ref.id,
      'type': 'transfer',
      'status': 'completed',
      'amount': amount,
      'paymentDate': Timestamp.fromDate(now),
      'description': desc,
      'accountId': fromAccountId,
      'account': fromAccount.toJson(),
      'targetAccountId': toAccountId,
      'targetAccount': toAccount.toJson(),
      'transferGroupId': groupId,
      'transferDirection': 'out',
      'company': Global.companyAggr?.toJson(),
      'createdAt': Timestamp.fromDate(now),
      'createdBy': Global.userAggr?.toJson(),
      'updatedAt': Timestamp.fromDate(now),
      'updatedBy': Global.userAggr?.toJson(),
    });

    // Payment 2: incoming to destination
    final p2Ref = paymentsCol.doc();
    batch.set(p2Ref, {
      'id': p2Ref.id,
      'type': 'transfer',
      'status': 'completed',
      'amount': amount,
      'paymentDate': Timestamp.fromDate(now),
      'description': desc,
      'accountId': toAccountId,
      'account': toAccount.toJson(),
      'targetAccountId': fromAccountId,
      'targetAccount': fromAccount.toJson(),
      'transferGroupId': groupId,
      'transferDirection': 'in',
      'company': Global.companyAggr?.toJson(),
      'createdAt': Timestamp.fromDate(now),
      'createdBy': Global.userAggr?.toJson(),
      'updatedAt': Timestamp.fromDate(now),
      'updatedBy': Global.userAggr?.toJson(),
    });

    // Update balances
    final accountsCol = db
        .collection('companies')
        .doc(companyId)
        .collection('financialAccounts');
    batch.update(accountsCol.doc(fromAccountId), {
      'currentBalance': FieldValue.increment(-amount),
    });
    batch.update(accountsCol.doc(toAccountId), {
      'currentBalance': FieldValue.increment(amount),
    });

    await batch.commit();
  }

  /// Reverses a single payment (income or expense) atomically.
  ///
  /// Creates a reversal payment document, marks the original as reversed,
  /// and reverts the account balance. If the original is linked to an entry,
  /// recalculates the entry's paidAmount.
  @action
  Future<void> reversePayment(
      FinancialPayment original, String reason) async {
    if (companyId == null) return;

    // Guard: cannot reverse an already-reversed payment
    if (original.status == FinancialPaymentStatus.reversed) return;

    // Guard: cannot reverse a reversal payment itself
    if (original.reversedPaymentId != null) return;

    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    final now = DateTime.now();

    final paymentsCol = db
        .collection('companies')
        .doc(companyId)
        .collection('financialPayments');

    // 1. Create reversal payment
    final reversalRef = paymentsCol.doc();
    batch.set(reversalRef, {
      'id': reversalRef.id,
      'type': original.type?.name,
      'status': 'completed',
      'amount': original.amount,
      'paymentDate': Timestamp.fromDate(now),
      'description': 'Estorno: ${original.description}',
      'reversedPaymentId': original.id,
      'reversalReason': reason,
      'entryId': original.entryId,
      'accountId': original.accountId,
      'account': original.account?.toJson(),
      'orderId': original.orderId,
      'orderNumber': original.orderNumber,
      'customer': original.customer?.toJson(),
      'supplier': original.supplier,
      'category': original.category,
      'syncSource': null,
      'company': Global.companyAggr?.toJson(),
      'createdAt': Timestamp.fromDate(now),
      'createdBy': Global.userAggr?.toJson(),
      'updatedAt': Timestamp.fromDate(now),
      'updatedBy': Global.userAggr?.toJson(),
    });

    // 2. Mark original as reversed
    final originalRef = paymentsCol.doc(original.id);
    batch.update(originalRef, {
      'status': 'reversed',
      'reversedByPaymentId': reversalRef.id,
      'reversedAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      'updatedBy': Global.userAggr?.toJson(),
    });

    // 3. Revert account balance
    if (original.accountId != null) {
      final accountRef = db
          .collection('companies')
          .doc(companyId)
          .collection('financialAccounts')
          .doc(original.accountId);

      // Expense reversal gives money back (+), income reversal takes money back (-)
      final balanceRevert = original.type == FinancialPaymentType.expense
          ? (original.amount ?? 0)
          : -(original.amount ?? 0);
      batch.update(accountRef, {
        'currentBalance': FieldValue.increment(balanceRevert),
      });
    }

    await batch.commit();

    // 4. Recalculate entry paidAmount if linked
    if (original.entryId != null) {
      final entryStore = FinancialEntryStore();
      // Ensure companyId is set (avoid waiting for SharedPreferences)
      entryStore.companyId = companyId;
      await entryStore.recalculatePaidAmount(original.entryId!);
    }
  }

  /// Reverses a transfer (both legs) atomically.
  ///
  /// Fetches both payments by transferGroupId, creates reversal payments
  /// with flipped directions, marks originals as reversed, and reverts
  /// both account balances in a single WriteBatch.
  @action
  Future<void> reverseTransfer(
      FinancialPayment original, String reason) async {
    if (companyId == null) return;
    if (original.transferGroupId == null) return;

    // Guard: cannot reverse an already-reversed payment
    if (original.status == FinancialPaymentStatus.reversed) return;

    // Guard: cannot reverse a reversal payment itself
    if (original.reversedPaymentId != null) return;

    // Get both payments in the transfer group
    final groupPayments = await repository.getByTransferGroup(
        companyId!, original.transferGroupId!);

    if (groupPayments.isEmpty) return;

    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    final now = DateTime.now();
    final newGroupId = now.millisecondsSinceEpoch.toString();

    final paymentsCol = db
        .collection('companies')
        .doc(companyId)
        .collection('financialPayments');

    final accountsCol = db
        .collection('companies')
        .doc(companyId)
        .collection('financialAccounts');

    for (final payment in groupPayments) {
      if (payment == null) continue;
      if (payment.status == FinancialPaymentStatus.reversed) continue;

      // Flip transfer direction for the reversal
      final originalDirection = payment.transferDirection;
      final reversalDirection =
          originalDirection == 'out' ? 'in' : 'out';

      // 1. Create reversal payment
      final reversalRef = paymentsCol.doc();
      batch.set(reversalRef, {
        'id': reversalRef.id,
        'type': 'transfer',
        'status': 'completed',
        'amount': payment.amount,
        'paymentDate': Timestamp.fromDate(now),
        'description': 'Estorno: ${payment.description}',
        'reversedPaymentId': payment.id,
        'reversalReason': reason,
        'accountId': payment.accountId,
        'account': payment.account?.toJson(),
        'targetAccountId': payment.targetAccountId,
        'targetAccount': payment.targetAccount?.toJson(),
        'transferGroupId': newGroupId,
        'transferDirection': reversalDirection,
        'syncSource': null,
        'company': Global.companyAggr?.toJson(),
        'createdAt': Timestamp.fromDate(now),
        'createdBy': Global.userAggr?.toJson(),
        'updatedAt': Timestamp.fromDate(now),
        'updatedBy': Global.userAggr?.toJson(),
      });

      // 2. Mark original as reversed
      final originalRef = paymentsCol.doc(payment.id);
      batch.update(originalRef, {
        'status': 'reversed',
        'reversedByPaymentId': reversalRef.id,
        'reversedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'updatedBy': Global.userAggr?.toJson(),
      });

      // 3. Revert account balance
      if (payment.accountId != null) {
        final accountRef = accountsCol.doc(payment.accountId);
        // 'out' direction originally decremented balance, so revert with +
        // 'in' direction originally incremented balance, so revert with -
        final balanceRevert = originalDirection == 'out'
            ? (payment.amount ?? 0)
            : -(payment.amount ?? 0);
        batch.update(accountRef, {
          'currentBalance': FieldValue.increment(balanceRevert),
        });
      }
    }

    await batch.commit();
  }
}
