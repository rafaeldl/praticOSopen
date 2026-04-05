import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType, Divider, InkWell;
import 'package:provider/provider.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/repositories/tenant/tenant_order_repository.dart';
import 'package:praticos/widgets/cached_image.dart';
import 'package:praticos/models/custom_field.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/extensions/context_extensions.dart';

class DeviceDetailScreen extends StatefulWidget {
  const DeviceDetailScreen({super.key});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  Device? _device;
  final TenantOrderRepository _orderRepo = TenantOrderRepository();
  Stream<List<Order?>>? _orderStream;
  Stream<List<Order?>>? _contractStream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_device == null) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _device = args?['device'] as Device?;
      if (_device?.id != null && Global.companyAggr?.id != null) {
        _orderStream = _orderRepo.streamOrdersByDevice(
          Global.companyAggr!.id!,
          _device!.id!,
        );
        _contractStream = _orderRepo.streamContractsByDevice(
          Global.companyAggr!.id!,
          _device!.id!,
        );
      }
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'active':
        return CupertinoColors.systemGreen;
      case 'maintenance':
        return CupertinoColors.systemOrange;
      case 'inactive':
        return CupertinoColors.systemGrey;
      case 'decommissioned':
        return CupertinoColors.systemRed;
      default:
        return CupertinoColors.systemGreen;
    }
  }

  String _statusLabel(BuildContext context, String? status) {
    switch (status) {
      case 'active':
        return context.l10n.deviceStatusActive;
      case 'maintenance':
        return context.l10n.deviceStatusMaintenance;
      case 'inactive':
        return context.l10n.deviceStatusInactive;
      case 'decommissioned':
        return context.l10n.deviceStatusDecommissioned;
      default:
        return context.l10n.deviceStatusActive;
    }
  }

  Color _orderStatusColor(String? status) {
    switch (status) {
      case 'quote':
        return CupertinoColors.systemBlue;
      case 'approved':
        return CupertinoColors.activeBlue;
      case 'progress':
        return CupertinoColors.systemOrange;
      case 'done':
        return CupertinoColors.systemGreen;
      case 'canceled':
        return CupertinoColors.systemRed;
      default:
        return CupertinoColors.systemGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SegmentConfigProvider>();
    final formatService = FormatService();

    if (_device == null) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(config.device),
        ),
        child: const Center(child: CupertinoActivityIndicator()),
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: Material(
        type: MaterialType.transparency,
        child: CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: Text(_device!.name ?? config.device),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(CupertinoIcons.pencil),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/device_form',
                    arguments: {'device': _device},
                  ).then((result) {
                    if (result != null && result is Device) {
                      setState(() => _device = result);
                    }
                  });
                },
              ),
            ),

            // Header section with photo and key info
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Photo
                    _buildAvatar(config),
                    const SizedBox(width: 16),
                    // Key info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_device!.serial != null && _device!.serial!.isNotEmpty)
                            Text(
                              _device!.serial!,
                              style: TextStyle(
                                fontSize: 15,
                                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                              ),
                            ),
                          if (_device!.manufacturer != null && _device!.manufacturer!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _device!.manufacturer!,
                              style: TextStyle(
                                fontSize: 15,
                                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                              ),
                            ),
                          ],
                          if (config.useDeviceManagement) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _statusColor(_device!.status),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _statusLabel(context, _device!.status),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: CupertinoColors.label.resolveFrom(context),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Device info section
            SliverToBoxAdapter(
              child: CupertinoListSection.insetGrouped(
                header: Text(context.l10n.details.toUpperCase()),
                children: [
                  if (_device!.category != null)
                    _buildInfoRow(config.label('device.category'), _device!.category!),
                  if (_device!.manufacturer != null)
                    _buildInfoRow(config.label('device.brand'), _device!.manufacturer!),
                  if (_device!.name != null)
                    _buildInfoRow(config.label('device.model'), _device!.name!),
                  if (_device!.serial != null)
                    _buildInfoRow(config.label('device.serial'), _device!.serial!),
                  if (_device!.customData != null)
                    ..._buildCustomDataRows(config),
                ],
              ),
            ),

            // Order history section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 20, top: 20, bottom: 8),
                child: Text(
                  context.l10n.orderHistory.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            ),

            // Order history list
            _buildOrderHistory(config, formatService),

            // Contracts section
            if (config.useContracts)
              _buildContractsSection(config, formatService),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(SegmentConfigProvider config) {
    if (_device?.photo != null && _device!.photo!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedImage(
          imageUrl: _device!.photo!,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        config.deviceIcon,
        size: 36,
        color: CupertinoColors.systemGrey.resolveFrom(context),
      ),
    );
  }

  List<Widget> _buildCustomDataRows(SegmentConfigProvider config) {
    final locale = context.l10n.localeName;
    final fields = config.fieldsFor('device');

    // Build lookup: both full key (device.year) and short key (year) → label
    final labelMap = <String, String>{};
    for (final f in fields) {
      final label = f.getLabel(locale);
      labelMap[f.key] = label;
      labelMap[f.fieldName] = label;
    }

    return _device!.customData!.entries
        .where((e) => e.value != null && e.value.toString().isNotEmpty)
        .map((entry) {
      final label = labelMap[entry.key] ?? entry.key;
      final value = entry.value.toString();

      // Resolve select option labels
      final field = fields.cast<CustomField?>().firstWhere(
        (f) => f!.key == entry.key || f.fieldName == entry.key,
        orElse: () => null,
      );
      final displayValue = (field != null && field.type == 'select')
          ? field.getOptionLabel(value, locale)
          : value;

      return _buildInfoRow(label, displayValue);
    }).toList();
  }

  Widget _buildInfoRow(String label, String value) {
    return CupertinoListTile(
      title: Text(label, style: const TextStyle(fontSize: 15)),
      additionalInfo: Text(
        value,
        style: TextStyle(
          fontSize: 15,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    );
  }

  Widget _buildOrderHistory(SegmentConfigProvider config, FormatService formatService) {
    if (_orderStream == null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: Center(
            child: Text(
              context.l10n.noOrderHistory,
              style: TextStyle(
                fontSize: 15,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
        ),
      );
    }

    return StreamBuilder<List<Order?>>(
      stream: _orderStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CupertinoActivityIndicator()),
            ),
          );
        }

        final orders = snapshot.data?.whereType<Order>().toList() ?? [];

        if (orders.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              child: Center(
                child: Text(
                  context.l10n.noOrderHistory,
                  style: TextStyle(
                    fontSize: 15,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final order = orders[index];
              return _buildOrderItem(order, config, formatService, index == orders.length - 1);
            },
            childCount: orders.length,
          ),
        );
      },
    );
  }

  Widget _buildOrderItem(Order order, SegmentConfigProvider config, FormatService formatService, bool isLast) {
    final statusLabel = config.getStatus(order.status);
    final statusColor = _orderStatusColor(order.status);
    final dateStr = order.createdAt != null
        ? formatService.formatDate(order.createdAt!)
        : '';

    return Container(
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, '/order_detail', arguments: {'order': order});
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Status dot
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${order.number ?? ''} - $statusLabel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.label.resolveFrom(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${order.customer?.name ?? ''} $dateStr',
                          style: TextStyle(
                            fontSize: 14,
                            color: CupertinoColors.secondaryLabel.resolveFrom(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (order.total != null)
                    Text(
                      formatService.formatCurrency(order.total!),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
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

  Widget _buildContractsSection(SegmentConfigProvider config, FormatService formatService) {
    if (_contractStream == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return StreamBuilder<List<Order?>>(
      stream: _contractStream,
      builder: (context, snapshot) {
        final contracts = snapshot.data
            ?.whereType<Order>()
            .where((o) => o.contract?.active == true)
            .toList() ?? [];

        if (contracts.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Text(
                  context.l10n.contracts.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final order = contracts[index];
                  final contract = order.contract!;
                  final freq = _contractFrequencyLabel(contract.frequency);
                  final nextDue = contract.nextDueDate != null
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
                                Icon(
                                  CupertinoIcons.repeat,
                                  size: 18,
                                  color: CupertinoColors.systemOrange.resolveFrom(context),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '#${order.number ?? ''} - $freq',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: CupertinoColors.label.resolveFrom(context),
                                        ),
                                      ),
                                      if (nextDue.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          '${context.l10n.contractNextDue}: $nextDue',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Icon(
                                  CupertinoIcons.chevron_right,
                                  size: 16,
                                  color: CupertinoColors.systemGrey3.resolveFrom(context),
                                ),
                              ],
                            ),
                          ),
                          if (index < contracts.length - 1)
                            Divider(
                              height: 1,
                              indent: 46,
                              color: CupertinoColors.systemGrey5.resolveFrom(context),
                            ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: contracts.length,
              ),
            ),
          ],
        );
      },
    );
  }

  String _contractFrequencyLabel(String? frequency) {
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
}
