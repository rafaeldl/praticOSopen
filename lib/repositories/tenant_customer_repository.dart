import 'package:praticos/models/customer.dart';
import 'package:praticos/repositories/tenant_repository.dart';

class TenantCustomerRepository extends TenantRepository<Customer> {
  TenantCustomerRepository() : super('customers');

  @override
  Customer fromJson(Map<String, dynamic> data) => Customer.fromJson(data);

  @override
  Map<String, dynamic> toJson(Customer? item) => item!.toJson();
}
