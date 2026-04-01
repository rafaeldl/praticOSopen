import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/financial_entry.dart';
import 'package:praticos/repositories/tenant_repository.dart';
import 'package:praticos/repositories/repository.dart';

/// Repository para FinancialEntries usando subcollections por tenant.
///
/// Path: `/companies/{companyId}/financialEntries/{entryId}`
class TenantFinancialEntryRepository
    extends TenantRepository<FinancialEntry?> {
  static const String collectionName = 'financialEntries';

  TenantFinancialEntryRepository() : super(collectionName);

  @override
  FinancialEntry fromJson(Map<String, dynamic> data) =>
      FinancialEntry.fromJson(_convertTimestampsToStrings(data));

  @override
  Map<String, dynamic> toJson(FinancialEntry? entry) => entry!.toJson();

  /// Stream de entries por direction e status, ordenadas por vencimento.
  Stream<List<FinancialEntry?>> streamByDirection(
    String companyId,
    String direction, {
    String? status,
  }) {
    final args = <QueryArgs>[
      QueryArgs('direction', direction),
      QueryArgs('deletedAt', null),
    ];
    if (status != null) {
      args.add(QueryArgs('status', status));
    }
    return streamQueryList(
      companyId,
      args: args,
      orderBy: [OrderBy('dueDate')],
    );
  }

  /// Stream de entries pendentes ordenadas por vencimento.
  Stream<List<FinancialEntry?>> streamPending(String companyId) {
    return streamQueryList(
      companyId,
      args: [
        QueryArgs('status', 'pending'),
        QueryArgs('deletedAt', null),
      ],
      orderBy: [OrderBy('dueDate')],
    );
  }

  /// Busca entries por installmentGroupId ordenadas por numero.
  Future<List<FinancialEntry?>> getByInstallmentGroup(
    String companyId,
    String groupId,
  ) async {
    return getQueryList(
      companyId,
      args: [
        QueryArgs('installmentGroupId', groupId),
        QueryArgs('deletedAt', null),
      ],
      orderBy: [OrderBy('installmentNumber')],
    );
  }

  /// Stream de entries por periodo de vencimento.
  /// Uses direct Firestore query with Timestamp values to ensure
  /// correct range comparison regardless of stored date format.
  Stream<List<FinancialEntry?>> streamByDueDateRange(
    String companyId,
    DateTime from,
    DateTime to, {
    List<QueryArgs>? extraArgs,
  }) {
    var query = FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection(collectionName)
        .where('deletedAt', isEqualTo: null)
        .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('dueDate', isLessThanOrEqualTo: Timestamp.fromDate(to))
        .orderBy('dueDate');

    if (extraArgs != null) {
      for (final arg in extraArgs) {
        query = query.where(arg.key, isEqualTo: arg.value);
      }
    }

    return query.snapshots().map(
          (snap) => snap.docs.map((doc) {
            final data = {...doc.data(), 'id': doc.id};
            return FinancialEntry.fromJson(_convertTimestampsToStrings(data));
          }).toList(),
        );
  }

  /// Converts Firestore Timestamps back to ISO strings so that the
  /// generated fromJson (which expects String) works correctly.
  Map<String, dynamic> _convertTimestampsToStrings(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);
    const dateFields = [
      'dueDate',
      'competenceDate',
      'paidDate',
      'createdAt',
      'updatedAt',
      'deletedAt',
    ];
    for (final field in dateFields) {
      final value = result[field];
      if (value is Timestamp) {
        result[field] = value.toDate().toIso8601String();
      }
    }
    // Handle nested recurrence date fields
    if (result['recurrence'] is Map) {
      final rec = Map<String, dynamic>.from(result['recurrence'] as Map);
      const recDateFields = ['endDate', 'nextDueDate', 'lastGeneratedDate'];
      for (final field in recDateFields) {
        final value = rec[field];
        if (value is Timestamp) {
          rec[field] = value.toDate().toIso8601String();
        }
      }
      result['recurrence'] = rec;
    }
    // Handle nested createdBy/updatedBy/deletedBy
    for (final nested in ['createdBy', 'updatedBy', 'deletedBy']) {
      if (result[nested] is Map) {
        final map = Map<String, dynamic>.from(result[nested] as Map);
        for (final field in ['createdAt', 'updatedAt']) {
          if (map[field] is Timestamp) {
            map[field] = (map[field] as Timestamp).toDate().toIso8601String();
          }
        }
        result[nested] = map;
      }
    }
    return result;
  }

  /// Converts ISO string date fields to Firestore Timestamps so that
  /// range queries (startAfter/endAt) work correctly.
  Map<String, dynamic> _convertDatesToTimestamps(Map<String, dynamic> json) {
    const dateFields = [
      'dueDate',
      'competenceDate',
      'paidDate',
      'createdAt',
      'updatedAt',
      'deletedAt',
    ];
    for (final field in dateFields) {
      final value = json[field];
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) {
          json[field] = Timestamp.fromDate(parsed);
        }
      }
    }
    // Handle nested recurrence date fields
    if (json['recurrence'] is Map<String, dynamic>) {
      final rec = json['recurrence'] as Map<String, dynamic>;
      const recDateFields = ['endDate', 'nextDueDate', 'lastGeneratedDate'];
      for (final field in recDateFields) {
        final value = rec[field];
        if (value is String) {
          final parsed = DateTime.tryParse(value);
          if (parsed != null) {
            rec[field] = Timestamp.fromDate(parsed);
          }
        }
      }
    }
    return json;
  }

  @override
  Future<void> createItem(String companyId, FinancialEntry? item,
      {String? id}) async {
    final json = _convertDatesToTimestamps(toJson(item));
    json.remove('number');
    if (item?.id != null) {
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection(collectionName)
          .doc(item!.id)
          .set(json, SetOptions(merge: true));
    } else if (id != null) {
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection(collectionName)
          .doc(id)
          .set(json, SetOptions(merge: true));
      item?.id = id;
    } else {
      final docRef = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection(collectionName)
          .add(json);
      item?.id = docRef.id;
    }
  }

  @override
  Future<void> updateItem(String companyId, FinancialEntry? item) {
    final json = _convertDatesToTimestamps(toJson(item));
    return FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection(collectionName)
        .doc(item?.id)
        .set(json, SetOptions(merge: true));
  }
}
