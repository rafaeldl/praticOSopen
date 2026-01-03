import 'package:praticos/models/service.dart';
import 'package:praticos/repositories/tenant_repository.dart';
import 'package:praticos/repositories/repository.dart';

/// Repository para Services usando subcollections por tenant.
///
/// Path: `/companies/{companyId}/services/{serviceId}`
class TenantServiceRepository extends TenantRepository<Service?> {
  static const String collectionName = 'services';

  TenantServiceRepository() : super(collectionName);

  @override
  Service fromJson(Map<String, dynamic> data) => Service.fromJson(data);

  @override
  Map<String, dynamic> toJson(Service? service) => service!.toJson();

  // ═══════════════════════════════════════════════════════════════════
  // Service-specific methods
  // ═══════════════════════════════════════════════════════════════════

  /// Stream de todos os services do tenant ordenados por nome.
  Stream<List<Service?>> streamServices(String companyId) {
    return streamQueryList(
      companyId,
      orderBy: [OrderBy('name')],
    );
  }

  /// Busca services por faixa de preço.
  Future<List<Service?>> getByPriceRange(
    String companyId, {
    double? minValue,
    double? maxValue,
  }) async {
    List<QueryArgs> args = [];

    if (minValue != null) {
      args.add(QueryArgs('value', minValue, oper: 'isGreaterThanOrEqualTo'));
    }

    if (maxValue != null) {
      args.add(QueryArgs('value', maxValue, oper: 'isLessThanOrEqualTo'));
    }

    return getQueryList(
      companyId,
      args: args,
      orderBy: [OrderBy('value')],
    );
  }
}
