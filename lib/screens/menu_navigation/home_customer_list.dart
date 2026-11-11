import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/customers/customer_form_screen.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/services/customer_directory.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/plate_lookup.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/theme/status_style.dart';
import 'package:praticos/utils/customer_utils.dart';
import 'package:praticos/utils/phone_format.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/models/permission.dart';

/// Clientes tab: searchable list (name, phone or vehicle plate). "Recentes"
/// (default) puts the last activity first (docs/CUSTOMER_LAST_ACTIVITY.md),
/// without showing the date; "A–Z" groups by initial. The choice is kept on the device. A row opens the
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
            trailing: _canAdd
                ? GlassBarButton(
                    label: l10n.newCustomer,
                    icon: CupertinoIcons.add,
                    onPressed: _addCustomer,
                  )
                : null,
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
          if (_customers?.isNotEmpty ?? false)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.blockMargin,
                  AppSpacing.xs,
                  AppSpacing.blockMargin,
                  0,
                ),
                child: CupertinoSlidingSegmentedControl<CustomerListOrder>(
                  groupValue: _order,
                  onValueChanged: (order) {
                    if (order != null) _setOrder(order);
                  },
                  children: {
                    for (final order in CustomerListOrder.values)
                      order: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xs,
                        ),
                        child: Text(
                          order == CustomerListOrder.recent
                              ? l10n.customersOrderRecent
                              : l10n.customersOrderName,
                          style: AppTypography.callout,
                        ),
                      ),
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
    if (recent) {
      children.addAll(matches.map(_row));
    } else {
      for (final entry in groupByInitial(matches).entries) {
        children.add(SectionLabel(entry.key));
        children.addAll(entry.value.map(_row));
      }
    }
    return [SliverList(delegate: SliverChildListDelegate(children))];
  }

  /// Name with the phone (or the plate found) under it; on the right what
  /// needs doing: what the customer owes over the open or late orders.
  /// Nothing pending, nothing on the right.
  Widget _row(Customer customer, {String? plate}) {
    final phone = (customer.phone?.isNotEmpty ?? false)
        ? formatPhone(customer.phone)
        : null;
    final subtitle = [?plate, ?phone].join(' · ');
    return AppListRow(
      title: customer.name ?? '',
      subtitle: subtitle.isEmpty ? null : subtitle,
      trailingWidget: _pending(customer),
      onTap: () => _open(customer),
    );
  }

  Widget? _pending(Customer customer) {
    final l10n = context.l10n;
    final summary =
        _openOrders?[customer.id] ??
        (_openOrders == null
            ? customerOpenSummary(customer, DateTime.now())
            : null);
    final late = (summary?.late ?? 0) > 0;
    final open = summary?.open ?? 0;
    final owed = _showOwed ? customer.owed ?? 0 : 0;
    if (!late && open == 0 && owed <= 0) return null;

    final stacked =
        MediaQuery.textScalerOf(context).scale(100) / 100 >=
        kAppListRowStackScale;
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final danger = OrderStatusStyle.overdueColor.resolveFrom(context);
    final align = stacked ? TextAlign.start : TextAlign.end;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: stacked
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        if (owed > 0)
          Text(
            l10n.customerOwedTrailing(
              (FormatService()..setLocale(l10n.localeName)).formatCurrency(
                owed,
              ),
            ),
            textAlign: align,
            style: AppTypography.callout.copyWith(
              color: AppColors.text.resolveFrom(context),
              fontFeatures: AppTypography.tabular,
            ),
          ),
        if (late || open > 0)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusDot(color: late ? danger : AppColors.warningDot),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  late
                      ? l10n.lateOrdersCount(summary!.late)
                      : l10n.openOrdersCount(open),
                  textAlign: align,
                  style: AppTypography.callout.copyWith(
                    color: late ? danger : secondary,
                    fontWeight: late ? FontWeight.w600 : null,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
