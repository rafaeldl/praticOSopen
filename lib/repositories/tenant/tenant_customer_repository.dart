import 'package:praticos/models/customer.dart';
import 'package:praticos/repositories/tenant_repository.dart';
import 'package:praticos/repositories/repository.dart';

/// Repository para Customers usando subcollections por tenant.
///
/// Path: `/companies/{companyId}/customers/{customerId}`
class TenantCustomerRepository extends TenantRepository<Customer?> {
  static const String collectionName = 'customers';

  TenantCustomerRepository() : super(collectionName);

  @override
  Customer fromJson(Map<String, dynamic> data) => Customer.fromJson(data);

  @override
  Map<String, dynamic> toJson(Customer? customer) => customer!.toJson();

  // ═══════════════════════════════════════════════════════════════════
  // Customer-specific methods
  // ═══════════════════════════════════════════════════════════════════

  /// Stream de todos os customers do tenant ordenados por nome.
  Stream<List<Customer?>> streamCustomers(String companyId) {
    return streamQueryList(
      companyId,
      orderBy: [OrderBy('name')],
    );
  }

  /// Busca customers por nome (busca parcial não suportada pelo Firestore).
  Future<List<Customer?>> searchByName(String companyId, String name) async {
    return getQueryList(
      companyId,
      args: [QueryArgs('name', name)],
      orderBy: [OrderBy('name')],
    );
  }

  /// Busca customer por telefone.
  Future<Customer?> getByPhone(String companyId, String phone) async {
    final customers = await getQueryList(
      companyId,
      args: [QueryArgs('phone', phone)],
      limit: 1,
    );
    return customers.isNotEmpty ? customers.first : null;
  }

  /// Busca customer por email.
  Future<Customer?> getByEmail(String companyId, String email) async {
    final customers = await getQueryList(
      companyId,
      args: [QueryArgs('email', email)],
      limit: 1,
    );
    return customers.isNotEmpty ? customers.first : null;
  }
}
