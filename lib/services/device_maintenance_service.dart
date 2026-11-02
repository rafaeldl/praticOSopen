import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:praticos/global.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/repositories/tenant/tenant_customer_repository.dart';
import 'package:praticos/repositories/tenant/tenant_device_repository.dart';
import 'package:praticos/repositories/tenant/tenant_order_repository.dart';
import 'package:praticos/utils/customer_utils.dart';

/// Days before the date that "Manutenções chegando" and the push start.
const kMaintenanceLeadDays = 7;

/// Reads that decide what is offered never hold the user longer than this.
const kMaintenanceReadWait = Duration(seconds: 3);

/// `YYYY-MM-DD` of [date] as the user reads it.
String maintenanceDay(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

/// Last day that counts as "chegando" on [now].
String maintenanceWindowEnd(DateTime now) => maintenanceDay(
  DateTime(now.year, now.month, now.day + kMaintenanceLeadDays),
);

/// [date] plus [months], on the last day when the month is shorter
/// (31/08 + 6 months = 28/02).
DateTime addMonths(DateTime date, int months) {
  final first = DateTime(date.year, date.month + months);
  final lastDay = DateTime(first.year, first.month + 1, 0).day;
  return DateTime(
    first.year,
    first.month,
    date.day < lastDay ? date.day : lastDay,
  );
}

/// Whether a maintenance on [day] is late or within the "chegando" window.
bool maintenanceIsNear(String? day, DateTime now) =>
    day != null && day.compareTo(maintenanceWindowEnd(now)) <= 0;

/// First word of [name], without extra spaces; empty when there is none.
String firstName(String? name) {
  final words = (name ?? '').trim().split(RegExp(r'\s+'));
  return words.first;
}

/// Message to the customer, greeting by the first name when there is one.
String maintenanceWhatsappText(
  AppLocalizations l10n, {
  required String? customer,
  required String device,
  required String date,
}) {
  final name = firstName(customer);
  return name.isEmpty
      ? l10n.maintenanceWhatsappMessageNoName(device, date)
      : l10n.maintenanceWhatsappMessage(name, device, date);
}

/// Name of the first service of [order] on [deviceId], or null. A line with no
/// device belongs to all of them.
String? mainServiceName(Order? order, String? deviceId) {
  for (final line in order?.services ?? const <OrderService>[]) {
    if (line.deviceId != null && line.deviceId != deviceId) continue;
    final name = (line.service?.name ?? line.description ?? '').trim();
    if (name.isNotEmpty) return name;
  }
  return null;
}

/// [mainServiceName] of [order] for each of [deviceIds] that has one.
Map<String, String> mainServices(Order? order, Iterable<String> deviceIds) => {
  for (final id in deviceIds)
    if (mainServiceName(order, id) case final name?) id: name,
};

/// `wa.me` link with [message] ready for the person to review and send, or
/// null when there is no number to call.
Uri? whatsappMessageUri(String? phone, String message) {
  final number = (phone ?? '').trim().isEmpty ? '' : whatsappNumber(phone!);
  if (number.isEmpty) return null;
  // encodeComponent, not Uri.https: its "+" for spaces is not read by every
  // WhatsApp, which would show them in the message.
  return Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(message)}');
}

/// The order a maintenance starts from: its customer, the device, and the
/// services of [last] done on this device, without their photos.
Order maintenanceOrder(Device device, Order? last) {
  final aggr = device.toAggr();
  final customer = device.nextMaintenanceCustomer ?? last?.customer;
  final services = (last?.services ?? const <OrderService>[]).where(
    (line) => line.deviceId == null || line.deviceId == device.id,
  );
  return Order()
    ..customer = customer
    ..device = aggr
    ..devices = [aggr]
    ..services = [
      for (final line in services)
        OrderService()
          ..service = line.service
          ..description = line.description
          ..value = line.value
          ..deviceId = line.deviceId,
    ];
}

/// Most recent finished order among [orders], or null.
Order? lastDoneOrder(List<Order> orders) {
  Order? last;
  for (final order in orders) {
    if (order.status != 'done') continue;
    final date = order.completedAt ?? order.createdAt;
    final best = last?.completedAt ?? last?.createdAt;
    if (last == null || (date != null && (best == null || date.isAfter(best)))) {
      last = order;
    }
  }
  return last;
}

