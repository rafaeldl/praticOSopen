import 'package:flutter/cupertino.dart';
import 'package:praticos/constants/label_keys.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/device_store.dart';
import 'package:praticos/models/custom_field.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/repositories/tenant/tenant_order_repository.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/theme/status_style.dart';
import 'package:praticos/widgets/cached_image.dart';
import 'package:provider/provider.dart';

/// Vehicle (device) screen (`/device_detail`, arguments `device` and
/// optionally `customer`): data, owner, "Nova OS" for this vehicle, order
/// history and active contracts. Edit and delete live in the "…" menu.
///
/// The device label ("Veículo", "Aparelho"…) and icon come from the segment.
class DeviceDetailScreen extends StatefulWidget {
  const DeviceDetailScreen({
    super.key,
    this.device,
    this.customer,
    this.orderRepository,
    this.onDelete,
    this.showPrices,
  });

  /// Falls back to the `device` route argument.
  final Device? device;

  /// Owner, when the caller knows it. Otherwise it is taken from the most
  /// recent order of the vehicle.
  final Customer? customer;

  /// Injected in tests; defaults to [TenantOrderRepository].
  final TenantOrderRepository? orderRepository;

  /// Deletes the device. Defaults to [DeviceStore.deleteDevice].
  final Future<void> Function(Device device)? onDelete;

  /// Order totals. Defaults to the `viewPrices` permission (off for everyone
  /// when `Company.useFinancial == false`).
  final bool? showPrices;

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  bool get _showPrices =>
      widget.showPrices ?? AuthorizationService.instance.canViewPrices;

  Device? _device;
  Customer? _customer;
  TenantOrderRepository? _repo;
  Stream<List<Order?>>? _orderStream;
  Stream<List<Order?>>? _contractStream;

