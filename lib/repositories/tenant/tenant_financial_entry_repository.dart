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
      FinancialEntry.fromJson(data);

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
  Stream<List<FinancialEntry?>> streamByDueDateRange(
    String companyId,
    DateTime from,
    DateTime to, {
    List<QueryArgs>? extraArgs,
  }) {
    return streamListFromTo(
      companyId,
      'dueDate',
      from,
      to,
      args: [
        QueryArgs('deletedAt', null),
        ...?extraArgs,
      ],
    );
  }
}
