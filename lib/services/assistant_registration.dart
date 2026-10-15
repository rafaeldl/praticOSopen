import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/repositories/v2/customer_repository_v2.dart';
import 'package:praticos/repositories/v2/device_repository_v2.dart';
import 'package:praticos/services/analytics_service.dart';
import 'package:praticos/utils/search_utils.dart';

/// Customer and vehicle the assistant heard but that are not registered.
///
/// They get their id right away so the order can point to them on screen;
/// the registration is written only when the user saves the order ("✓"),
/// never by the assistant alone. "Desfazer" before saving drops them.
class AssistantRegistration {
  AssistantRegistration({
    CustomerRepositoryV2? customers,
    DeviceRepositoryV2? devices,
    String Function()? newId,
  }) : _customers = customers,
       _devices = devices,
       _newId =
           newId ??
           (() => FirebaseFirestore.instance.collection('tmp').doc().id);

  final CustomerRepositoryV2? _customers;
  final DeviceRepositoryV2? _devices;
  final String Function() _newId;

  /// A new customer with its id, not saved yet.
  Customer newCustomer(String name, String? phone) => Customer()
    ..id = _newId()
    ..name = name.trim()
    ..phone = (phone?.trim().isEmpty ?? true) ? null : phone!.trim();

  /// A new vehicle with its id, not saved yet. Only with a plate/serial: a
  /// model alone would make duplicates.
  Device newDevice({required String serial, String? name, String? manufacturer}) =>
      Device()
        ..id = _newId()
        ..serial = serial.trim().toUpperCase()
        ..name = (name?.trim().isEmpty ?? true) ? serial.trim().toUpperCase() : name!.trim()
        ..manufacturer = (manufacturer?.trim().isEmpty ?? true) ? null : manufacturer!.trim()
        ..status = 'active';

  /// Writes the customer (on "✓"). Does not wait for the server (offline).
  Future<void> saveCustomer(Customer customer) async {
    final companyId = Global.companyAggr?.id;
    if (companyId == null) return;
    final now = DateTime.now();
    customer
      ..company = Global.companyAggr
      ..createdAt = now
      ..createdBy = Global.userAggr
      ..updatedAt = now
      ..updatedBy = Global.userAggr
      ..keywords = generateKeywords(customer.name);
    await (_customers ?? CustomerRepositoryV2()).createItem(companyId, customer);
    AnalyticsService.instance.logCustomerCreated(customerId: customer.id);
  }

  /// Writes the vehicle (on "✓").
  Future<void> saveDevice(Device device) async {
    final companyId = Global.companyAggr?.id;
    if (companyId == null) return;
    final now = DateTime.now();
    device
      ..company = Global.companyAggr
      ..createdAt = now
      ..createdBy = Global.userAggr
      ..updatedAt = now
      ..updatedBy = Global.userAggr
      ..keywords = generateKeywords(device.name);
    await (_devices ?? DeviceRepositoryV2()).createItem(companyId, device);
  }
}
