import 'package:praticos/models/service.dart';
import 'package:praticos/repositories/tenant_repository.dart';

class TenantServiceRepository extends TenantRepository<Service> {
  TenantServiceRepository() : super('services');

  @override
  Service fromJson(Map<String, dynamic> data) => Service.fromJson(data);

  @override
  Map<String, dynamic> toJson(Service? item) => item!.toJson();
}
