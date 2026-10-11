import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/customer_directory.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/theme/status_style.dart';
import 'package:praticos/utils/customer_utils.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Customer screen (`/customer_detail`, argument `customer`): call / WhatsApp,
/// "Nova OS para Ana", the customer's vehicles and orders, and "Total gasto"
/// (sum of the completed orders) and, with the view-prices permission, "Falta
/// receber" (what is still open on the customer's orders). Edit and delete live in the "…" menu.
class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({
    super.key,
    this.customer,
    this.directory,
    this.showPrices,
  });

  /// Falls back to the `customer` route argument.
  final Customer? customer;

  /// Injected in tests; defaults to [FirestoreCustomerDirectory].
  final CustomerDirectory? directory;

  /// Order totals and "Total gasto". Defaults to the `viewPrices`
  /// permission, which is off for everyone when the company does not use
  /// values and billing (`Company.useFinancial == false`).
  final bool? showPrices;

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late final CustomerDirectory _directory =
      widget.directory ?? FirestoreCustomerDirectory();
  Customer? _customer;
  Stream<List<Order>>? _orders;

  bool get _showPrices =>
      widget.showPrices ?? AuthorizationService.instance.canViewPrices;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_customer != null) return;
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _customer = widget.customer ?? args?['customer'] as Customer?;
    _loadOrders();
  }

  void _loadOrders() {
    final id = _customer?.id;
    setState(() {
      _orders = id == null ? Stream.value(const <Order>[]) : _directory.watchOrdersOf(id);
    });
  }

  String get _firstName =>
      (_customer?.name ?? '').trim().split(RegExp(r'\s+')).first;

  Future<void> _call() => launchUrl(
        Uri(scheme: 'tel', path: _customer!.phone!.replaceAll(RegExp(r'[^\d+]'), '')),
      );

  Future<void> _whatsapp() => launchUrl(
        Uri.parse('https://wa.me/${whatsappNumber(_customer!.phone!)}'),
        mode: LaunchMode.externalApplication,
      );

  void _newOrder() {
    Navigator.pushNamed(
      context,
      '/order',
      arguments: {'order': Order()..customer = _customer!.toAggr()},
    );
  }

  Future<void> _edit() async {
    await Navigator.pushNamed(
      context,
      '/customer_form',
      arguments: {'customer': _customer},
    );
    if (mounted) setState(() {});
  }

  Future<void> _confirmDelete() async {
    final l10n = context.l10n;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(l10n.deleteCustomerTitle(_customer?.name ?? '')),
        content: Text(l10n.deleteCustomerKeepsOrders),
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
    await _directory.deleteCustomer(_customer!);
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

  @override
  Widget build(BuildContext context) {
    final customer = _customer;
    final l10n = context.l10n;
    final background = AppColors.background.resolveFrom(context);
    if (customer == null) {
      return CupertinoPageScaffold(
        backgroundColor: background,
        navigationBar: const CupertinoNavigationBar(),
        child: const SizedBox.shrink(),
      );
    }
    final hasPhone = customer.phone?.isNotEmpty ?? false;

    return CupertinoPageScaffold(
      backgroundColor: background,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(customer.name ?? ''),
            backgroundColor: background,
            border: null,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 44),
              onPressed: _showMenu,
              child: Semantics(
                label: l10n.customerActions,
                child: const Icon(CupertinoIcons.ellipsis_circle),
              ),
            ),
          ),
          if (hasPhone)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageMargin, 0, AppSpacing.pageMargin, AppSpacing.md,
                ),
                child: Text(
                  customer.phone!,
                  style: AppTypography.callout.copyWith(
                    color: AppColors.textSecondary.resolveFrom(context),
                  ),
                ),
              ),
            ),
          if (hasPhone)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.blockMargin,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _SecondaryButton(
                        icon: CupertinoIcons.phone,
                        label: l10n.callAction,
                        onPressed: _call,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _SecondaryButton(
                        icon: CupertinoIcons.chat_bubble_text,
                        label: l10n.whatsapp,
                        onPressed: _whatsapp,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.blockMargin,
                AppSpacing.lg,
                AppSpacing.blockMargin,
                0,
              ),
              child: _PrimaryButton(
                label: l10n.newOrderFor(_firstName),
                onPressed: _newOrder,
              ),
            ),
          ),
          StreamBuilder<List<Order>>(
            stream: _orders,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: ErrorState(onRetry: _loadOrders),
                  ),
                );
              }
              final orders = snapshot.data;
              if (orders == null) {
                return const SliverToBoxAdapter(
                  child: SizedBox(height: 120, child: LoadingState()),
                );
              }
              return SliverList(
                delegate: SliverChildListDelegate(_buildOrderSections(orders)),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  List<Widget> _buildOrderSections(List<Order> orders) {
    if (orders.isEmpty) return const [];
    final l10n = context.l10n;
    final config = context.watch<SegmentConfigProvider>();
    final format = FormatService()..setLocale(l10n.localeName);
    final vehicles = distinctVehicles(orders);
    final name = _firstName;

    return [
      if (vehicles.isNotEmpty) ...[
        SectionLabel(l10n.devicesOfCustomer(config.devicePlural, name)),
        for (final v in vehicles) _vehicleRow(v),
      ],
      SectionLabel(l10n.ordersOfCustomer(name)),
      for (final o in orders) _orderRow(o, format),
      if (_showPrices && customerOwed(orders) > 0)
        _TotalLine(
          label: l10n.financialToReceive,
          value: format.formatCurrency(customerOwed(orders)),
        ),
      if (_showPrices)
        _TotalLine(
          label: l10n.totalSpent,
          value: format.formatCurrency(totalSpent(orders)),
        ),
    ];
  }

  Widget _vehicleRow(DeviceAggr vehicle) {
    final l10n = context.l10n;
    final parts = [
      if (vehicle.serial?.isNotEmpty ?? false) l10n.plateValue(vehicle.serial!),
      if (vehicle.manufacturer?.isNotEmpty ?? false) vehicle.manufacturer!,
    ];
    return AppListRow(
      title: vehicle.name ?? '',
      subtitle: parts.isEmpty ? null : parts.join(' · '),
      onTap: () => Navigator.pushNamed(
        context,
        '/device_detail',
        arguments: {
          'device': Device.fromJson(vehicle.toJson()),
          'customer': _customer,
        },
      ),
    );
  }

  Widget _orderRow(Order order, FormatService format) {
    final l10n = context.l10n;
    final isOpen = order.status == 'approved' || order.status == 'progress';
    final late = isOpen &&
        order.dueDate != null &&
        order.dueDate!.isBefore(DateTime.now());
    final dotColor =
        late ? OrderStatusStyle.overdueColor : OrderStatusStyle.dotColor(order.status);
    final statusText = late
        ? l10n.orderOverdue
        : OrderStatusStyle.label(l10n, order.status);
    final device = order.devices?.isNotEmpty == true
        ? order.devices!.first.name
        : order.device?.name;
    final number = order.number == null ? '' : ' #${order.number}';

    return AppListRow(
      leading: StatusDot(color: dotColor),
      title: [
        '${l10n.order}$number',
        if (device?.isNotEmpty ?? false) device!,
      ].join(' · '),
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
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = AppColors.text.resolveFrom(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.pageMargin, AppSpacing.lg, AppSpacing.pageMargin, 0,
      ),
      padding: const EdgeInsets.only(top: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: text, width: 2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodyStrong.copyWith(color: text),
            ),
          ),
          Text(
            value,
            style: AppTypography.bodyStrong.copyWith(
              color: text,
              fontFeatures: AppTypography.tabular,
            ),
          ),
        ],
      ),
    );
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

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final text = AppColors.onSecondaryFill.resolveFrom(context);
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      minimumSize: const Size.fromHeight(48),
      color: AppColors.secondaryFill.resolveFrom(context),
      borderRadius: BorderRadius.circular(AppRadii.button),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: text),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              label,
              style: AppTypography.callout.copyWith(color: text),
            ),
          ),
        ],
      ),
    );
  }
}
