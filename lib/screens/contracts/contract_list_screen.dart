import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType, Divider, InkWell;
import 'package:provider/provider.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/repositories/tenant/tenant_order_repository.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';

class ContractListScreen extends StatefulWidget {
  const ContractListScreen({super.key});

  @override
  State<ContractListScreen> createState() => _ContractListScreenState();
}

class _ContractListScreenState extends State<ContractListScreen> {
  final TenantOrderRepository _repository = TenantOrderRepository();
  Stream<List<Order?>>? _contractStream;

  @override
  void initState() {
    super.initState();
    final companyId = Global.companyAggr?.id;
    if (companyId != null) {
      _contractStream = _repository.streamContractOrders(companyId);
    }
  }

  String _frequencyLabel(BuildContext context, String? frequency) {
    switch (frequency) {
      case 'daily':
        return context.l10n.frequencyDaily;
      case 'weekly':
        return context.l10n.frequencyWeekly;
      case 'monthly':
        return context.l10n.frequencyMonthly;
      case 'yearly':
        return context.l10n.frequencyYearly;
      default:
        return frequency ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SegmentConfigProvider>();
    final formatService = FormatService();

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: Material(
        type: MaterialType.transparency,
        child: CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: Text(context.l10n.contracts),
            ),
            if (_contractStream != null)
              StreamBuilder<List<Order?>>(
                stream: _contractStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      child: Center(child: CupertinoActivityIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Text(context.l10n.errorLoading),
                      ),
                    );
                  }

                  final orders = snapshot.data
                      ?.whereType<Order>()
                      .where((o) => o.contract?.active == true)
                      .toList() ?? [];

                  if (orders.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.repeat,
                                size: 64,
                                color: CupertinoColors.systemGrey.resolveFrom(context),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                context.l10n.noContracts,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.label.resolveFrom(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final order = orders[index];
                        return _buildContractItem(
                          order, config, formatService, index == orders.length - 1,
                        );
                      },
                      childCount: orders.length,
                    ),
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildContractItem(
    Order order,
    SegmentConfigProvider config,
    FormatService formatService,
    bool isLast,
  ) {
    final contract = order.contract!;
    final isActive = contract.active ?? false;
    final frequencyStr = _frequencyLabel(context, contract.frequency);
    final intervalStr = (contract.interval != null && contract.interval! > 1)
        ? '${context.l10n.interval} ${contract.interval} $frequencyStr'
        : frequencyStr;
    final nextDueStr = contract.nextDueDate != null
        ? formatService.formatDate(contract.nextDueDate!)
        : '';

    return Container(
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, '/order', arguments: {'order': order});
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Active indicator
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isActive
                          ? CupertinoColors.systemGreen
                          : CupertinoColors.systemGrey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${order.number ?? ''} - ${order.customer?.name ?? ''}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.label.resolveFrom(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          intervalStr,
                          style: TextStyle(
                            fontSize: 14,
                            color: CupertinoColors.secondaryLabel.resolveFrom(context),
                          ),
                        ),
                        if (nextDueStr.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${context.l10n.contractNextDue}: $nextDueStr',
                            style: TextStyle(
                              fontSize: 13,
                              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (contract.autoGenerate == true)
                    Icon(
                      CupertinoIcons.bolt_fill,
                      size: 16,
                      color: CupertinoColors.systemOrange.resolveFrom(context),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: CupertinoColors.systemGrey3.resolveFrom(context),
                  ),
                ],
              ),
            ),
            if (!isLast)
              Divider(
                height: 1,
                indent: 38,
                color: CupertinoColors.systemGrey5.resolveFrom(context),
              ),
          ],
        ),
      ),
    );
  }
}
