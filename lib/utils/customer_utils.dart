import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';

/// Pure helpers of the customer screens (list, picker and detail).

/// Lower-cases and strips everything but letters and digits, so "abc-1d23",
/// "ABC 1D23" and "abc1d23" are the same plate.
String normalizePlate(String? value) =>
    (value ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Minimum number of characters before a query is also tried as a plate.
const int kMinPlateQueryLength = 3;

/// Whether [device] has a plate (serial) containing the typed [query].
bool deviceMatchesPlate(Device device, String query) {
  final q = normalizePlate(query);
  if (q.length < kMinPlateQueryLength) return false;
  return normalizePlate(device.serial).contains(q);
}

/// Customers whose name or phone contains [query] (case-insensitive).
List<Customer> filterCustomers(List<Customer> customers, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return customers;
  // Digit matching only for phone-like queries, so "abc1" does not hit "1".
  final phoneLike = RegExp(r'^[\d\s()+\-.]+$').hasMatch(q);
  final digits = phoneLike ? q.replaceAll(RegExp(r'\D'), '') : '';
  return customers.where((c) {
    if ((c.name ?? '').toLowerCase().contains(q)) return true;
    final phone = c.phone ?? '';
    if (phone.toLowerCase().contains(q)) return true;
    return digits.isNotEmpty &&
        phone.replaceAll(RegExp(r'\D'), '').contains(digits);
  }).toList();
}

/// First letter of the customer name, upper-cased and without accent;
/// '#' for names that do not start with a letter.
String customerInitial(Customer customer) {
  final name = (customer.name ?? '').trim();
  if (name.isEmpty) return '#';
  const from = 'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
  const to = 'AAAAAEEEEIIIIOOOOOUUUUCN';
  var c = name[0].toUpperCase();
  final idx = from.indexOf(c);
  if (idx >= 0) c = to[idx];
  return RegExp(r'[A-Z]').hasMatch(c) ? c : '#';
}

/// Groups [customers] (already sorted by name) by initial, keeping order.
Map<String, List<Customer>> groupByInitial(List<Customer> customers) {
  final groups = <String, List<Customer>>{};
  for (final c in customers) {
    groups.putIfAbsent(customerInitial(c), () => []).add(c);
  }
  return groups;
}

/// Distinct vehicles used in [orders], most recent order first. Uses the
/// order's `devices` and falls back to the legacy single `device`.
List<DeviceAggr> distinctVehicles(List<Order> orders) {
  final sorted = [...orders]..sort(_newestFirst);
  final seen = <String>{};
  final result = <DeviceAggr>[];
  for (final order in sorted) {
    final devices = (order.devices?.isNotEmpty ?? false)
        ? order.devices!
        : [if (order.device != null) order.device!];
    for (final d in devices) {
      final id = d.id;
      if (id == null || !seen.add(id)) continue;
      result.add(d);
    }
  }
  return result;
}

/// Sum of the total of the completed orders ("Total gasto").
double totalSpent(List<Order> orders) => orders
    .where((o) => o.status == 'done')
    .fold<double>(0, (sum, o) => sum + (o.total ?? 0));

/// What the customer still owes ("Falta receber"): the open amount of every
/// order that is not a quote, not canceled and not paid, in any month.
double customerOwed(List<Order> orders) => orders
    .where((o) =>
        o.status != 'quote' && o.status != 'canceled' && o.payment != 'paid')
    .fold<double>(0, (sum, o) {
  final open = (o.total ?? 0) - (o.paidAmount ?? 0);
  return open > 0 ? sum + open : sum;
});

/// Customer ids of the most recent [orders], distinct, newest first.
List<String> recentCustomerIdsOf(List<Order> orders, {int max = 5}) {
  final sorted = [...orders]..sort(_newestFirst);
  final ids = <String>[];
  for (final o in sorted) {
    final id = o.customer?.id;
    if (id != null && !ids.contains(id)) ids.add(id);
    if (ids.length >= max) break;
  }
  return ids;
}

/// Id of the customer of the most recent order, or null.
String? latestCustomerIdOf(List<Order> orders) {
  final ids = recentCustomerIdsOf(orders, max: 1);
  return ids.isEmpty ? null : ids.first;
}

/// Open (approved or in progress) and overdue order counts of a customer.
class OpenOrdersSummary {
  const OpenOrdersSummary({this.open = 0, this.late = 0});

  final int open;
  final int late;
}

/// Groups the open orders by customer id. An order is late when its due date
/// is before [now].
Map<String, OpenOrdersSummary> summarizeOpenOrders(
  List<Order> orders,
  DateTime now,
) {
  final open = <String, int>{};
  final late = <String, int>{};
  for (final o in orders) {
    final id = o.customer?.id;
    if (id == null) continue;
    if (o.status != 'approved' && o.status != 'progress') continue;
    open[id] = (open[id] ?? 0) + 1;
    if (o.dueDate != null && o.dueDate!.isBefore(now)) {
      late[id] = (late[id] ?? 0) + 1;
    }
  }
  return {
    for (final id in open.keys)
      id: OpenOrdersSummary(open: open[id]!, late: late[id] ?? 0),
  };
}

int _newestFirst(Order a, Order b) {
  final da = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  final db = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  return db.compareTo(da);
}

/// Number for a `wa.me` link: digits only; Brazilian numbers typed without
/// the country code (10 or 11 digits) get the 55 prefix.
String whatsappNumber(String phone) {
  var digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('0')) digits = digits.substring(1);
  if (digits.length == 10 || digits.length == 11) digits = '55$digits';
  return digits;
}

