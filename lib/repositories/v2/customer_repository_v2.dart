import 'package:praticos/config/feature_flags.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/repositories/customer_repository.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/repositories/tenant/tenant_customer_repository.dart';
import 'package:praticos/repositories/tenant_repository.dart';
import 'package:praticos/repositories/v2/repository_v2.dart';

/// Repository V2 para Customers com suporte a dual-write/dual-read.
class CustomerRepositoryV2 extends RepositoryV2<Customer?> {
  final CustomerRepository _legacy = CustomerRepository();
  final TenantCustomerRepository _tenant = TenantCustomerRepository();

  @override
  Repository<Customer?> get legacyRepo => _legacy;

  @override
  TenantRepository<Customer?> get tenantRepo => _tenant;

  // ═══════════════════════════════════════════════════════════════════
  // Customer-specific methods
  // ═══════════════════════════════════════════════════════════════════

  /// Stream de todos os customers do tenant ordenados por nome.
  Stream<List<Customer?>> streamCustomers(String companyId) {
    if (FeatureFlags.shouldReadFromNew) {
      final stream = _tenant.streamCustomers(companyId);

      if (FeatureFlags.shouldFallbackToLegacy) {
        return stream.handleError((error) {
          print('[CustomerRepositoryV2] Fallback streamCustomers: $error');
          return _legacy.streamQueryList(
            orderBy: [OrderBy('name')],
            args: [QueryArgs('company.id', companyId)],
          );
        });
      }

      return stream;
    }

    return _legacy.streamQueryList(
      orderBy: [OrderBy('name')],
      args: [QueryArgs('company.id', companyId)],
    );
  }

  /// Busca customers por nome.
  Future<List<Customer?>> searchByName(String companyId, String name) async {
    if (FeatureFlags.shouldReadFromNew) {
      try {
        return await _tenant.searchByName(companyId, name);
      } catch (e) {
        if (FeatureFlags.shouldFallbackToLegacy) {
          print('[CustomerRepositoryV2] Fallback searchByName: $e');
          return await _legacy.getQueryList(
            args: [
              QueryArgs('company.id', companyId),
              QueryArgs('name', name),
            ],
            orderBy: [OrderBy('name')],
          );
        }
        rethrow;
      }
    }

    return await _legacy.getQueryList(
      args: [
        QueryArgs('company.id', companyId),
        QueryArgs('name', name),
      ],
      orderBy: [OrderBy('name')],
    );
  }

  /// Busca customer por telefone.
  Future<Customer?> getByPhone(String companyId, String phone) async {
    if (FeatureFlags.shouldReadFromNew) {
      try {
        return await _tenant.getByPhone(companyId, phone);
      } catch (e) {
        if (FeatureFlags.shouldFallbackToLegacy) {
          print('[CustomerRepositoryV2] Fallback getByPhone: $e');
          final customers = await _legacy.getQueryList(
            args: [
              QueryArgs('company.id', companyId),
              QueryArgs('phone', phone),
            ],
            limit: 1,
          );
          return customers.isNotEmpty ? customers.first : null;
        }
        rethrow;
      }
    }

    final customers = await _legacy.getQueryList(
      args: [
        QueryArgs('company.id', companyId),
        QueryArgs('phone', phone),
      ],
      limit: 1,
    );
    return customers.isNotEmpty ? customers.first : null;
  }

  /// Busca customer por email.
  Future<Customer?> getByEmail(String companyId, String email) async {
    if (FeatureFlags.shouldReadFromNew) {
      try {
        return await _tenant.getByEmail(companyId, email);
      } catch (e) {
        if (FeatureFlags.shouldFallbackToLegacy) {
          print('[CustomerRepositoryV2] Fallback getByEmail: $e');
          final customers = await _legacy.getQueryList(
            args: [
              QueryArgs('company.id', companyId),
              QueryArgs('email', email),
            ],
            limit: 1,
          );
          return customers.isNotEmpty ? customers.first : null;
        }
        rethrow;
      }
    }

    final customers = await _legacy.getQueryList(
      args: [
        QueryArgs('company.id', companyId),
        QueryArgs('email', email),
      ],
      limit: 1,
    );
    return customers.isNotEmpty ? customers.first : null;
  }
}
