import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/customers/customer_form_screen.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/pull_down_menu.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/services/customer_directory.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/plate_lookup.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/theme/status_style.dart';
import 'package:praticos/utils/customer_utils.dart';
import 'package:praticos/screens/widgets/order_list_row.dart';
import 'package:praticos/utils/phone_format.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/models/permission.dart';

/// Clientes tab: searchable list (name, phone or vehicle plate). "Recentes"
/// (default) puts the last activity first (docs/CUSTOMER_LAST_ACTIVITY.md),
/// without showing the date; "A–Z" groups by initial. The order is picked in
/// the top sort button (a pull-down menu), so it takes no room on the screen. The choice is kept on the device. A row opens the
/// customer screen; "+" opens the new-customer sheet.
/// How the Clientes list is ordered.
enum CustomerListOrder { recent, name }

const _orderKey = 'customersOrder';

class HomeCustomerList extends StatefulWidget {
  const HomeCustomerList({
    super.key,
    this.directory,
    this.canAdd,
    this.showOwed,
    this.seesAllOrders,
  });

  /// Injected in tests; defaults to [FirestoreCustomerDirectory].
  final CustomerDirectory? directory;

  /// Whether "+" (new customer) shows. Defaults to the `manageCustomers`
  /// permission (the Firestore rules deny the write otherwise). Test seam.
  final bool? canAdd;

  /// Whether each row says how much the customer owes (`Customer.owed`, of
  /// every order). Defaults to who reads the Financeiro. Test seam.
  final bool? showOwed;

  /// Whether the badges come from the numbers the server keeps on the
  /// customer (every order) instead of the orders this person may read.
  /// Defaults to `viewAllOrders`: consultant and technician count only
  /// their own orders, as the Firestore rules allow. Test seam.
  final bool? seesAllOrders;

  @override
  State<HomeCustomerList> createState() => _HomeCustomerListState();
}

class _HomeCustomerListState extends State<HomeCustomerList> {
  late final CustomerDirectory _directory =
      widget.directory ?? FirestoreCustomerDirectory();
  bool get _canAdd =>
      widget.canAdd ??
      AuthorizationService.instance.hasPermission(
        PermissionType.manageCustomers,
      );

  late final PlateLookup _plates = PlateLookup(
    _directory,
    onChanged: () => setState(() {}),
  );
  final TextEditingController _searchController = TextEditingController();

  StreamSubscription<List<Customer>>? _subscription;
  List<Customer>? _customers;

  /// Badges counted from the orders this person may read; null when they
  /// come from the customer ([HomeCustomerList.seesAllOrders]).
  Map<String, OpenOrdersSummary>? _openOrders;
  bool get _seesAllOrders =>
      widget.seesAllOrders ??
      AuthorizationService.instance.hasPermission(PermissionType.viewAllOrders);
  bool get _showOwed =>
      widget.showOwed ??
      AuthorizationService.instance.hasPermission(
        PermissionType.viewFinancialReports,
      );
  bool _hasError = false;
  String _query = '';
  CustomerListOrder _order = CustomerListOrder.recent;

  @override
  void initState() {
    super.initState();
    _listen();
    SharedPreferences.getInstance()
        .then((prefs) {
          final saved = prefs.getString(_orderKey);
          if (!mounted || saved == null) return;
          setState(
            () => _order = saved == CustomerListOrder.name.name
                ? CustomerListOrder.name
                : CustomerListOrder.recent,
          );
        })
        .catchError((_) {});
    _plates.load();
    if (!_seesAllOrders) {
      _openOrders = const {};
      _directory
          .openOrdersByCustomer()
          .then((summary) {
            if (mounted) setState(() => _openOrders = summary);
          })
          .catchError((_) {});
    }
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

  void _open(Customer customer) {
    Navigator.pushNamed(
      context,
      '/customer_detail',
      arguments: {'customer': customer},
    );
  }

  void _setOrder(CustomerListOrder order) {
    setState(() => _order = order);
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setString(_orderKey, order.name))
        .catchError((_) => false);
  }

  /// "Ordenar por" (top button): the iOS pull-down menu, ✓ on the current one.
  Future<void> _chooseOrder() async {
    final l10n = context.l10n;
    final choice = await showPullDownMenu(
      context,
      groups: [
        PullDownGroup(title: l10n.customersSortBy, [
          PullDownItem(
            value: CustomerListOrder.recent.name,
            label: l10n.customersOrderRecent,
            icon: CupertinoIcons.clock,
            checked: _order == CustomerListOrder.recent,
          ),
          PullDownItem(
            value: CustomerListOrder.name.name,
            label: l10n.customersOrderName,
            icon: CupertinoIcons.textformat_abc,
            checked: _order == CustomerListOrder.name,
          ),
        ]),
      ],
    );
    if (choice == null || !mounted) return;
    _setOrder(
      choice == CustomerListOrder.name.name
          ? CustomerListOrder.name
          : CustomerListOrder.recent,
    );
  }

