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
import 'package:praticos/services/plate_lookup.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/theme/status_style.dart';
import 'package:praticos/utils/customer_utils.dart';
import 'package:praticos/utils/phone_format.dart';
import 'package:provider/provider.dart';

/// Clientes tab: searchable list (name, phone or vehicle plate) grouped by
/// initial. A row opens the customer screen; "+" opens the new-customer sheet.
class HomeCustomerList extends StatefulWidget {
  const HomeCustomerList({super.key, this.directory});

  /// Injected in tests; defaults to [FirestoreCustomerDirectory].
  final CustomerDirectory? directory;

  @override
  State<HomeCustomerList> createState() => _HomeCustomerListState();
}

class _HomeCustomerListState extends State<HomeCustomerList> {
  late final CustomerDirectory _directory =
      widget.directory ?? FirestoreCustomerDirectory();
  late final PlateLookup _plates =
      PlateLookup(_directory, onChanged: () => setState(() {}));
  final TextEditingController _searchController = TextEditingController();

  StreamSubscription<List<Customer>>? _subscription;
  List<Customer>? _customers;
  Map<String, OpenOrdersSummary> _openOrders = const {};
  bool _hasError = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _listen();
    _plates.load();
    _directory.openOrdersByCustomer().then((summary) {
      if (mounted) setState(() => _openOrders = summary);
    }).catchError((_) {});
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
            trailing: GlassBarButton(
              label: l10n.newCustomer,
              icon: CupertinoIcons.add,
              onPressed: _addCustomer,
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
                placeholder: l10n.searchCustomerPlaceholder,
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
          child: ErrorState(message: l10n.customerLookupError, onRetry: _listen),
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
          AppSpacing.pageMargin, AppSpacing.xs, AppSpacing.pageMargin, 0,
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
          plate: '${l10n.plateValue(hit.device.serial ?? '')} · ${hit.device.name ?? ''}',
        ),
    ];
    for (final entry in groupByInitial(matches).entries) {
      children.add(SectionLabel(entry.key));
      children.addAll(entry.value.map(_row));
    }
    return [SliverList(delegate: SliverChildListDelegate(children))];
  }

  Widget _row(Customer customer, {String? plate}) {
    final l10n = context.l10n;
    final summary = _openOrders[customer.id];
    String? status;
    CupertinoDynamicColor? dot;
    if (summary != null && summary.late > 0) {
      status = l10n.lateOrdersCount(summary.late);
      dot = OrderStatusStyle.overdueColor;
    } else if (summary != null && summary.open > 0) {
      status = l10n.openOrdersCount(summary.open);
      dot = AppColors.warning;
    }
    final phone =
        (customer.phone?.isNotEmpty ?? false) ? formatPhone(customer.phone) : null;
    final subtitle = [?plate, ?status, ?phone].join(' · ');
    return AppListRow(
      leading: dot == null ? null : StatusDot(color: dot),
      title: customer.name ?? '',
      subtitle: subtitle.isEmpty ? null : subtitle,
      onTap: () => _open(customer),
    );
  }
}
