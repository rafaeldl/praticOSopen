import 'package:praticos/models/company.dart';
import 'package:praticos/models/order.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

// Recurring contracts: one rule for the app (checkAndGenerateDueOrders) and
// the server job (firebase/functions/src/services/contract-generation.ts).
// The shared cases are docs/web-app/contract-cases/contract-generation.json.
//
// - Due: active, nextDueDate at or before now, and the due day not after the
//   contract's last day (endDate counts as included). See
//   [OrderContract.isDueAt].
// - After generating: the next due date is the first one after now, stepping
//   from the due date just generated. Missed periods are not made up, and an
//   app opened late never makes one order per opening. See
//   [OrderContract.advanceAfterGenerating].
// - Id of the generated order: [contractOrderId].

/// Time zone of a company's dates when it has none of its own (the company
/// document has no time zone field today).
const String contractTimeZone = 'America/Sao_Paulo';

bool _tzReady = false;

/// Id of the order generated from contract [templateId] for the due date
/// [due]: `contract_{templateId}_{YYYYMMDD}`, the day of [due] in the
/// company's time zone. The app and the server write the same document, so
/// whoever comes second (in a transaction) creates nothing.
///
/// Dates the app wrote have no offset and are the wall-clock time already,
/// so their own day counts. A UTC date is converted to [timeZone] first.
String contractOrderId(
  String templateId,
  DateTime due, {
  String timeZone = contractTimeZone,
}) {
  var day = due;
  if (due.isUtc) {
    if (!_tzReady) {
      tz_data.initializeTimeZones();
      _tzReady = true;
    }
    day = tz.TZDateTime.from(due, tz.getLocation(timeZone));
  }
  String two(int n) => n.toString().padLeft(2, '0');
  final key = '${day.year.toString().padLeft(4, '0')}${two(day.month)}'
      '${two(day.day)}';
  return 'contract_${templateId}_$key';
}

/// The order a contract generates from [template] at [now]: customer,
/// devices, items (service/product, description, value, quantity and line
/// total), assignee and author of the template; a quote, unpaid, without
/// number (the trigger numbers it) and without id (see [contractOrderId]).
Order buildContractOrder(
  Order template, {
  required DateTime now,
  CompanyAggr? company,
}) {
  final order = Order()
    ..company = company
    ..status = 'quote'
    ..payment = 'unpaid'
    ..createdAt = now
    ..createdBy = template.createdBy
    ..updatedAt = now
    ..updatedBy = template.createdBy
    ..customer = template.customer
    ..devices = template.devices != null ? List.from(template.devices!) : null
    ..device = template.device
    ..services = template.services
        ?.map(
          (s) => OrderService()
            ..service = s.service
            ..description = s.description
            ..value = s.value,
        )
        .toList()
    ..products = template.products
        ?.map(
          (p) => OrderProduct()
            ..product = p.product
            ..description = p.description
            ..value = p.value
            ..quantity = p.quantity
            ..total = p.total,
        )
        .toList()
    ..assignedTo = template.assignedTo
    ..contract = (OrderContract()
      ..parentOrderId = template.id
      ..parentOrderNumber = template.number);

  order.syncDeviceIds();

  double total = 0;
  for (final s in order.services ?? <OrderService>[]) {
    total += s.value ?? 0;
  }
  for (final p in order.products ?? <OrderProduct>[]) {
    total += p.total ?? (p.value ?? 0) * (p.quantity ?? 1);
  }
  order.total = total;
  return order;
}