/// How many of [orders] include the device [deviceId] (in `devices` or the
/// legacy single `device`).
int orderCountForDevice(List<Order> orders, String? deviceId) {
  if (deviceId == null) return 0;
  return orders.where((o) {
    final devices = (o.devices?.isNotEmpty ?? false)
        ? o.devices!
        : [if (o.device != null) o.device!];
    return devices.any((d) => d.id == deviceId);
  }).length;
}

String _nameKey(String? name) =>
    (name ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

String _phoneKey(String? phone) =>
    (phone ?? '').trim().isEmpty ? '' : whatsappNumber(phone!);

/// Id of the customer in [customers] that is the order's [current] customer
/// (the ✓ in "Qual cliente?"), or null when none can be told apart safely.
///
/// 1. Same `id`.
/// 2. When the order's customer has no id, or an id that is not in the list
///    (old or migrated record), the same name (ignoring case and extra
///    spaces) plus:
///    - the same phone, when the order has one; a customer with that name
///      but no phone counts only when it is the only one with that name;
///    - nothing else when the order has no phone, but then the name must be
///      unique in the list.
///
/// Two customers that cannot be told apart get no ✓: a missing check is
/// better than a wrong one.
String? currentCustomerId(CustomerAggr? current, List<Customer> customers) {
  if (current == null) return null;
  final id = current.id;
  if (id != null && id.isNotEmpty && customers.any((c) => c.id == id)) {
    return id;
  }
  final name = _nameKey(current.name);
  if (name.isEmpty) return null;
  final sameName = customers
      .where((c) => c.id != null && _nameKey(c.name) == name)
      .toList();
  if (sameName.isEmpty) return null;
  final phone = _phoneKey(current.phone);
  if (phone.isEmpty) {
    return sameName.length == 1 ? sameName.first.id : null;
  }
  final samePhone =
      sameName.where((c) => _phoneKey(c.phone) == phone).toList();
  if (samePhone.isNotEmpty) {
    return samePhone.length == 1 ? samePhone.first.id : null;
  }
  if (sameName.length == 1 && _phoneKey(sameName.first.phone).isEmpty) {
    return sameName.first.id;
  }
  return null;
}

/// The vehicles of [order]: `devices`, or the legacy single `device`.
List<DeviceAggr> orderDevices(Order? order) {
  if (order == null) return const [];
  if (order.devices?.isNotEmpty ?? false) return order.devices!;
  return [if (order.device != null) order.device!];
}

/// Ids of the [devices] that are on the order ([current]): the ✓ in
/// "Qual veículo?". Matches by `id`; a vehicle without id, or with an id not
/// in the list, matches by plate/serial only when exactly one device has it.
Set<String> currentDeviceIds(List<DeviceAggr> current, List<Device> devices) {
  final ids = {for (final d in devices) if (d.id != null) d.id!};
  final result = <String>{};
  for (final c in current) {
    if (c.id != null && ids.contains(c.id)) {
      result.add(c.id!);
      continue;
    }
    final plate = normalizePlate(c.serial);
    if (plate.isEmpty) continue;
    final hits = devices
        .where((d) => d.id != null && normalizePlate(d.serial) == plate)
        .toList();
    if (hits.length == 1) result.add(hits.first.id!);
  }
  return result;
}
