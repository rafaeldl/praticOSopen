import 'package:flutter/cupertino.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/contract_config_sheet.dart';
import 'package:praticos/constants/label_keys.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/device_store.dart';
import 'package:praticos/models/custom_field.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/utils/device_reading.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/repositories/tenant/tenant_device_repository.dart';
import 'package:praticos/repositories/tenant/tenant_order_repository.dart';
import 'package:praticos/screens/devices/next_maintenance_offer.dart';
import 'package:praticos/screens/order/order_extras.dart';
import 'package:praticos/screens/widgets/app_toast.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/screens/widgets/order_history_row.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/device_maintenance_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/widgets/cached_image.dart';
import 'package:praticos/screens/contracts/contracts_title.dart';
import 'package:provider/provider.dart';
import 'package:praticos/screens/widgets/failure_alert.dart';
import 'package:praticos/screens/widgets/primary_button.dart';

/// [value] of a number field, grouped for reading ("98.000"), or null to show
/// it as it is. The saved value does not change. Year has the number type but
/// is not a quantity. A value with a leading zero or any other text stays as
/// typed.
String? formatDeviceNumber(
  CustomField? field,
  Object? value,
  FormatService format,
) {
  if (field?.type != 'number' || field?.fieldName == 'year') return null;
  final number = value is num
      ? (value == value.truncate() ? value.toInt() : null)
      : RegExp(r'^-?[1-9]\d*$').hasMatch('$value')
      ? int.tryParse('$value')
      : null;
  return number == null ? null : format.formatDecimal(number);
}

/// Vehicle (device) screen (`/device_detail`, arguments `device` and
/// optionally `customer`): data, owner, next maintenance, "Nova OS" for this
/// vehicle, order history and active contracts. Edit and delete live in the
/// "…" menu.
///
/// The device label ("Veículo", "Aparelho"…) and icon come from the segment.
class DeviceDetailScreen extends StatefulWidget {
  const DeviceDetailScreen({
    super.key,
    this.device,
    this.customer,
    this.orderRepository,
    this.deviceRepository,
    this.canManageDevices,
    this.saveMaintenance,
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

  /// Injected in tests; defaults to [TenantDeviceRepository].
  final TenantDeviceRepository? deviceRepository;

  /// Who may set the next maintenance. Defaults to `manageDevices`.
  final bool? canManageDevices;

  /// Writes the next maintenance; defaults to [DeviceMaintenanceService].
  final void Function(
    String deviceId,
    DateTime? date,
    CustomerAggr? customer,
    String? lastService,
    VoidCallback onFailed,
  )?
  saveMaintenance;

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
  String? _previousTitle;
  TenantOrderRepository? _repo;
  Stream<List<Order?>>? _orderStream;
  Stream<List<Order?>>? _contractStream;
  Stream<List<Order?>>? _maintenanceContracts;
  Stream<Device?>? _maintenanceStream;
  bool _editingMaintenance = false;

  TenantOrderRepository get _orderRepo =>
      _repo ??= widget.orderRepository ?? TenantOrderRepository();

  bool get _canManageDevices =>
      widget.canManageDevices ??
      AuthorizationService.instance.hasPermission(PermissionType.manageDevices);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_device != null) return;
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _device = widget.device ?? args?['device'] as Device?;
    _customer = widget.customer ?? args?['customer'] as Customer?;
    _previousTitle = args?['previousTitle'] as String?;
    _loadOrders();
  }

