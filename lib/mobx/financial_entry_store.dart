import 'package:praticos/global.dart';
import 'package:praticos/models/financial_entry.dart';
import 'package:praticos/repositories/v2/financial_entry_repository_v2.dart';
import 'package:praticos/services/segment_config_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  /// Syncs a payment from the financial module back to the linked OS.
  /// Called after payEntry when the entry has an orderId.
  Future<void> syncOrderPayment(FinancialEntry entry, double amount) async {
    if (companyId == null) return;
    if (!SegmentConfigService().useFinancialManagement) return;
    if (entry.orderId == null) return;
    if (entry.syncSource == 'order') {
      entry.syncSource = null;
      await repository.updateItem(companyId!, entry);
      return;
    }

    // Update the OS with the payment
    final db = FirebaseFirestore.instance;
    final orderRef = db.collection('companies').doc(companyId).collection('orders').doc(entry.orderId);
    final orderDoc = await orderRef.get();
    if (!orderDoc.exists) return;

    final now = DateTime.now();
    final txnId = now.millisecondsSinceEpoch.toString();

    // Add PaymentTransaction to the OS
    final transaction = {
      'id': txnId,
      'type': 'payment',
      'amount': amount,
      'description': 'Pagamento via financeiro',
      'createdAt': now.toIso8601String(),
      'createdBy': Global.userAggr?.toJson(),
    };

    final orderData = orderDoc.data()!;
    final transactions = List<Map<String, dynamic>>.from(orderData['transactions'] ?? []);
    transactions.add(transaction);

    final currentPaid = (orderData['paidAmount'] as num?)?.toDouble() ?? 0;
    final newPaid = currentPaid + amount;
    final total = (orderData['total'] as num?)?.toDouble() ?? 0;
    final isFullyPaid = newPaid >= total;

    await orderRef.update({
      'transactions': transactions,
      'paidAmount': newPaid,
      'payment': isFullyPaid ? 'paid' : 'unpaid',
      'syncSource': 'financial',
      'updatedAt': Timestamp.fromDate(now),
      'updatedBy': Global.userAggr?.toJson(),
    });
  }

  /// Recalculates the paidAmount on a FinancialEntry by summing all active
  /// (completed, non-deleted) payments linked to that entry. Uses a Firestore
  /// transaction for atomic read+write of the entry document.
  Future<void> recalculatePaidAmount(String entryId) async {
    if (companyId == null) return;
    final db = FirebaseFirestore.instance;
    final entryRef = db
        .collection('companies')
        .doc(companyId)
        .collection('financialEntries')
        .doc(entryId);

    // Read payments outside transaction (queries not supported in transactions)
    final paymentsSnapshot = await db
        .collection('companies')
        .doc(companyId)
        .collection('financialPayments')
        .where('entryId', isEqualTo: entryId)
        .get();

    double activePaidAmount = 0;
    for (final doc in paymentsSnapshot.docs) {
      final data = doc.data();
      if (data['status'] == 'completed' && data['deletedAt'] == null) {
        activePaidAmount += (data['amount'] as num?)?.toDouble() ?? 0;
      }
    }

    // Atomic update of entry
    await db.runTransaction((transaction) async {
      final entryDoc = await transaction.get(entryRef);
      if (!entryDoc.exists) return;

      final entryData = entryDoc.data()!;
      final entryAmount = (entryData['amount'] as num?)?.toDouble() ?? 0;
      final discountAmount =
          (entryData['discountAmount'] as num?)?.toDouble() ?? 0;
      final isFullyPaid = activePaidAmount + discountAmount >= entryAmount;

      transaction.update(entryRef, {
        'paidAmount': activePaidAmount,
        'status': isFullyPaid ? 'paid' : 'pending',
        'paidDate':
            isFullyPaid ? Timestamp.fromDate(DateTime.now()) : null,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
        'updatedBy': Global.userAggr?.toJson(),
      });
    });
  }

  /// Processes all active recurrences, generating pending entries for any
  /// missed due dates (catch-up). Called fire-and-forget when the financial
  /// statement screen loads.
  Future<void> processRecurrences() async {
    if (companyId == null) return;

    // Load pending entries and filter for active recurrences client-side
    final allEntries = await repository.streamPending(companyId!).first;
    final recurring = allEntries
        .where((e) =>
            e != null &&
            e.recurrence != null &&
            (e.recurrence!.active ?? false) &&
            e.recurrence!.nextDueDate != null &&
            !e.recurrence!.nextDueDate!.isAfter(DateTime.now()))
        .cast<FinancialEntry>()
        .toList();

    for (final entry in recurring) {
      await _processRecurrence(entry);
    }
  }

  Future<void> _processRecurrence(FinancialEntry entry) async {
    if (companyId == null) return;
    var nextDueDate = entry.recurrence!.nextDueDate!;
    final now = DateTime.now();
    final endDate = entry.recurrence!.endDate;

    while (!nextDueDate.isAfter(now)) {
      // Check if endDate is reached before generating
      if (endDate != null && nextDueDate.isAfter(endDate)) {
        entry.recurrence!.active = false;
        break;
      }

      // Generate new entry with dueDate = nextDueDate (normal, no recurrence)
      final newEntry = FinancialEntry()
        ..direction = entry.direction
        ..status = FinancialEntryStatus.pending
        ..description = entry.description
        ..amount = entry.amount
        ..dueDate = nextDueDate
        ..competenceDate = nextDueDate
        ..paidAmount = 0
        ..discountAmount = 0
        ..category = entry.category
        ..accountId = entry.accountId
        ..account = entry.account
        ..supplier = entry.supplier
        ..customer = entry.customer;
      _applyAuditFields(newEntry);
      await repository.createItem(companyId!, newEntry);

      // Advance to next due date
      nextDueDate = _calculateNextDueDate(
        nextDueDate,
        entry.recurrence!.frequency ?? 'monthly',
        entry.recurrence!.interval ?? 1,
      );
    }

    // Check if the next due date exceeds endDate => deactivate
    if (endDate != null && nextDueDate.isAfter(endDate)) {
      entry.recurrence!.active = false;
    }

    // Update the original entry with new nextDueDate and lastGeneratedDate
    entry.recurrence!.lastGeneratedDate = DateTime.now();
    entry.recurrence!.nextDueDate = nextDueDate;
    entry.updatedAt = DateTime.now();
    entry.updatedBy = Global.userAggr;
    await repository.updateItem(companyId!, entry);
  }

  DateTime _calculateNextDueDate(
      DateTime current, String frequency, int interval) {
    switch (frequency) {
      case 'daily':
        return current.add(Duration(days: interval));
      case 'weekly':
        return current.add(Duration(days: 7 * interval));
      case 'monthly':
        return DateTime(current.year, current.month + interval, current.day);
      case 'yearly':
        return DateTime(current.year + interval, current.month, current.day);
      default:
        return DateTime(current.year, current.month + interval, current.day);
    }
  }

  void _applyAuditFields(FinancialEntry entry) {
    entry.createdAt = DateTime.now();
    entry.createdBy = Global.userAggr;
    entry.company = Global.companyAggr;
    entry.updatedAt = DateTime.now();
    entry.updatedBy = Global.userAggr;
  }
}
