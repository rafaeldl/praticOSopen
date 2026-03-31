import 'package:praticos/models/financial_payment.dart';
import 'package:praticos/repositories/tenant/tenant_financial_payment_repository.dart';
import 'package:praticos/repositories/tenant_repository.dart';
import 'package:praticos/repositories/v2/repository_v2.dart';

/// Repository V2 para FinancialPayments usando subcollections por tenant.
///
/// Path: `/companies/{companyId}/financialPayments/{paymentId}`
class FinancialPaymentRepositoryV2 extends RepositoryV2<FinancialPayment?> {
  final TenantFinancialPaymentRepository _tenant =
      TenantFinancialPaymentRepository();

  @override
  TenantRepository<FinancialPayment?> get tenantRepo => _tenant;

  Stream<List<FinancialPayment?>> streamByDateRange(
    String companyId,
    DateTime from,
    DateTime to,
  ) {
    return _tenant.streamByDateRange(companyId, from, to);
  }

  Stream<List<FinancialPayment?>> streamByAccount(
    String companyId,
    String accountId,
  ) {
    return _tenant.streamByAccount(companyId, accountId);
  }

  Future<List<FinancialPayment?>> getByEntryId(
    String companyId,
    String entryId,
  ) async {
    return await _tenant.getByEntryId(companyId, entryId);
  }

  Future<List<FinancialPayment?>> getByTransferGroup(
    String companyId,
    String transferGroupId,
  ) async {
    return await _tenant.getByTransferGroup(companyId, transferGroupId);
  }
}
