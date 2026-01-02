import 'package:praticos/models/order.dart';
import 'package:praticos/repositories/tenant_repository.dart';

class TenantOrderRepository extends TenantRepository<Order> {
  TenantOrderRepository() : super('orders');

  @override
  Order fromJson(Map<String, dynamic> data) => Order.fromJson(data);

  @override
  Map<String, dynamic> toJson(Order? item) => item!.toJson();
}
