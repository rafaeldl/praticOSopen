import 'package:flutter/cupertino.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:praticos/constants/label_keys.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/device_store.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/repositories/v2/device_repository_v2.dart';
import 'package:praticos/screens/device_form_screen.dart';
import 'package:praticos/screens/widgets/add_row.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/app_sheet.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/customer_directory.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/status_style.dart';
import 'package:praticos/widgets/cached_image.dart';
import 'package:provider/provider.dart';

/// Vehicles / devices (`/device_list`).
///
/// - **Selection mode** (route argument `order`, from the order): title "Qual
///   é o veículo?", "Cadastrar veículo novo" on top, and, when the order has
///   a customer, a "Veículos da Ana" section first (distinct devices of the
///   customer's orders) followed by "Outros veículos". Tapping a row pops with
///   the [Device]; no swipe, no chevron.
/// - **Settings mode** (from "Mais"): title "Veículos", chevron on every row
///   and swipe to edit / delete (delete needs `manageDevices`).
class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({
    super.key,
    this.devices,
    this.vehiclesOfCustomer,
    this.canManage,
  });

  /// Injected in tests; defaults to the company's device stream.
  final Stream<List<Device?>> Function()? devices;

  /// Injected in tests; defaults to the vehicles of the customer's orders.
  final Future<List<DeviceAggr>> Function(String customerId)?
  vehiclesOfCustomer;

  /// Injected in tests; defaults to the `manageDevices` permission.
  final bool Function()? canManage;

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool _argsRead = false;
  bool _selecting = false;
  String? _customerId;
  String? _customerName;

  Stream<List<Device?>>? _stream;
  Future<List<DeviceAggr>>? _customerVehicles;
  DeviceStore? _store;

  bool get _canManage =>
      widget.canManage?.call() ??
      AuthorizationService.instance.hasPermission(PermissionType.manageDevices);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsRead) return;
    _argsRead = true;
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _selecting = args != null && args.containsKey('order');
    final order = args?['order'];
    if (order is Order) {
      _customerId = order.customer?.id;
      _customerName = order.customer?.name;
    }
    if (widget.devices != null) {
      _stream = widget.devices!();
    } else {
      final companyId = Global.companyAggr?.id;
      _stream = companyId == null
          ? Stream.value(const <Device?>[])
          : DeviceRepositoryV2().streamDevices(companyId);
    }
    if (_selecting && _customerId != null) {
      final load =
          widget.vehiclesOfCustomer ?? FirestoreCustomerDirectory().vehiclesOf;
      // A failure only hides the customer section.
      _customerVehicles = load(_customerId!).catchError((_) => <DeviceAggr>[]);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final device = await AppSheet.show<Device>(
      context,
      (_) => const DeviceFormScreen(asSheet: true),
    );
    if (_selecting && device != null && mounted) {
      Navigator.pop(context, device);
    }
  }

  void _open(Device device, SegmentConfigProvider config) {
    if (_selecting) {
      Navigator.pop(context, device);
    } else if (config.useDeviceManagement) {
      Navigator.pushNamed(
        context,
        '/device_detail',
        arguments: {'device': device},
      );
    } else {
      Navigator.pushNamed(
        context,
        '/device_form',
        arguments: {'device': device},
      );
    }
  }

  bool _matches(Device d) {
    if (_searchQuery.isEmpty) return true;
    return (d.name ?? '').toLowerCase().contains(_searchQuery) ||
        (d.serial ?? '').toLowerCase().contains(_searchQuery) ||
        (d.manufacturer ?? '').toLowerCase().contains(_searchQuery);
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SegmentConfigProvider>();
    final l10n = context.l10n;
    final title = _selecting
        ? l10n.pickDeviceTitle(config.device.toLowerCase())
        : config.devicePlural;
    final background = AppColors.background.resolveFrom(context);

    return CupertinoPageScaffold(
      backgroundColor: background,
      child: Material(
        type: MaterialType.transparency,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            AppNavBar(
              largeTitle: Text(title),
              backgroundColor: background,
              trailing: _selecting
                  ? null
                  : GlassBarButton(
                      label: l10n.add,
                      icon: CupertinoIcons.add,
                      onPressed: _create,
                    ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: CupertinoSearchTextField(
                  controller: _searchController,
                  placeholder: '${l10n.search} ${config.device.toLowerCase()}',
                  onChanged: (value) =>
                      setState(() => _searchQuery = value.toLowerCase()),
                ),
              ),
            ),
            if (_selecting)
              SliverToBoxAdapter(
                child: AddRow(
                  label: l10n.registerNewDevice(config.device.toLowerCase()),
                  onTap: _create,
                ),
              ),
            StreamBuilder<List<Device?>>(
              stream: _stream,
              builder: (context, snapshot) => _buildBody(snapshot, config),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    AsyncSnapshot<List<Device?>> snapshot,
    SegmentConfigProvider config,
  ) {
    final l10n = context.l10n;
    if (snapshot.hasError) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: ErrorState(
          message: '${l10n.errorLoading} ${config.devicePlural.toLowerCase()}',
          onRetry: () => setState(() {
            _argsRead = false;
            didChangeDependencies();
          }),
        ),
      );
    }
    final data = snapshot.data;
    if (data == null) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: LoadingState(),
      );
    }
    final all = data.whereType<Device>().toList();
    if (all.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: config.deviceIcon,
          title: '${l10n.no} ${config.device.toLowerCase()} ${l10n.registered}',
          message:
              '${l10n.tapPlusToAddYourFirst} ${config.device.toLowerCase()}.',
        ),
      );
    }
    final filtered = all.where(_matches).toList();
    if (filtered.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(title: config.label(LabelKeys.noResultsFound)),
      );
    }

    if (!_selecting || _customerVehicles == null) {
      return _rows(filtered, config);
    }
    return FutureBuilder<List<DeviceAggr>>(
      future: _customerVehicles,
      builder: (context, vehicles) {
        final ids = {
          for (final v in vehicles.data ?? const <DeviceAggr>[])
            if (v.id != null) v.id!,
        };
        final mine = filtered.where((d) => ids.contains(d.id)).toList();
        if (mine.isEmpty) return _rows(filtered, config);
        final others = filtered.where((d) => !ids.contains(d.id)).toList();
        final name = (_customerName ?? '').trim().split(RegExp(r'\s+')).first;
        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: SectionLabel(
                l10n.devicesOfCustomer(config.devicePlural, name),
              ),
            ),
            _rows(mine, config),
            if (others.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionLabel(
                  l10n.otherDevicesSection(config.devicePlural.toLowerCase()),
                ),
              ),
              _rows(others, config),
            ],
          ],
        );
      },
    );
  }

  Widget _rows(List<Device> devices, SegmentConfigProvider config) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _row(devices[index], config),
        childCount: devices.length,
      ),
    );
  }

  Widget _row(Device device, SegmentConfigProvider config) {
    final l10n = context.l10n;
    final management = config.useDeviceManagement;
    final subtitleParts = [
      if (device.serial?.isNotEmpty ?? false) l10n.plateValue(device.serial!),
      if (device.manufacturer?.isNotEmpty ?? false) device.manufacturer!,
      if (management && !_selecting)
        DeviceStatusStyle.label(l10n, device.status),
    ];
    final row = AppListRow(
      key: ValueKey('device-${device.id}'),
      leading: _buildDeviceAvatar(device, management),
      title: device.name ?? '',
      subtitle: subtitleParts.isEmpty ? null : subtitleParts.join(' · '),
      showChevron: !_selecting,
      onTap: () => _open(device, config),
    );
    if (_selecting || device.id == null) return row;
    return _swipeable(device, row, config);
  }

  Widget _swipeable(Device device, Widget row, SegmentConfigProvider config) {
    return Dismissible(
      key: Key(device.id!),
      direction: DismissDirection.horizontal,
      background: Container(
        color: AppColors.accent.resolveFrom(context),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Icon(
          CupertinoIcons.pencil,
          color: AppColors.onAccent.resolveFrom(context),
        ),
      ),
      secondaryBackground: Container(
        color: AppColors.danger.resolveFrom(context),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(
          CupertinoIcons.trash,
          color: AppColors.onAccent.resolveFrom(context),
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          Navigator.pushNamed(
            context,
            '/device_form',
            arguments: {'device': device},
          );
          return false;
        }
        if (!_canManage) {
          await showCupertinoDialog(
            context: context,
            builder: (dialogContext) => CupertinoAlertDialog(
              title: Text(context.l10n.noPermission),
              content: Text(context.l10n.noPermissionToRemove),
              actions: [
                CupertinoDialogAction(
                  child: Text(context.l10n.ok),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ],
            ),
          );
          return false;
        }
        return await showCupertinoDialog<bool>(
              context: context,
              builder: (dialogContext) => CupertinoAlertDialog(
                title: Text(config.label(LabelKeys.confirmDeletion)),
                content: Text(
                  '${context.l10n.doYouWantToRemoveThe} ${config.device.toLowerCase()} "${device.name}"?',
                ),
                actions: [
                  CupertinoDialogAction(
                    child: Text(config.label(LabelKeys.cancel)),
                    onPressed: () => Navigator.pop(dialogContext, false),
                  ),
                  CupertinoDialogAction(
                    isDestructiveAction: true,
                    child: Text(config.label(LabelKeys.remove)),
                    onPressed: () => Navigator.pop(dialogContext, true),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => (_store ??= DeviceStore()).deleteDevice(device),
      child: Container(
        color: AppColors.background.resolveFrom(context),
        child: row,
      ),
    );
  }

  Widget _buildDeviceAvatar(Device device, bool management) {
    final Widget avatar;
    if (device.photo != null && device.photo!.isNotEmpty) {
      avatar = CachedImage(
        imageUrl: device.photo!,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
      );
    } else {
      avatar = Container(
        color: AppColors.secondaryFill.resolveFrom(context),
        alignment: Alignment.center,
        child: Icon(
          context.read<SegmentConfigProvider>().deviceIcon,
          color: AppColors.textSecondary.resolveFrom(context),
        ),
      );
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.field),
          child: SizedBox(width: 44, height: 44, child: avatar),
        ),
        if (management && !_selecting)
          Positioned(
            right: -2,
            bottom: -2,
            child: StatusDot(color: DeviceStatusStyle.dotColor(device.status)),
          ),
      ],
    );
  }
}
