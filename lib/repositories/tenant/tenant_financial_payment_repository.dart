import 'package:praticos/models/financial_payment.dart';
import 'package:praticos/repositories/tenant_repository.dart';
import 'package:praticos/repositories/repository.dart';

/// Repository para FinancialPayments usando subcollections por tenant.
///
/// Path: `/companies/{companyId}/financialPayments/{paymentId}`
class TenantFinancialPaymentRepository
    extends TenantRepository<FinancialPayment?> {
  static const String collectionName = 'financialPayments';

  TenantFinancialPaymentRepository() : super(collectionName);

  @override
  FinancialPayment fromJson(Map<String, dynamic> data) =>
      FinancialPayment.fromJson(data);

  @override
  Map<String, dynamic> toJson(FinancialPayment? payment) =>
      payment!.toJson();

  /// Stream de payments por periodo, ordenados por data desc.
  Stream<List<FinancialPayment?>> streamByDateRange(
    String companyId,
    DateTime from,
    DateTime to,
  ) {
    return streamListFromTo(
      companyId,
      'paymentDate',
      from,
      to,
      args: [QueryArgs('deletedAt', null)],
    );
  }

  /// Stream de payments por conta, ordenados por data desc.
  Stream<List<FinancialPayment?>> streamByAccount(
    String companyId,
    String accountId,
  ) {
    return streamQueryList(
      companyId,
      args: [
        QueryArgs('accountId', accountId),
        QueryArgs('deletedAt', null),
      ],
      orderBy: [OrderBy('paymentDate', descending: true)],
    );
  }

  /// Busca payments por entryId.
  Future<List<FinancialPayment?>> getByEntryId(
    String companyId,
    String entryId,
  ) async {
    return getQueryList(
      companyId,
      args: [
        QueryArgs('entryId', entryId),
        QueryArgs('deletedAt', null),
      ],
      orderBy: [OrderBy('paymentDate', descending: true)],
    );
  }

  /// Busca payments por transferGroupId.
  Future<List<FinancialPayment?>> getByTransferGroup(
    String companyId,
    String transferGroupId,
  ) async {
    return getQueryList(
      companyId,
      args: [
        QueryArgs('transferGroupId', transferGroupId),
        QueryArgs('status', 'completed'),
      ],
    );
  }
}
