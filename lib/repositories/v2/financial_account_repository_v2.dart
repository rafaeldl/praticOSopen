import 'package:praticos/models/financial_account.dart';
import 'package:praticos/repositories/tenant/tenant_financial_account_repository.dart';
import 'package:praticos/repositories/tenant_repository.dart';
import 'package:praticos/repositories/v2/repository_v2.dart';

/// Repository V2 para FinancialAccounts usando subcollections por tenant.
///
/// Path: `/companies/{companyId}/financialAccounts/{accountId}`
class FinancialAccountRepositoryV2 extends RepositoryV2<FinancialAccount?> {
  final TenantFinancialAccountRepository _tenant =
      TenantFinancialAccountRepository();

  @override
  TenantRepository<FinancialAccount?> get tenantRepo => _tenant;

  Stream<List<FinancialAccount?>> streamActive(String companyId) {
    return _tenant.streamActive(companyId);
  }

  Stream<List<FinancialAccount?>> streamAll(String companyId) {
    return _tenant.streamAll(companyId);
  }
}
