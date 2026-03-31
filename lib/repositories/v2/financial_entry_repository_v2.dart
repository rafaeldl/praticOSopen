import 'package:praticos/models/financial_entry.dart';
import 'package:praticos/repositories/tenant/tenant_financial_entry_repository.dart';
import 'package:praticos/repositories/tenant_repository.dart';
import 'package:praticos/repositories/v2/repository_v2.dart';

/// Repository V2 para FinancialEntries usando subcollections por tenant.
///
/// Path: `/companies/{companyId}/financialEntries/{entryId}`
class FinancialEntryRepositoryV2 extends RepositoryV2<FinancialEntry?> {
  final TenantFinancialEntryRepository _tenant =
      TenantFinancialEntryRepository();

  @override
  TenantRepository<FinancialEntry?> get tenantRepo => _tenant;

  Stream<List<FinancialEntry?>> streamByDirection(
    String companyId,
    String direction, {
    String? status,
  }) {
    return _tenant.streamByDirection(companyId, direction, status: status);
  }

  Stream<List<FinancialEntry?>> streamPending(String companyId) {
    return _tenant.streamPending(companyId);
  }

  Future<List<FinancialEntry?>> getByInstallmentGroup(
    String companyId,
    String groupId,
  ) async {
    return await _tenant.getByInstallmentGroup(companyId, groupId);
  }

  Stream<List<FinancialEntry?>> streamByDueDateRange(
    String companyId,
    DateTime from,
    DateTime to,
  ) {
    return _tenant.streamByDueDateRange(companyId, from, to);
  }
}