  TenantOrderRepository get _orderRepo =>
      _repo ??= widget.orderRepository ?? TenantOrderRepository();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_device != null) return;
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _device = widget.device ?? args?['device'] as Device?;
    _customer = widget.customer ?? args?['customer'] as Customer?;
    _loadOrders();
  }

  void _loadOrders() {
    final companyId = Global.companyAggr?.id;
    final deviceId = _device?.id;
    setState(() {
      if (deviceId != null && companyId != null) {
        _orderStream = _orderRepo.streamOrdersByDevice(companyId, deviceId);
        _contractStream = _orderRepo.streamContractsByDevice(companyId, deviceId);
      }
    });
  }

  void _newOrder(Customer? owner) {
    final aggr = _device!.toAggr();
    final order = Order()
      ..customer = owner?.toAggr()
      ..device = aggr
      ..devices = [aggr];
    Navigator.pushNamed(context, '/order', arguments: {'order': order});
  }

  Future<void> _edit() async {
    final result = await Navigator.pushNamed(
      context,
      '/device_form',
      arguments: {'device': _device},
    );
    if (result is Device && mounted) setState(() => _device = result);
  }

  Future<void> _confirmDelete() async {
    final l10n = context.l10n;
    if (!AuthorizationService.instance
        .hasPermission(PermissionType.manageDevices)) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: Text(l10n.noPermission),
          content: Text(l10n.noPermissionToRemove),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.ok),
            ),
          ],
        ),
      );
      return;
    }
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(l10n.deleteDeviceTitle(_device?.name ?? '')),
        content: Text(l10n.deleteDeviceKeepsOrders),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.back),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final onDelete = widget.onDelete;
    if (onDelete != null) {
      await onDelete(_device!);
    } else {
      await DeviceStore().deleteDevice(_device!);
    }
    if (mounted) Navigator.pop(context);
  }

  void _showMenu() {
    final l10n = context.l10n;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _edit();
            },
            child: Text(l10n.edit),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(sheetContext);
              _confirmDelete();
            },
            child: Text(l10n.deleteAction),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: Text(l10n.cancel),
        ),
      ),
    );
  }

  /// Newest first; orders without a date go last.
  List<Order> _sorted(List<Order?> raw) {
    final orders = raw.whereType<Order>().toList();
    orders.sort((a, b) {
      final x = a.createdAt, y = b.createdAt;
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      return y.compareTo(x);
    });
    return orders;
  }

  Customer? _ownerFrom(List<Order> orders) {
    if (_customer != null) return _customer;
    for (final o in orders) {
      final c = o.customer;
      if (c != null) return Customer.fromJson(c.toJson());
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SegmentConfigProvider>();
    final l10n = context.l10n;
    final background = AppColors.background.resolveFrom(context);
    final device = _device;
    if (device == null) {
      return CupertinoPageScaffold(
        backgroundColor: background,
        navigationBar: CupertinoNavigationBar(middle: Text(config.device)),
        child: const LoadingState(),
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: background,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(device.name ?? config.device),
            backgroundColor: background,
            border: null,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 44),
              onPressed: _showMenu,
              child: Semantics(
                label: l10n.deviceActions,
                child: const Icon(CupertinoIcons.ellipsis_circle),
              ),
            ),
          ),
          if (_orderStream == null)
            SliverList(
              delegate: SliverChildListDelegate(
                _buildContent(config, const <Order>[]),
              ),
            )
          else
            StreamBuilder<List<Order?>>(
              stream: _orderStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return SliverToBoxAdapter(
                    child: SizedBox(
                      height: 200,
                      child: ErrorState(onRetry: _loadOrders),
                    ),
                  );
                }
                final data = snapshot.data;
                if (data == null) {
                  return const SliverToBoxAdapter(
                    child: SizedBox(height: 120, child: LoadingState()),
                  );
                }
                return SliverList(
                  delegate: SliverChildListDelegate(
                    _buildContent(config, _sorted(data)),
                  ),
                );
              },
            ),
          if (config.useContracts) _buildContractsSection(),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  List<Widget> _buildContent(SegmentConfigProvider config, List<Order> orders) {
    final l10n = context.l10n;
    final device = _device!;
    final owner = _ownerFrom(orders);
    final format = FormatService()..setLocale(l10n.localeName);
    final serialLabel = config.label(LabelKeys.deviceSerialNumber);
    final secondary = AppColors.textSecondary.resolveFrom(context);

    final subtitle = [
      if (device.serial?.isNotEmpty ?? false) '$serialLabel ${device.serial}',
      if (owner?.name?.isNotEmpty ?? false) owner!.name!,
    ].join(' · ');

    return [
      if (subtitle.isNotEmpty || (device.photo?.isNotEmpty ?? false))
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageMargin, 0, AppSpacing.pageMargin, AppSpacing.md,
          ),
          child: Row(
            children: [
              if (device.photo?.isNotEmpty ?? false) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.field),
                  child: CachedImage(
                    imageUrl: device.photo!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              if (subtitle.isNotEmpty)
                Expanded(
                  child: Text(
                    subtitle,
                    style: AppTypography.callout.copyWith(color: secondary),
                  ),
                ),
            ],
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.blockMargin, AppSpacing.sm, AppSpacing.blockMargin, 0,
        ),
        child: _PrimaryButton(
          label: l10n.newOrderAction,
          onPressed: () => _newOrder(owner),
        ),
      ),
      if (owner != null) ...[
        SectionLabel(config.customer),
        AppListRow(
          title: owner.name ?? '',
          subtitle: owner.phone,
          onTap: () => Navigator.pushNamed(
            context,
            '/customer_detail',
            arguments: {'customer': owner},
          ),
        ),
      ],
      ..._buildInfoRows(config),
      SectionLabel(l10n.orderHistory),
      if (orders.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageMargin,
            vertical: AppSpacing.xl,
          ),
          child: Text(
            l10n.noOrderHistory,
            style: AppTypography.body.copyWith(color: secondary),
          ),
        )
      else
        for (final o in orders) _orderRow(o, config, format),
    ];
  }

  List<Widget> _buildInfoRows(SegmentConfigProvider config) {
    final l10n = context.l10n;
    final device = _device!;
    final rows = <Widget>[];
    void add(String label, String? value) {
      if (value == null || value.isEmpty) return;
      rows.add(AppListRow(title: label, trailing: value));
    }

    add(config.label(LabelKeys.deviceBrand), device.manufacturer);
    add(config.label(LabelKeys.deviceCategory), device.category);
    rows.addAll(_customDataRows(config));
    if (config.useDeviceManagement) {
      rows.add(AppListRow(
        leading: StatusDot(
          color: DeviceStatusStyle.dotColor(device.status),
          size: 10,
        ),
        title: l10n.status,
        trailing: DeviceStatusStyle.label(l10n, device.status),
      ));
    }
    if (rows.isEmpty) return const [];
    return [SectionLabel(l10n.deviceDetailsLabel), ...rows];
  }

  List<Widget> _customDataRows(SegmentConfigProvider config) {
    final data = _device!.customData;
    if (data == null) return const [];
    final locale = context.l10n.localeName;
    final fields = config.fieldsFor('device');

    final labelMap = <String, String>{};
    for (final f in fields) {
      final label = f.getLabel(locale);
      labelMap[f.key] = label;
      labelMap[f.fieldName] = label;
    }

    return data.entries
        .where((e) => e.value != null && e.value.toString().isNotEmpty)
        .map((entry) {
      final label = labelMap[entry.key] ?? entry.key;
      final value = entry.value.toString();
      final field = fields.cast<CustomField?>().firstWhere(
            (f) => f!.key == entry.key || f.fieldName == entry.key,
            orElse: () => null,
          );
      final display = (field != null && field.type == 'select')
          ? field.getOptionLabel(value, locale)
          : value;
      return AppListRow(title: label, trailing: display);
    }).toList();
  }

  Widget _orderRow(Order order, SegmentConfigProvider config, FormatService format) {
    final l10n = context.l10n;
    final isOpen = order.status == 'approved' || order.status == 'progress';
    final late = isOpen &&
        order.dueDate != null &&
        order.dueDate!.isBefore(DateTime.now());
    final dotColor =
        late ? OrderStatusStyle.overdueColor : OrderStatusStyle.dotColor(order.status);
    final statusText = late ? l10n.orderOverdue : config.getStatus(order.status);
    final number = order.number == null ? '' : ' #${order.number}';

    return AppListRow(
      leading: StatusDot(color: dotColor),
      title: '${l10n.order}$number',
      subtitle: [
        statusText,
        if (order.createdAt != null) format.formatDate(order.createdAt),
      ].join(' · '),
      trailing: !_showPrices || order.total == null
          ? null
          : format.formatCurrency(order.total),
      onTap: () => Navigator.pushNamed(
        context,
        '/order',
        arguments: {'order': order},
      ),
    );
  }

  Widget _buildContractsSection() {
    final stream = _contractStream;
    if (stream == null) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return StreamBuilder<List<Order?>>(
      stream: stream,
      builder: (context, snapshot) {
        final contracts = snapshot.data
                ?.whereType<Order>()
                .where((o) => o.contract?.active == true)
                .toList() ??
            [];
        if (contracts.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        final l10n = context.l10n;
        final format = FormatService()..setLocale(l10n.localeName);
        return SliverList(
          delegate: SliverChildListDelegate([
            SectionLabel(l10n.contracts),
            for (final order in contracts)
              AppListRow(
                leading: Icon(
                  CupertinoIcons.repeat,
                  size: 18,
                  color: AppColors.textSecondary.resolveFrom(context),
                ),
                title:
                    '${l10n.order}${order.number == null ? '' : ' #${order.number}'} · ${_frequencyLabel(order.contract!.frequency)}',
                subtitle: order.contract!.nextDueDate == null
                    ? null
                    : '${l10n.contractNextDue}: ${format.formatDate(order.contract!.nextDueDate!)}',
                onTap: () => Navigator.pushNamed(
                  context,
                  '/order',
                  arguments: {'order': order},
                ),
              ),
          ]),
        );
      },
    );
  }

  String _frequencyLabel(String? frequency) {
    final l10n = context.l10n;
    switch (frequency) {
      case 'daily':
        return l10n.frequencyDaily;
      case 'weekly':
        return l10n.frequencyWeekly;
      case 'monthly':
        return l10n.frequencyMonthly;
      case 'yearly':
        return l10n.frequencyYearly;
      default:
        return frequency ?? '';
    }
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size.fromHeight(AppSizes.primaryButtonHeight),
      color: AppColors.accent.resolveFrom(context),
      borderRadius: BorderRadius.circular(AppRadii.button),
      onPressed: onPressed,
      child: Text(
        label,
        style: AppTypography.bodyStrong.copyWith(
          color: AppColors.onAccent.resolveFrom(context),
        ),
      ),
    );
  }
}