/// Reads and writes of the next maintenance, on the current company.
class DeviceMaintenanceService {
  DeviceMaintenanceService({
    TenantDeviceRepository? devices,
    TenantOrderRepository? orders,
    TenantCustomerRepository? customers,
  }) : _devicesOverride = devices,
       _ordersOverride = orders,
       _customersOverride = customers;

  final TenantDeviceRepository? _devicesOverride;
  final TenantOrderRepository? _ordersOverride;
  final TenantCustomerRepository? _customersOverride;

  TenantDeviceRepository get devices =>
      _devicesOverride ?? TenantDeviceRepository();
  TenantOrderRepository get orders =>
      _ordersOverride ?? TenantOrderRepository();
  TenantCustomerRepository get customers =>
      _customersOverride ?? TenantCustomerRepository();

  String? get _companyId => Global.companyAggr?.id;

  /// Queues the write and returns at once, so the app works offline. A
  /// refused write ends in [onFailed]; the device stream undoes it on its own.
  void save(
    Iterable<String> deviceIds, {
    required DateTime? date,
    CustomerAggr? customer,
    Map<String, String> lastServices = const {},
    VoidCallback? onFailed,
  }) {
    final companyId = _companyId;
    final ids = deviceIds.toList();
    if (companyId == null || ids.isEmpty) return;
    Future.sync(
      () => devices.setNextMaintenance(
        companyId,
        ids,
        day: date == null ? null : maintenanceDay(date),
        customer: customer,
        lastServices: lastServices,
        actor: Global.userAggr,
      ),
    ).catchError((Object e) {
      debugPrint('Could not save the next maintenance: $e');
      onFailed?.call();
    });
  }

  /// The active contract of [deviceId], or null. Technicians and consultants
  /// cannot query contracts: for them, and on any failure, there is none.
  Future<Order?> activeContract(String deviceId) async {
    final companyId = _companyId;
    if (companyId == null) return null;
    try {
      final contracts = await orders
          .streamContractsByDevice(companyId, deviceId)
          .first
          .timeout(kMaintenanceReadWait);
      return contracts.whereType<Order>().where((order) {
        return order.contract?.active == true;
      }).firstOrNull;
    } catch (e) {
      debugPrint('Could not read the device contracts: $e');
      return null;
    }
  }

  /// Fresh device, or null when it could not be read.
  Future<Device?> device(String deviceId) async {
    final companyId = _companyId;
    if (companyId == null) return null;
    try {
      return await devices
          .getSingle(companyId, deviceId)
          .timeout(kMaintenanceReadWait);
    } catch (e) {
      debugPrint('Could not read the device: $e');
      return null;
    }
  }

  /// [source] without the devices under an active contract: the contract
  /// already says when they are due.
  Future<List<Device>> withoutContract(List<Device> source) async {
    final contracts = await Future.wait(
      source.map((device) => activeContract(device.id ?? '')),
    );
    return [
      for (var i = 0; i < source.length; i++)
        if (contracts[i] == null) source[i],
    ];
  }

  /// Order for "Abrir OS". When the history cannot be read (the rules hide it
  /// from technicians and consultants) it starts without services.
  Future<Order> newOrderFor(Device device) async {
    final companyId = _companyId;
    final id = device.id;
    Order? last;
    if (companyId != null && id != null) {
      try {
        last = lastDoneOrder(
          await orders
              .getOrdersByDevice(companyId, id)
              .timeout(kMaintenanceReadWait),
        );
      } catch (e) {
        debugPrint('Could not read the device history: $e');
      }
    }
    return maintenanceOrder(device, last);
  }

  /// Current phone of the customer (it may have changed since the date was
  /// set), or null.
  Future<String?> customerPhone(String? customerId) async {
    final companyId = _companyId;
    if (companyId == null || customerId == null) return null;
    try {
      final customer = await customers
          .getSingle(companyId, customerId)
          .timeout(kMaintenanceReadWait);
      return customer?.phone;
    } catch (e) {
      debugPrint('Could not read the customer: $e');
      return null;
    }
  }
}
