import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/screens/customers/customer_form_screen.dart';
import 'package:praticos/screens/widgets/add_row.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/app_sheet.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/services/customer_directory.dart';
import 'package:praticos/services/plate_lookup.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/utils/customer_utils.dart';
import 'package:praticos/utils/phone_format.dart';

/// Result of the customer picker: the customer and, when known, the vehicle.
///
/// The vehicle is set when the user searched by plate, or when the customer
/// has exactly one vehicle and the order has none yet.
class CustomerPick {
  const CustomerPick(this.customer, [this.device]);

  final Customer customer;
  final Device? device;
}

/// "Quem é o cliente?": the picker used from the order (`/customer_list`, with
/// the `order` route argument). Pops with a [CustomerPick].
///
/// - Search by name, phone or vehicle plate. A plate hit selects the customer
///   and the vehicle together.
/// - A customer with a single vehicle selects it too (unless the order
///   already has one).
/// - "Cadastrar cliente novo" opens the new-customer sheet.
/// - No swipe actions: this is a choice, not a management list.
class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key, this.directory});

  /// Injected in tests; defaults to [FirestoreCustomerDirectory].
  final CustomerDirectory? directory;

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  late final CustomerDirectory _directory =
      widget.directory ?? FirestoreCustomerDirectory();
  final TextEditingController _searchController = TextEditingController();
  late final PlateLookup _plates =
      PlateLookup(_directory, onChanged: () => setState(() {}));

  StreamSubscription<List<Customer>>? _subscription;
  List<Customer>? _customers;
  bool _hasError = false;
  List<String> _recentIds = const [];
  String _query = '';
  bool _picking = false;
  Order? _order;
  bool _argsRead = false;

  @override
  void initState() {
    super.initState();
    _listen();
    _plates.load();
    _directory.recentCustomerIds().then((ids) {
      if (mounted) setState(() => _recentIds = ids);
    }).catchError((_) {});
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
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _plates.search(value);
  }

  Future<void> _pick(Customer customer, {Device? device}) async {
    if (_picking) return;
    _picking = true;
    var selected = device;
    final orderHasVehicle = _order?.devices?.isNotEmpty ?? false;
    if (selected == null && !orderHasVehicle && customer.id != null) {
      try {
        final vehicles = await _directory.vehiclesOf(customer.id!);
        if (vehicles.length == 1) {
          selected = Device.fromJson(vehicles.first.toJson());
        }
      } catch (_) {
        // Vehicles are a convenience; the customer is still chosen.
      }
    }
    if (!mounted) return;
    Navigator.pop(context, CustomerPick(customer, selected));
  }

  Future<void> _addCustomer() async {
    final created = await AppSheet.show<Customer>(
      context,
      (_) => const CustomerFormScreen(asSheet: true),
    );
    if (created != null && mounted) {
      Navigator.pop(context, CustomerPick(created));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          AppNavBar(
            largeTitle: Text(l10n.pickCustomerTitle),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.blockMargin,
                vertical: AppSpacing.sm,
              ),
              child: CupertinoSearchTextField(
                controller: _searchController,
                autofocus: true,
                placeholder: l10n.searchCustomerPlaceholder,
                backgroundColor: AppColors.secondaryFill.resolveFrom(context),
                style: AppTypography.body.copyWith(
                  color: AppColors.text.resolveFrom(context),
                ),
                onChanged: _onQueryChanged,
              ),
            ),
          ),
          ..._buildBody(),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  List<Widget> _buildBody() {
    final l10n = context.l10n;
    if (_hasError) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorState(
            message: l10n.customerLookupError,
            onRetry: _listen,
          ),
        ),
      ];
    }
    final customers = _customers;
    if (customers == null) {
      return const [SliverFillRemaining(hasScrollBody: false, child: LoadingState())];
    }

    final query = _query.trim();
    if (customers.isEmpty && query.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            title: l10n.noCustomersYet,
            actionLabel: l10n.addFirstCustomer,
            onAction: _addCustomer,
          ),
        ),
      ];
    }

    final hits = query.isEmpty ? const <PlateHit>[] : _plates.hits(query, customers);
    final hitIds = hits.map((h) => h.customer.id).toSet();
    final matches = filterCustomers(customers, query)
        .where((c) => !hitIds.contains(c.id))
        .toList();

    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: AddRow(label: l10n.addNewCustomer, onTap: _addCustomer),
      ),
    ];

    if (hits.isEmpty && matches.isEmpty) {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(title: l10n.noCustomerMatching(query)),
        ),
      );
      return slivers;
    }

    Widget row(Customer c, {Device? device}) => AppListRow(
          title: c.name ?? '',
          subtitle: device == null
              ? (c.phone?.isNotEmpty ?? false ? formatPhone(c.phone) : null)
              : '${l10n.plateValue(device.serial ?? '')} · ${device.name ?? ''}',
          showChevron: false,
          onTap: () => _pick(c, device: device),
        );

    final children = <Widget>[];
    for (final hit in hits) {
      children.add(row(hit.customer, device: hit.device));
    }

    if (query.isEmpty) {
      final byId = {for (final c in customers) c.id: c};
      final recents = _recentIds
          .map((id) => byId[id])
          .whereType<Customer>()
          .take(5)
          .toList();
      if (recents.isNotEmpty) {
        children.add(SectionLabel(l10n.recentCustomers));
        children.addAll(recents.map(row));
      }
      for (final entry in groupByInitial(matches).entries) {
        children.add(SectionLabel(entry.key));
        children.addAll(entry.value.map(row));
      }
    } else {
      children.addAll(matches.map(row));
    }

    slivers.add(SliverList(delegate: SliverChildListDelegate(children)));
    return slivers;
  }
}
