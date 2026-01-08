import 'package:praticos/models/customer.dart';
import 'package:praticos/repositories/tenant/tenant_customer_repository.dart';
import 'package:praticos/repositories/tenant_repository.dart';
import 'package:praticos/repositories/v2/repository_v2.dart';

/// Repository V2 para Customers usando subcollections por tenant.
///
/// Path: `/companies/{companyId}/customers/{customerId}`
class CustomerRepositoryV2 extends RepositoryV2<Customer?> {
  final TenantCustomerRepository _tenant = TenantCustomerRepository();

  @override
  TenantRepository<Customer?> get tenantRepo => _tenant;

  // ═══════════════════════════════════════════════════════════════════
  // Customer-specific methods
  // ═══════════════════════════════════════════════════════════════════

  /// Stream de todos os customers do tenant ordenados por nome.
  Stream<List<Customer?>> streamCustomers(String companyId) {
    return _tenant.streamCustomers(companyId);
  }

  /// Busca customers por nome.
  Future<List<Customer?>> searchByName(String companyId, String name) async {
    return await _tenant.searchByName(companyId, name);
  }

  /// Busca customer por telefone.
  Future<Customer?> getByPhone(String companyId, String phone) async {
    return await _tenant.getByPhone(companyId, phone);
  }

  /// Busca customer por email.
  Future<Customer?> getByEmail(String companyId, String email) async {
    return await _tenant.getByEmail(companyId, email);
  }
}
