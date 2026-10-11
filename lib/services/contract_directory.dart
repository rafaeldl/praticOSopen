import 'package:praticos/global.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/repositories/tenant/tenant_order_repository.dart';

/// Where the contracts screen gets its orders (injected in tests).
abstract class ContractDirectory {
  /// Orders that carry a recurring contract, active or ended.
  Stream<List<Order>> watchContractOrders();
}

class FirestoreContractDirectory implements ContractDirectory {
  final TenantOrderRepository _repository = TenantOrderRepository();

  @override
  Stream<List<Order>> watchContractOrders() {
    final companyId = Global.companyAggr?.id;
    if (companyId == null) return const Stream.empty();
    return _repository
        .streamContractOrders(companyId)
        .map((list) => list.whereType<Order>().toList());
  }
}
