import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/screens/menu_navigation/home_groups.dart';
import 'package:praticos/utils/financial_summary.dart';
import 'package:praticos/utils/open_orders.dart';

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

/// When the customer last had activity: `lastActivityAt` (server), or the
/// most recent of `updatedAt`/`createdAt` before the backfill.
DateTime? customerLastActivity(Customer customer) {
  if (customer.lastActivityAt != null) return customer.lastActivityAt;
  final updated = customer.updatedAt;
  final created = customer.createdAt;
  if (updated == null) return created;
  if (created == null) return updated;
  return updated.isAfter(created) ? updated : created;
}

/// By name, ignoring case and accents (the order of [groupByInitial]).
List<Customer> sortByName(List<Customer> customers) {
  String key(Customer c) => customerInitial(c) + (c.name ?? '').toLowerCase();
  return [...customers]..sort((a, b) => key(a).compareTo(key(b)));
}

/// Most recent activity first; customers without a date last, by name.
List<Customer> sortByRecent(List<Customer> customers) {
  int byName(Customer a, Customer b) =>
      (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase());
  return [...customers]..sort((a, b) {
    final at = customerLastActivity(a);
    final bt = customerLastActivity(b);
    if (at == null && bt == null) return byName(a, b);
    if (at == null) return 1;
    if (bt == null) return -1;
    final cmp = bt.compareTo(at);
    return cmp != 0 ? cmp : byName(a, b);
  });
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

/// The customer screen shows 5 vehicles and 5 orders; "Ver todos" opens the
/// rest in place.
const int kCustomerShortList = 5;

/// The open list gets a search field only past 10 items, as the pickers.
const int kCustomerListSearchFrom = 10;

/// One list of the customer screen: what is shown, whether it has a
/// "Ver todos" and whether it has a search field.
class ShortList<T> {
  const ShortList(
    this.shown, {
    required this.canOpen,
    required this.searchable,
  });

  final List<T> shown;
  final bool canOpen;
  final bool searchable;
}

/// The first 5 of [items] while closed; everything (filtered by [query] past
/// 10 items) once [open]. With 5 or fewer there is no "Ver todos".
ShortList<T> shortList<T>(
  List<T> items, {
  required bool open,
  String query = '',
  required bool Function(T item, String query) matches,
}) {
  final canOpen = items.length > kCustomerShortList;
  final searchable = open && items.length > kCustomerListSearchFrom;
  final q = query.trim();
  final List<T> shown;
  if (canOpen && !open) {
    shown = items.take(kCustomerShortList).toList();
  } else if (searchable && q.isNotEmpty) {
    shown = items.where((item) => matches(item, q)).toList();
  } else {
    shown = items;
  }
  return ShortList(shown, canOpen: canOpen, searchable: searchable);
}

/// A vehicle of the customer screen by name or plate ("abc-1d23").
bool vehicleMatches(DeviceAggr vehicle, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  if ((vehicle.name ?? '').toLowerCase().contains(q)) return true;
  final plate = normalizePlate(q);
  return plate.length >= kMinPlateQueryLength &&
      normalizePlate(vehicle.serial).contains(plate);
}

/// An order of the customer screen by its number ("OS 123", "123").
bool orderNumberMatches(Order order, String query) {
  final digits = query.replaceAll(RegExp(r'\D'), '');
  return digits.isNotEmpty && '${order.number ?? ''}'.contains(digits);
}

/// Sum of the total of the completed orders ("Total gasto").
double totalSpent(List<Order> orders) => orders
    .where((o) => o.status == 'done')
    .fold<double>(0, (sum, o) => sum + (o.total ?? 0));

/// What the customer still owes ("Falta receber"): the A receber rule of
/// the Financeiro ([FinancialSummary.owesNow]), so the customer screen, the
/// Clientes list and the Financeiro never disagree.
double customerOwed(Iterable<Order?> orders) => orders
    .whereType<Order>()
    .where(FinancialSummary.owesNow)
    .fold<double>(0, (sum, o) => sum + FinancialSummary.openAmount(o));

/// Approved or running orders with nothing received yet ("Em andamento" of
/// the Financeiro): not owed yet, but the customer can already get them in
/// the statement.
double customerInProgress(Iterable<Order?> orders) => orders
    .whereType<Order>()
    .where((o) => FinancialSummary.isInProgress(o) && !FinancialSummary.owesNow(o))
    .fold<double>(0, (sum, o) => sum + FinancialSummary.openAmount(o));

/// [customerOwed] per customer id, for the Clientes list. Customers that owe
/// nothing are absent.
Map<String, double> owedByCustomerOf(Iterable<Order?> orders) {
  final result = <String, double>{};
  for (final o in orders.whereType<Order>().where(FinancialSummary.owesNow)) {
    final id = o.customer?.id;
    if (id == null) continue;
    result[id] = (result[id] ?? 0) + FinancialSummary.openAmount(o);
  }
  return result;
}

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

/// Groups the open orders by customer id, with the rules of the Início:
/// "em aberto" is [isOpenOrderStatus] (quotes count) and late is
/// [HomeRules.isOverdue] (by day). Same numbers in Início, Clientes and web
/// (docs/web-app/contract-cases/customer-summary.json).
Map<String, OpenOrdersSummary> summarizeOpenOrders(
  Iterable<Order?> orders,
  DateTime now,
) {
  final open = <String, int>{};
  final late = <String, int>{};
  for (final o in orders.whereType<Order>()) {
    final id = o.customer?.id;
    if (id == null) continue;
    if (!isOpenOrderStatus(o.status)) continue;
    open[id] = (open[id] ?? 0) + 1;
    if (HomeRules.isOverdue(o, now)) late[id] = (late[id] ?? 0) + 1;
  }
  return {
    for (final id in open.keys)
      id: OpenOrdersSummary(open: open[id]!, late: late[id] ?? 0),
  };
}

/// The Clientes badge from the numbers the server keeps on the customer
/// (`openOrders`, `openDueDates`: docs/CUSTOMER_LAST_ACTIVITY.md), so the
/// list reads no order. Late are the promised days behind today, by day
/// ([HomeRules.isOverdueAt]), so it changes with time without a write.
OpenOrdersSummary customerOpenSummary(Customer customer, DateTime now) {
  final late = (customer.openDueDates ?? const <DateTime>[])
      .where(
        (due) => HomeRules.isOverdueAt(
          status: 'approved',
          due: due.toLocal(),
          now: now,
        ),
      )
      .length;
  return OpenOrdersSummary(open: customer.openOrders ?? 0, late: late);
}

int _newestFirst(Order a, Order b) {
  final da = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  final db = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  return db.compareTo(da);
}

/// Number for a `wa.me` link, the one rule for the whole app.
///
/// A number typed with `+` keeps its own country; any other gets the country
/// code of the company (or [country], an ISO 3166-1 alpha-2 code), Brazil by
/// default. Numbers that are not valid go back as digits only, except old
/// Brazilian mobiles (8 digits after the area code, still common on WhatsApp),
/// which get the 55 too.
String whatsappNumber(String phone, {String? country}) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  try {
    final code = (country ?? Global.companyAggr?.country ?? 'BR').toUpperCase();
    final iso = IsoCode.values.where((c) => c.name == code).firstOrNull ??
        IsoCode.BR;
    final typed = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final international = typed.startsWith('+');
    final parsed = international
        ? PhoneNumber.parse(typed)
        : PhoneNumber.parse(typed, destinationCountry: iso);
    if (parsed.isValid()) return '${parsed.countryCode}${parsed.nsn}';
    if (!international &&
        iso == IsoCode.BR &&
        (parsed.nsn.length == 10 || parsed.nsn.length == 11)) {
      return '55${parsed.nsn}';
    }
  } catch (_) {
    // Not a phone number: fall through to the digits.
  }
  return digits;
}

/// Key to compare two phones: [whatsappNumber], and in Brazil without the
/// ninth digit, because WhatsApp still brings old mobiles with 8 digits.
String phoneMatchKey(String phone, {String? country}) {
  final number = whatsappNumber(phone, country: country);
  if (number.length == 13 && number.startsWith('55') && number[4] == '9') {
    return number.replaceRange(4, 5, '');
  }
  return number;
}

/// First of [customers] with the same [phone], in any format, or null.
Customer? findCustomerByPhone(
  List<Customer> customers,
  String phone, {
  String? country,
}) {
  final key = phoneMatchKey(phone, country: country);
  if (key.isEmpty) return null;
  for (final c in customers) {
    final other = c.phone ?? '';
    if (other.trim().isEmpty) continue;
    if (phoneMatchKey(other, country: country) == key) return c;
  }
  return null;
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
