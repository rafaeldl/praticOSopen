import 'package:praticos/global.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/repositories/tenant/tenant_customer_repository.dart';
import 'package:praticos/repositories/tenant/tenant_device_repository.dart';
import 'package:praticos/repositories/tenant/tenant_order_repository.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/utils/customer_utils.dart';

export 'package:praticos/utils/customer_utils.dart' show OpenOrdersSummary;

/// Read/write access the customer screens need. The screens depend on this
/// interface (not on Firestore) so they can be tested with a fake.
abstract class CustomerDirectory {
  /// Customers of the company, sorted by name.
  Stream<List<Customer>> watchCustomers();

  /// All vehicles/devices of the company (used to search by plate).
  Future<List<Device>> loadDevices();

  /// Id of the customer of the most recent order that has [device].
  Future<String?> ownerIdOf(Device device);

  /// Distinct vehicles used in the orders of [customerId], newest first.
  Future<List<DeviceAggr>> vehiclesOf(String customerId);

  /// Orders of [customerId], newest first.
  Stream<List<Order>> watchOrdersOf(String customerId);

  /// Open/overdue order counts per customer id.
  Future<Map<String, OpenOrdersSummary>> openOrdersByCustomer();

  /// Customer ids of the last ~50 orders, newest first, distinct.
  Future<List<String>> recentCustomerIds();

  Future<void> deleteCustomer(Customer customer);
}

/// [CustomerDirectory] backed by the tenant repositories.
class FirestoreCustomerDirectory implements CustomerDirectory {
  late final TenantCustomerRepository _customers = TenantCustomerRepository();
  late final TenantDeviceRepository _devices = TenantDeviceRepository();
  late final TenantOrderRepository _orders = TenantOrderRepository();

  String get _companyId => Global.companyAggr!.id!;

  @override
  Stream<List<Customer>> watchCustomers() => _customers
      .streamCustomers(_companyId)
      .map((l) => l.whereType<Customer>().toList());

  @override
  Future<List<Device>> loadDevices() async {
    final list = await _devices.getQueryList(
      _companyId,
      orderBy: [OrderBy('name')],
    );
    return list.whereType<Device>().toList();
  }

  @override
  Future<String?> ownerIdOf(Device device) async {
    final list = await _orders.getQueryList(
      _companyId,
      args: [QueryArgs('deviceIds', device.id, oper: 'arrayContains')],
    );
    return latestCustomerIdOf(list.whereType<Order>().toList());
  }

  @override
  Future<List<DeviceAggr>> vehiclesOf(String customerId) async {
    final orders = await watchOrdersOf(customerId).first;
    return distinctVehicles(orders);
  }

  /// Consultant and technician read only the orders they created (Firestore
  /// rules), so their query has to say so or it is denied.
  String? get _ownOrdersOnly {
    final auth = AuthorizationService.instance;
    if (auth.isConsultant || auth.isTechnician) return Global.currentUser?.uid;
    return null;
  }

  @override
  Stream<List<Order>> watchOrdersOf(String customerId) => _orders
      .streamOrders(
        _companyId,
        customerId: customerId,
        createdById: _ownOrdersOnly,
      )
      .map((l) => l.whereType<Order>().toList());

  @override
  Future<Map<String, OpenOrdersSummary>> openOrdersByCustomer() async {
    final list = await _orders
        .streamOrders(_companyId, status: 'due_date')
        .first;
    return summarizeOpenOrders(
      list.whereType<Order>().toList(),
      DateTime.now(),
    );
  }

  @override
  Future<List<String>> recentCustomerIds() async {
    final list = await _orders.getQueryList(
      _companyId,
      orderBy: [OrderBy('createdAt', descending: true)],
      limit: 50,
    );
    return recentCustomerIdsOf(list.whereType<Order>().toList());
  }

  @override
  Future<void> deleteCustomer(Customer customer) async {
    await _customers.removeItem(_companyId, customer.id);
  }
}
