import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/screens/order/order_route.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/services/contract_directory.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

enum _ContractTab { active, ended }

/// "Contratos": the orders that repeat on their own. Active ones show when
/// the next order is born; ended ones show when they stopped. Tapping a row
/// opens the order that holds the contract.
class ContractListScreen extends StatefulWidget {
  const ContractListScreen({super.key, this.directory, this.onNew});

  /// Injected in tests; defaults to [FirestoreContractDirectory].
  final ContractDirectory? directory;

  /// "+": defaults to "Nova OS" with "Repetir" turned on.
  final VoidCallback? onNew;

  @override
  State<ContractListScreen> createState() => _ContractListScreenState();
}

class _ContractListScreenState extends State<ContractListScreen> {
  late final ContractDirectory _directory =
      widget.directory ?? FirestoreContractDirectory();
  StreamSubscription<List<Order>>? _subscription;
  List<Order>? _orders;
  bool _hasError = false;
  _ContractTab _tab = _ContractTab.active;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    _subscription?.cancel();
    setState(() {
      _orders = null;
      _hasError = false;
    });
    _subscription = _directory.watchContractOrders().listen(
      (list) {
        if (mounted) setState(() => _orders = list);
      },
      onError: (_) {
        if (mounted) setState(() => _hasError = true);
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  String _frequencyText(OrderContract contract) {
    final l10n = context.l10n;
    final count = contract.interval ?? 1;
    return switch (contract.frequency) {
      'daily' => l10n.contractEveryDays(count),
      'weekly' => l10n.contractEveryWeeks(count),
      'monthly' => l10n.contractEveryMonths(count),
      'yearly' => l10n.contractEveryYears(count),
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final secondary = AppColors.textSecondary.resolveFrom(context);
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      child: CustomScrollView(
        slivers: [
          AppNavBar(
            largeTitle: Text(l10n.contracts),
            previousTitle: l10n.myCompany,
            trailing: GlassBarButton(
              key: const ValueKey('contract_new'),
              label: l10n.contractNew,
              icon: CupertinoIcons.add,
              onPressed:
                  widget.onNew ?? () => openNewOrder(context, repeat: true),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageMargin,
                0,
                AppSpacing.pageMargin,
                AppSpacing.md,
              ),
              child: Text(
                l10n.contractsSubtitle(l10n.orderShort),
                style: AppTypography.callout.copyWith(color: secondary),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.blockMargin,
                vertical: AppSpacing.sm,
              ),
              child: CupertinoSlidingSegmentedControl<_ContractTab>(
                groupValue: _tab,
                children: {
                  _ContractTab.active: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Text(l10n.contractsTabActive),
                  ),
                  _ContractTab.ended: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Text(l10n.contractsTabEnded),
                  ),
                },
                onValueChanged: (value) {
                  if (value != null) setState(() => _tab = value);
                },
              ),
            ),
          ),
          ..._buildBody(context),
        ],
      ),
    );
  }

  List<Widget> _buildBody(BuildContext context) {
    final l10n = context.l10n;
    if (_hasError) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorState(onRetry: _listen),
        ),
      ];
    }
    final orders = _orders;
    if (orders == null) {
      return const [
        SliverFillRemaining(hasScrollBody: false, child: LoadingState()),
      ];
    }
    final showActive = _tab == _ContractTab.active;
    final visible = orders
        .where(
          (o) =>
              o.contract != null && (o.contract!.active == true) == showActive,
        )
        .toList();

    return [
      if (visible.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            title: showActive ? l10n.noContracts : l10n.contractsEmptyEnded,
            message: showActive
                ? l10n.contractsEmptyAdd(l10n.orderShort)
                : null,
          ),
        )
      else ...[
        SliverList(
          delegate: SliverChildListDelegate([
            for (final order in visible) _row(context, order),
          ]),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageMargin,
              AppSpacing.xl,
              AppSpacing.pageMargin,
              AppSpacing.xxl,
            ),
            child: Text(
              l10n.contractsFooterHint(l10n.orderShort),
              style: AppTypography.callout.copyWith(
                color: AppColors.textSecondary.resolveFrom(context),
              ),
            ),
          ),
        ),
      ],
    ];
  }

  Widget _row(BuildContext context, Order order) {
    final l10n = context.l10n;
    final format = FormatService();
    final contract = order.contract!;
    final active = contract.active == true;
    final vehicle = order.device?.name;

    final firstLine = [
      _frequencyText(contract),
      if (vehicle != null && vehicle.isNotEmpty) vehicle,
    ].where((part) => part.isNotEmpty).join(' · ');

    final String? lastLine;
    if (active) {
      lastLine = contract.nextDueDate == null
          ? null
          : l10n.contractNextOrderOn(
              format.formatDate(contract.nextDueDate),
              l10n.orderShort,
            );
    } else {
      final ended = contract.endDate ?? contract.lastGeneratedDate;
      lastLine = ended == null
          ? l10n.contractEnded
          : l10n.contractEndedOn(format.formatDate(ended));
    }

    return AppListRow(
      title: order.customer?.name ?? '',
      titleStyle: AppTypography.bodyStrong,
      subtitle: [
        firstLine,
        if (lastLine != null) lastLine,
      ].where((line) => line.isNotEmpty).join('\n'),
      onTap: () =>
          Navigator.pushNamed(context, '/order', arguments: {'order': order}),
    );
  }
}