  Future<void> _addCustomer() async {
    final created = await FormSheet.show<Customer>(
      context,
      (_) => const CustomerFormScreen(asSheet: true),
    );
    if (created != null && mounted) _open(created);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final config = context.watch<SegmentConfigProvider>();
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          AppNavBar(
            largeTitle: Text(config.customerPlural),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_customers?.isNotEmpty ?? false)
                  GlassBarButton(
                    identifier: 'customers_sort_button',
                    label: l10n.customersSortBy,
                    icon: CupertinoIcons.arrow_up_arrow_down,
                    onPressed: _chooseOrder,
                  ),
                if (_canAdd) ...[
                  const SizedBox(width: AppSpacing.sm),
                  GlassBarButton(
                    label: l10n.newCustomer,
                    icon: CupertinoIcons.add,
                    onPressed: _addCustomer,
                  ),
                ],
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.blockMargin,
                vertical: AppSpacing.sm,
              ),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: l10n.searchCustomerPlaceholder(
                  config.serialLabelInSentence,
                ),
                backgroundColor: AppColors.secondaryFill.resolveFrom(context),
                style: AppTypography.body.copyWith(
                  color: AppColors.text.resolveFrom(context),
                ),
                onChanged: (value) {
                  setState(() => _query = value);
                  _plates.search(value);
                },
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
      return const [
        SliverFillRemaining(hasScrollBody: false, child: LoadingState()),
      ];
    }
    final query = _query.trim();
    if (customers.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            title: l10n.noCustomersYet,
            actionLabel: _canAdd ? l10n.addFirstCustomer : null,
            onAction: _canAdd ? _addCustomer : null,
          ),
        ),
      ];
    }

    final hits = query.isEmpty
        ? const <PlateHit>[]
        : _plates.hits(query, customers);
    final hitIds = hits.map((h) => h.customer.id).toSet();
    final recent = _order == CustomerListOrder.recent;
    final matches = filterCustomers(
      recent ? sortByRecent(customers) : sortByName(customers),
      query,
    ).where((c) => !hitIds.contains(c.id)).toList();

    if (hits.isEmpty && matches.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(title: l10n.noCustomerMatching(query)),
        ),
      ];
    }

    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageMargin,
          AppSpacing.xs,
          AppSpacing.pageMargin,
          0,
        ),
        child: Text(
          l10n.customersCount(customers.length),
          style: AppTypography.callout.copyWith(
            color: AppColors.textSecondary.resolveFrom(context),
          ),
        ),
      ),
      for (final hit in hits)
        _row(
          hit.customer,
          plate:
              '${SegmentConfigProvider.instance.serialValue(hit.device.serial)} · ${hit.device.name ?? ''}',
        ),
    ];
    // Rows split by a thin line, like the orders on Início.
    Iterable<Widget> rows(Iterable<Customer> list) sync* {
      var first = true;
      for (final customer in list) {
        if (!first) yield const _RowDivider();
        first = false;
        yield _row(customer);
      }
    }

    if (recent) {
      children.addAll(rows(matches));
    } else {
      for (final entry in groupByInitial(matches).entries) {
        children.add(SectionLabel(entry.key));
        children.addAll(rows(entry.value));
      }
    }
    return [SliverList(delegate: SliverChildListDelegate(children))];
  }

  /// Same row as the orders on Início (OrderListRow): name in bold with what
  /// the customer owes on the right, the phone or the plate found, then the
  /// open orders with their dot and the late ones in red on the right.
  Widget _row(Customer customer, {String? plate}) {
    final l10n = context.l10n;
    final phone = (customer.phone?.isNotEmpty ?? false)
        ? formatPhone(customer.phone)
        : null;
    final summary =
        _openOrders?[customer.id] ??
        (_openOrders == null
            ? customerOpenSummary(customer, DateTime.now())
            : null);
    final late = summary?.late ?? 0;
    final open = summary?.open ?? 0;
    final owed = _showOwed ? customer.owed ?? 0 : 0;
    final detail = [?plate, ?phone].join(' · ');
    final money = (FormatService()..setLocale(l10n.localeName)).formatCurrency(
      owed,
    );
    return Semantics(
      identifier: 'customer_row_${customer.id}',
      button: true,
      child: OrderListRow(
        key: ValueKey('customer_row_${customer.id}'),
        customerName: customer.name ?? '',
        detailText: detail.isEmpty ? null : detail,
        statusText: open > 0 ? l10n.openOrdersCount(open) : null,
        statusColor: open > 0 ? AppColors.warningDot : null,
        // What the customer owes on the right, where the order total sits
        // on Início.
        valueText: owed > 0 ? money : null,
        problemText: late > 0 ? l10n.lateOrdersCount(late) : null,
        problemColor: OrderStatusStyle.overdueColor.resolveFrom(context),
        onTap: () => _open(customer),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: OrderListRow.leadingInset),
      child: Container(
        height: 0.5,
        color: AppColors.separator.resolveFrom(context),
      ),
    );
  }
}