  void _loadOrders() {
    final companyId = Global.companyAggr?.id;
    final deviceId = _device?.id;
    setState(() {
      if (deviceId != null && companyId != null) {
        _orderStream = _orderRepo.streamOrdersByDevice(companyId, deviceId);
        _contractStream = _orderRepo.streamContractsByDevice(companyId, deviceId);
        // A stream has one listener: this one is for the maintenance row.
        _maintenanceContracts = _orderRepo.streamContractsByDevice(
          companyId,
          deviceId,
        );
        // The device that came in may be an aggregate, with no date.
        _maintenanceStream =
            (widget.deviceRepository ?? TenantDeviceRepository())
                .streamSingle(companyId, deviceId);
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
    try {
      if (onDelete != null) {
        await onDelete(_device!);
      } else {
        await DeviceStore().deleteDevice(_device!);
      }
    } catch (e) {
      debugPrint('Could not delete the device: $e');
      if (mounted) {
        await showFailureAlert(context, context.l10n.deleteFailedTryAgain);
      }
      return;
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
          AppNavBar(
            largeTitle: Text(device.name ?? config.device),
            previousTitle: _previousTitle ?? config.devicePlural,
            trailing: GlassBarButton(
              label: l10n.deviceActions,
              icon: CupertinoIcons.ellipsis,
              onPressed: _showMenu,
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
                // The history failed (e.g. a role the rules deny): "Nova OS"
                // and the maintenance stay; only the list shows the error.
                if (snapshot.hasError) {
                  return SliverList(
                    delegate: SliverChildListDelegate(
                      _buildContent(
                        config,
                        const <Order>[],
                        historyFailed: true,
                      ),
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

  List<Widget> _buildContent(
    SegmentConfigProvider config,
    List<Order> orders, {
    bool historyFailed = false,
  }) {
    final l10n = context.l10n;
    final device = _device!;
    final owner = _ownerFrom(orders);
    final serialLabel = config.label(LabelKeys.deviceSerialNumber);
    final secondary = AppColors.textSecondary.resolveFrom(context);

    // Plate/serial and the last reading ("98.000 km"), what identifies it.
    final readingField = config.readingField;
    final format = FormatService()..setLocale(l10n.localeName);
    final plate = [
      if (device.serial?.isNotEmpty ?? false) '$serialLabel ${device.serial}',
      if (readingField != null)
        ?formatReading(
          readingField,
          deviceReading(device.customData, readingField),
          format,
        ),
    ].join(' · ');
    final ownerName = owner?.name ?? '';
    final subtitle = [plate, if (ownerName.isNotEmpty) ownerName].join(' · ');
    final subtitleStyle = AppTypography.callout.copyWith(color: secondary);
    final deviceLower = config.device.toLowerCase();

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
                  child: ownerName.isEmpty
                      ? Text(plate, style: subtitleStyle)
                      : Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${plate.isEmpty ? '' : '$plate · '}'
                              '${l10n.deviceOwnerPrefix}',
                              style: subtitleStyle,
                            ),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _openOwner(owner!),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: AppSizes.minTouchTarget,
                                ),
                                child: Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  widthFactor: 1,
                                  child: Text(
                                    ownerName,
                                    style: subtitleStyle.copyWith(
                                      color: AppColors.accentText
                                          .resolveFrom(context),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
            ],
          ),
        ),
      _buildMaintenance(owner, mainServiceName(lastDoneOrder(orders), device.id)),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.blockMargin, AppSpacing.sm, AppSpacing.blockMargin, 0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                l10n.askOrderForDevice(deviceLower),
                style: AppTypography.callout.copyWith(color: secondary),
              ),
            ),
            _PrimaryButton(
              label: l10n.newOrderAction,
              onPressed: () => _newOrder(owner),
            ),
          ],
        ),
      ),
      ..._buildInfoRows(config),
      SectionLabel(l10n.ordersOfDevice(deviceLower)),
      if (historyFailed)
        SizedBox(
          key: const ValueKey('device_history_error'),
          height: 200,
          child: ErrorState(onRetry: _loadOrders),
        )
      else if (orders.isEmpty)
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
        for (final o in orders) _orderRow(o, config),
    ];
  }

  /// "Próxima manutenção: maio de 2027". With an active contract the date is
  /// the contract's and nothing asks for another one.
  Widget _buildMaintenance(Customer? owner, String? lastService) {
    final contracts = _maintenanceContracts;
    final deviceStream = _maintenanceStream;
    if (contracts == null || deviceStream == null) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<List<Order?>>(
      stream: contracts,
      builder: (context, contractSnapshot) => StreamBuilder<Device?>(
        stream: deviceStream,
        builder: (context, deviceSnapshot) {
          // Waits for both, so a contract's device never flashes "Definir".
          if (!deviceSnapshot.hasData &&
              !deviceSnapshot.hasError &&
              deviceSnapshot.connectionState != ConnectionState.done) {
            return const SizedBox.shrink();
          }
          if (!contractSnapshot.hasData && !contractSnapshot.hasError) {
            return const SizedBox.shrink();
          }
          final contract = contractSnapshot.data
              ?.whereType<Order>()
              .where((order) => order.contract?.isRunning == true)
              .firstOrNull;
          if (contract != null) return _contractMaintenanceRow(contract);
          return _maintenanceRow(deviceSnapshot.data, owner, lastService);
        },
      ),
    );
  }

  Widget _contractMaintenanceRow(Order contract) {
    final l10n = context.l10n;
    final format = FormatService()..setLocale(l10n.localeName);
    final due = contract.contract?.nextDueDate;
    return AppListRow(
      key: const ValueKey('device_maintenance_contract'),
      leading: _maintenanceIcon(),
      title: due == null
          ? l10n.nextMaintenanceByContract
          : l10n.nextMaintenanceOn(format.formatMonthYear(due)),
      subtitle: due == null ? null : l10n.nextMaintenanceByContract,
      onTap: () => Navigator.pushNamed(
        context,
        '/order',
        arguments: {'order': contract},
      ),
    );
  }

  Widget _maintenanceRow(
    Device? device,
    Customer? owner,
    String? lastService,
  ) {
    final l10n = context.l10n;
    final format = FormatService()..setLocale(l10n.localeName);
    final date = device?.nextMaintenance;
    if (date == null && !_canManageDevices) return const SizedBox.shrink();
    return AppListRow(
      key: const ValueKey('device_maintenance'),
      leading: _maintenanceIcon(),
      title: date == null
          ? l10n.nextMaintenanceSet
          : l10n.nextMaintenanceOn(format.formatMonthYear(date)),
      titleStyle: date == null
          ? AppTypography.body.copyWith(
              color: AppColors.accentText.resolveFrom(context),
            )
          : null,
      subtitle: date != null && _canManageDevices
          ? l10n.nextMaintenanceChangeHint
          : null,
      onTap: _canManageDevices
          ? () => _editMaintenance(date, owner, lastService)
          : null,
    );
  }

  Icon _maintenanceIcon() => Icon(
    CupertinoIcons.calendar,
    size: 22,
    color: AppColors.textSecondary.resolveFrom(context),
  );

  /// The row stays on screen behind the sheet: only the first tap opens it.
  Future<void> _editMaintenance(
    DateTime? current,
    Customer? owner,
    String? lastService,
  ) async {
    if (_editingMaintenance) return;
    _editingMaintenance = true;
    final l10n = context.l10n;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final pick = await OrderDateSheet.show(
      context,
      initial: current == null || current.isBefore(today)
          ? addMonths(today, 6)
          : current,
      minimum: today,
      dateOnly: true,
      removeLabel: current == null ? null : l10n.nextMaintenanceRemove,
    );
    _editingMaintenance = false;
    if (pick == null || !mounted) return;
    final saveError = l10n.nextMaintenanceSaveError;
    (widget.saveMaintenance ?? _saveMaintenance)(
      _device!.id!,
      pick.date,
      owner?.toAggr(),
      lastService,
      () {
        if (mounted) showAppToast(context, saveError);
      },
    );
    if (pick.date != null) await resetMaintenanceDeclines();
  }

  void _saveMaintenance(
    String deviceId,
    DateTime? date,
    CustomerAggr? customer,
    String? lastService,
    VoidCallback onFailed,
  ) {
    DeviceMaintenanceService(devices: widget.deviceRepository).save(
      [deviceId],
      date: date,
      customer: customer,
      lastServices: {deviceId: ?lastService},
      onFailed: onFailed,
    );
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
    if (rows.isEmpty) return const [];
    return [SectionLabel(l10n.deviceDetailsLabel), ...rows];
  }

  List<Widget> _customDataRows(SegmentConfigProvider config) {
    final data = _device!.customData;
    if (data == null) return const [];
    final locale = context.l10n.localeName;
    final fields = config.fieldsFor('device');
    final format = FormatService()..setLocale(locale);

    final labelMap = <String, String>{};
    for (final f in fields) {
      final label = f.getLabel(locale);
      labelMap[f.key] = label;
      labelMap[f.fieldName] = label;
    }

    // The reading shows next to the plate/serial at the top.
    final reading = config.readingField;
    return data.entries
        .where((e) => e.value != null && e.value.toString().isNotEmpty)
        .where(
          (e) =>
              reading == null ||
              (e.key != reading.fieldName && e.key != reading.key),
        )
        .map((entry) {
      final label = labelMap[entry.key] ?? entry.key;
      final value = entry.value.toString();
      final field = fields.cast<CustomField?>().firstWhere(
            (f) => f!.key == entry.key || f.fieldName == entry.key,
            orElse: () => null,
          );
      final display = (field != null && field.type == 'select')
          ? field.getOptionLabel(value, locale)
          : formatDeviceNumber(field, entry.value, format) ?? value;
      return AppListRow(title: label, trailing: display);
    }).toList();
  }

  void _openOwner(Customer owner) {
    Navigator.pushNamed(
      context,
      '/customer_detail',
      arguments: {'customer': owner, 'previousTitle': _device?.name},
    );
  }

  Widget _orderRow(Order order, SegmentConfigProvider config) {
    final field = config.readingField;
    final id = _device?.id;
    final reading = field == null || id == null
        ? null
        : formatReading(
            field,
            order.deviceReadings?[id],
            FormatService()..setLocale(context.l10n.localeName),
          );
    return OrderHistoryRow(
      order: order,
      detail: reading,
      showPrices: _showPrices,
      showDate: true,
      statusLabel: config.getStatus,
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
                .where((o) => o.contract?.isRunning == true)
                .toList() ??
            [];
        if (contracts.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        final l10n = context.l10n;
        final format = FormatService()..setLocale(l10n.localeName);
        return SliverList(
          delegate: SliverChildListDelegate([
            SectionLabel(contractsTitleOf(context)),
            for (final order in contracts)
              AppListRow(
                leading: Icon(
                  CupertinoIcons.repeat,
                  size: 18,
                  color: AppColors.textSecondary.resolveFrom(context),
                ),
                title:
                    '${l10n.order}${order.number == null ? '' : ' #${order.number}'} · ${ContractRepeat.describe(context, order.contract)}',
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
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionOutline(
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size.fromHeight(AppSizes.primaryButtonHeight),
        color: AppColors.action.resolveFrom(context),
        borderRadius: BorderRadius.circular(AppRadii.button),
        onPressed: onPressed,
        child: Text(
          label,
          style: AppTypography.bodyStrong.copyWith(
            color: AppColors.onAction.resolveFrom(context),
          ),
        ),
      ),
    );
  }
}
