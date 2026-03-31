import 'package:praticos/models/financial_account.dart';
import 'package:praticos/repositories/tenant_repository.dart';
import 'package:praticos/repositories/repository.dart';

/// Repository para FinancialAccounts usando subcollections por tenant.
///
/// Path: `/companies/{companyId}/financialAccounts/{accountId}`
class TenantFinancialAccountRepository
    extends TenantRepository<FinancialAccount?> {
  static const String collectionName = 'financialAccounts';

  TenantFinancialAccountRepository() : super(collectionName);

  @override
  FinancialAccount fromJson(Map<String, dynamic> data) =>
      FinancialAccount.fromJson(data);

  @override
  Map<String, dynamic> toJson(FinancialAccount? account) =>
      account!.toJson();

  /// Stream de contas ativas ordenadas por nome.
  Stream<List<FinancialAccount?>> streamActive(String companyId) {
    return streamQueryList(
      companyId,
      args: [QueryArgs('active', true)],
      orderBy: [OrderBy('name')],
    );
  }

  /// Stream de todas as contas ordenadas por nome.
  Stream<List<FinancialAccount?>> streamAll(String companyId) {
    return streamQueryList(
      companyId,
      orderBy: [OrderBy('name')],
    );
  }
}
