import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/screens/customers/customer_form_screen.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
import 'package:praticos/screens/widgets/picker_screen.dart';
import 'package:praticos/services/customer_directory.dart';
import 'package:praticos/services/plate_lookup.dart';
import 'package:praticos/utils/customer_utils.dart';
import 'package:praticos/utils/phone_format.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/models/permission.dart';

/// Result of the customer picker: the customer and, when known, the vehicle.
///
/// The vehicle is set when the user searched by plate, or when the customer
/// has exactly one vehicle and the order has none yet.
class CustomerPick {
  const CustomerPick(this.customer, [this.device]);

  final Customer customer;
  final Device? device;
}

/// "Qual cliente?": the picker used from the order (`/customer_list`, with
/// the `order` route argument). Pops with a [CustomerPick]. Built on
/// [PickerScaffold].
///
/// - Search (above 10 customers) by name, phone or vehicle plate. A plate hit
///   selects the customer and the vehicle together.
/// - A customer with a single vehicle selects it too (unless the order
///   already has one).
/// - "Novo cliente" opens the new-customer sheet; a search that finds no one
///   offers "Cadastrar “texto”" with the name (or phone) filled in.
/// - "Recentes" first, then "Todos". The order's customer has the ✓.
/// - No swipe actions: this is a choice, not a management list.
class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({
    super.key,
    this.directory,
    this.canAdd,
    this.onSaveCustomer,
  });

  /// Injected in tests; defaults to [FirestoreCustomerDirectory].
  final CustomerDirectory? directory;

  /// Whether "Novo cliente"/"Cadastrar “x”" show. Defaults to the
  /// `manageCustomers` permission (the Firestore rules deny the write
  /// otherwise). Test seam.
  final bool? canAdd;

  /// Saves a new customer. Defaults to [CustomerFormScreen]'s. Test seam.
  final Future<void> Function(Customer customer)? onSaveCustomer;

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

/// How long a tap waits for the customer's vehicles before choosing the
/// customer without one.
const _vehiclesTimeout = Duration(seconds: 3);

class _CustomerListScreenState extends State<CustomerListScreen> {
  late final CustomerDirectory _directory =
      widget.directory ?? FirestoreCustomerDirectory();
  late final PlateLookup _plates = PlateLookup(
    _directory,
    onChanged: () => setState(() {}),
  );

  StreamSubscription<List<Customer>>? _subscription;
  List<Customer>? _customers;
  bool _hasError = false;
  List<String> _recentIds = const [];
  bool _picking = false;
  Order? _order;
  bool _argsRead = false;

  @override
  void initState() {
    super.initState();
    _listen();
    _plates.load();
    _directory
        .recentCustomerIds()
        .then((ids) {
          if (mounted) setState(() => _recentIds = ids);
        })
        .catchError((_) {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsRead) return;
    _argsRead = true;
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _order = args?['order'] as Order?;
  }

  void _listen() {
    _subscription?.cancel();
    setState(() {
      _customers = null;
      _hasError = false;
    });
    _subscription = _directory.watchCustomers().listen(
      (list) {
        if (mounted) setState(() => _customers = list);
      },
      onError: (_) {
        if (mounted) setState(() => _hasError = true);
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _plates.dispose();
    super.dispose();
  }

  Future<void> _pick(Customer customer, {Device? device}) async {
    if (_picking) return;
    _picking = true;
    var selected = device;
    final orderHasVehicle = _order?.devices?.isNotEmpty ?? false;
    if (selected == null && !orderHasVehicle && customer.id != null) {
      try {
        final vehicles = await _directory
            .vehiclesOf(customer.id!)
            .timeout(_vehiclesTimeout);
        if (vehicles.length == 1) {
          selected = Device.fromJson(vehicles.first.toJson());
        }
      } catch (_) {
        // Vehicles are a convenience; the customer is still chosen (also
        // when the lookup is slow or never answers).
      }
    }
    if (!mounted) return;
    Navigator.pop(context, CustomerPick(customer, selected));
  }

  /// Opens the new-customer sheet; [query] (what was typed) fills the phone
  /// when it is only digits, the name otherwise.
  Future<void> _addCustomer([String query = '']) async {
    final text = query.trim();
    Customer? draft;
    if (text.isNotEmpty) {
      draft = Customer();
      if (RegExp(r'^[\d\s()+-]+$').hasMatch(text)) {
        draft.phone = text;
      } else {
        draft.name = text;
      }
    }
    final created = await FormSheet.show<Customer>(
      context,
      (_) => CustomerFormScreen(
        asSheet: true,
        customer: draft,
        onSave: widget.onSaveCustomer,
      ),
    );
    if (created != null && mounted) {
      Navigator.pop(context, CustomerPick(created));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final customers = _customers ?? const <Customer>[];
    final selectedId = currentCustomerId(_order?.customer, customers);
    final canAdd =
        widget.canAdd ??
        AuthorizationService.instance.hasPermission(
          PermissionType.manageCustomers,
        );
    return PickerScaffold<CustomerPick>(
      title: l10n.pickerCustomerTitle,
      itemCount: customers.length,
      searchPlaceholder: l10n.searchCustomerPlaceholder,
      autofocusSearch: true,
      onQueryChanged: _plates.search,
      loading: _customers == null && !_hasError,
      hasError: _hasError,
      errorMessage: l10n.customerLookupError,
      onRetry: _listen,
      addLabel: canAdd ? l10n.pickerNewCustomer : null,
      onAdd: canAdd ? _addCustomer : null,
      onCreate: canAdd ? _addCustomer : null,
      canCreate: (query) =>
          !customers.any((c) => pickerSameText(c.name, query)),
      noMatchText: l10n.noCustomerMatching,
      emptyTitle: l10n.noCustomersYet,
      onSelect: (pick) => _pick(pick.customer, device: pick.device),
      sections: (query) => _sections(customers, query, selectedId),
    );
  }

  List<PickerSection<CustomerPick>> _sections(
    List<Customer> customers,
    String query,
    String? selectedId,
  ) {
    final l10n = context.l10n;
    final hits = query.isEmpty
        ? const <PlateHit>[]
        : _plates.hits(query, customers);
    final hitIds = hits.map((h) => h.customer.id).toSet();
    final matches = filterCustomers(
      customers,
      query,
    ).where((c) => !hitIds.contains(c.id)).toList();

    PickerItem<CustomerPick> item(Customer c, {Device? device}) => PickerItem(
      value: CustomerPick(c, device),
      title: c.name ?? '',
      subtitle: device == null
          ? (c.phone?.isNotEmpty ?? false ? formatPhone(c.phone) : null)
          : '${l10n.plateValue(device.serial ?? '')} · ${device.name ?? ''}',
      selected: selectedId != null && c.id == selectedId,
    );

    if (query.isNotEmpty) {
      return [
        PickerSection(
          items: [
            for (final hit in hits) item(hit.customer, device: hit.device),
            ...matches.map(item),
          ],
        ),
      ];
    }
    final byId = {for (final c in customers) c.id: c};
    final recents = _recentIds
        .map((id) => byId[id])
        .whereType<Customer>()
        .take(5)
        .toList();
    return [
      if (recents.isNotEmpty)
        PickerSection(
          label: l10n.pickerRecent,
          items: recents.map(item).toList(),
        ),
      PickerSection(
        label: recents.isEmpty ? null : l10n.pickerAll,
        items: matches.map(item).toList(),
      ),
    ];
  }
}
