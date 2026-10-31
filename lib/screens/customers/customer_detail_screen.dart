import 'package:flutter/cupertino.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/device_form_screen.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/receipt.dart';
import 'package:praticos/repositories/tenant/tenant_receipt_repository.dart';
import 'package:praticos/screens/nfse/nfse_access.dart';
import 'package:praticos/screens/nfse/nfse_list_screen.dart';
import 'package:praticos/screens/nfse/nfse_issue_sheet.dart';
import 'package:praticos/screens/nfse/nfse_orders_picker.dart';
import 'package:praticos/screens/payments/receipt_detail_screen.dart';
import 'package:praticos/screens/payments/receive_customer_screen.dart';
import 'package:praticos/screens/widgets/add_row.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/app_toast.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/order_history_row.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/customer_directory.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/utils/customer_utils.dart';
import 'package:praticos/utils/financial_summary.dart';
import 'package:praticos/utils/phone_format.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:praticos/models/permission.dart';

/// Customer screen (`/customer_detail`, arguments `customer` and optionally
/// `previousTitle`, the label of the back button): phone with "gastou R$ X"
/// and, with the view-prices permission, "Falta receber R$ X" (what is
/// still open on the customer's orders) plus the "· Receber" link when the
/// person can receive on at least one open order (financial access: all of
/// them; a consultant: only their own). It opens "Receber de Ana" or, with
/// one such order, its Receber; call / WhatsApp, "Nova OS para Ana", the
/// customer's vehicles (with "Cadastrar outro veículo"), the latest orders
/// and, with financial access, the customer's "Recebimentos" (payments that
/// covered several orders; each opens [ReceiptDetailScreen]).
/// Edit and delete live in the "…" menu.
class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({
    super.key,
    this.customer,
    this.directory,
    this.showPrices,
    this.canReceiveOn,
    this.canSeeReceipts,
    this.onReceive,
    this.receipts,
    this.onOpenReceipt,
    this.nfse,
    this.can,
  });

  /// Falls back to the `customer` route argument.
  final Customer? customer;

  /// Injected in tests; defaults to [FirestoreCustomerDirectory].
  final CustomerDirectory? directory;

  /// Order totals and "gastou". Defaults to the `viewPrices`
  /// permission, which is off for everyone when the company does not use
  /// values and billing (`Company.useFinancial == false`).
  final bool? showPrices;

  /// Whether the person can receive on an order. Defaults to
  /// [AuthorizationService.canReceiveOnOrder]: financial access receives on
  /// any order, a consultant only on the orders they created. Test seam.
  final bool Function(Order order)? canReceiveOn;

  /// The customer's "Recebimentos". Defaults to financial access
  /// (`viewFinancialReports`): the list has every receipt of the customer,
  /// and a consultant only reads the ones they registered. Test seam.
  final bool? canSeeReceipts;

  /// "Receber" next to "Falta receber R$ X", with the customer's open
  /// orders the person can receive on (oldest first). Defaults to the order's Receber (one order) or
  /// [ReceiveCustomerScreen] (several). Test seam.
  final void Function(BuildContext context, List<Order> openOrders)? onReceive;

  /// Active receipts of the customer. Defaults to
  /// [TenantReceiptRepository.watchActiveOfCustomer]. Test seam.
  final Stream<List<Receipt>>? receipts;

  /// Opens a receipt. Defaults to [ReceiptDetailScreen.open]. Test seam.
  final void Function(BuildContext context, Receipt receipt)? onOpenReceipt;

  /// Notas fiscais of the customer (tests); defaults to a new
  /// [NfseController] that stays off unless the company has `nfseEnabled`.
  final NfseController? nfse;

  /// Permission check (edit/delete need `manageCustomers`, a new vehicle
  /// `manageDevices`: the Firestore rules deny them otherwise). Defaults to
  /// [AuthorizationService.hasPermission]. Test seam.
  final bool Function(PermissionType permission)? can;

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late final CustomerDirectory _directory =
      widget.directory ?? FirestoreCustomerDirectory();
  Customer? _customer;
  String? _previousTitle;
  Stream<List<Order>>? _orders;
  Stream<List<Receipt>>? _receipts;

  late final NfseController _nfse = widget.nfse ?? NfseController();

  /// Last orders shown (the "…" menu picks from them).
  List<Order> _lastOrders = const [];

  void _onNfse() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _nfse.addListener(_onNfse);
  }

  @override
  void dispose() {
    _nfse.removeListener(_onNfse);
    if (widget.nfse == null) _nfse.dispose();
    super.dispose();
  }

  bool _can(PermissionType permission) =>
      widget.can?.call(permission) ??
      AuthorizationService.instance.hasPermission(permission);

  bool get _showPrices =>
      widget.showPrices ?? AuthorizationService.instance.canViewPrices;

  bool get _canSeeReceipts =>
      widget.canSeeReceipts ??
      AuthorizationService.instance.canViewFinancialReports;

  bool _canReceiveOn(Order order) =>
      widget.canReceiveOn?.call(order) ??
      AuthorizationService.instance.canReceiveOnOrder(order);

  /// Open orders (oldest first) the person can receive on. A consultant
  /// only gets their own, even if the stream brings others.
  List<Order> _receivable(List<Order> orders) =>
      FinancialSummary.openOrdersOldestFirst(
        orders,
      ).where(_canReceiveOn).toList();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_customer != null) return;
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _customer = widget.customer ?? args?['customer'] as Customer?;
    _previousTitle = args?['previousTitle'] as String?;
    _loadOrders();
    _receipts = _receiptsStream();
    _nfse.watchCustomer(_customer?.id);
  }

  /// Only with financial access (the rules deny the rest).
  Stream<List<Receipt>>? _receiptsStream() {
    if (widget.receipts != null) return widget.receipts;
    final companyId = Global.companyAggr?.id;
    final id = _customer?.id;
    if (companyId == null || id == null || !_canSeeReceipts) return null;
    return TenantReceiptRepository().watchActiveOfCustomer(companyId, id);
  }

  void _loadOrders() {
    final id = _customer?.id;
    setState(() {
      _orders = id == null
          ? Stream.value(const <Order>[])
          : _directory.watchOrdersOf(id);
    });
  }

  String get _firstName =>
      (_customer?.name ?? '').trim().split(RegExp(r'\s+')).first;

  Future<void> _call() => launchUrl(
    Uri(
      scheme: 'tel',
      path: _customer!.phone!.replaceAll(RegExp(r'[^\d+]'), ''),
    ),
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

  /// Same gate as the order's Receber ([_canReceiveOn]); with one such
  /// order it goes straight to that order's Receber.
  Future<void> _receive(List<Order> orders) async {
    final open = _receivable(orders);
    if (open.isEmpty) return;
    final receive = widget.onReceive;
    if (receive != null) {
      receive(context, open);
      return;
    }
    if (open.length == 1) {
      await Navigator.pushNamed(
        context,
        '/payment_management',
        arguments: {'orderStore': OrderStore()..setOrder(open.first)},
      );
      return;
    }
    await ReceiveCustomerScreen.open(
      context,
      orders: open,
      customer: _customer?.toAggr(),
      customerName: _customer?.name,
    );
  }

  Future<void> _addDevice() async {
    final created = await FormSheet.show<Device>(
      context,
      (_) => const DeviceFormScreen(asSheet: true),
    );
    if (created == null || !mounted) return;
    Navigator.pushNamed(
      context,
      '/device_detail',
      arguments: {
        'device': created,
        'customer': _customer,
        'previousTitle': _customer?.name,
      },
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

  /// "Emitir uma nota com várias OS": picks orders of this customer that
  /// can have a nota and have none, then the issue sheet.
  Future<void> _issueSeveralNfse() async {
    if (!_nfse.ready) {
      await showNfseNotReady(context, sandbox: _nfse.sandbox);
      return;
    }
    final invoiced = _nfse.invoicedOrderIds;
    final eligible = [
      for (final o in _lastOrders)
        if (orderCanHaveNfse(o) && !invoiced.contains(o.id)) o,
    ];
    final l10n = context.l10n;
    if (eligible.isEmpty) {
      showAppToast(context, l10n.nfseNoOrdersToPick);
      return;
    }
    final ids = await NfseOrdersPicker.open(
      context,
      orders: eligible,
      previousTitle: _customer?.name,
    );
    if (ids == null || ids.isEmpty || !mounted) return;
    final invoice = await NfseIssueSheet.show(
      context,
      orderIds: ids,
      customerId: _customer?.id,
      sandbox: _nfse.sandbox,
    );
    if (invoice != null && mounted) {
      showAppToast(
        context,
        l10n.nfseSent,
        icon: CupertinoIcons.checkmark_circle,
      );
    }
  }

  void _showMenu() {
    final l10n = context.l10n;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          if (_nfse.enabled)
            CupertinoActionSheetAction(
              key: const Key('customerNfseSeveral'),
              onPressed: () {
                Navigator.pop(sheetContext);
                _issueSeveralNfse();
              },
              child: Text(l10n.nfseIssueSeveralAction),
            ),
          if (_can(PermissionType.manageCustomers)) ...[
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
    final config = context.watch<SegmentConfigProvider>();

    return CupertinoPageScaffold(
      backgroundColor: background,
      child: StreamBuilder<List<Order>>(
        stream: _orders,
        builder: (context, snapshot) {
          final orders = snapshot.data;
          if (orders != null) _lastOrders = orders;
          return CustomScrollView(
            slivers: [
              AppNavBar(
                largeTitle: Text(customer.name ?? ''),
                previousTitle: _previousTitle ?? config.customerPlural,
                trailing: _nfse.enabled || _can(PermissionType.manageCustomers)
                    ? GlassBarButton(
                        label: l10n.customerActions,
                        icon: CupertinoIcons.ellipsis,
                        onPressed: _showMenu,
                      )
                    : null,
              ),
              ..._buildHeader(customer, orders),
              if (snapshot.hasError)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: ErrorState(onRetry: _loadOrders),
                  ),
                )
              else if (orders == null)
                const SliverToBoxAdapter(
                  child: SizedBox(height: 120, child: LoadingState()),
                )
              else
                SliverList(
                  delegate: SliverChildListDelegate(
                    _buildOrderSections(orders),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildHeader(Customer customer, List<Order>? orders) {
    final l10n = context.l10n;
    final hasPhone = customer.phone?.isNotEmpty ?? false;
    final format = FormatService()..setLocale(l10n.localeName);
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final spent = orders == null ? 0.0 : totalSpent(orders);
    final owed = orders == null ? 0.0 : customerOwed(orders);
    final infoLines = [
      [
        if (hasPhone) formatPhone(customer.phone),
        if (_showPrices && spent > 0)
          l10n.customerSpentValue(format.formatCurrency(spent)),
      ].join(' · '),
    ].where((line) => line.isNotEmpty).toList();
    final owes = _showPrices && owed > 0;

    return [
      if (infoLines.isNotEmpty || owes)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageMargin,
              0,
              AppSpacing.pageMargin,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in infoLines)
                  Text(
                    line,
                    style: AppTypography.callout.copyWith(color: secondary),
                  ),
                if (owes) _owedLine(format.formatCurrency(owed), orders!),
              ],
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  l10n.askOrderForCustomer(_firstName),
                  style: AppTypography.callout.copyWith(color: secondary),
                ),
              ),
              _PrimaryButton(
                label: l10n.newOrderFor(_firstName),
                onPressed: _newOrder,
              ),
            ],
          ),
        ),
      ),
    ];
  }

  /// "Falta receber R$ 1.250 · Receber" (the link opens the payment).
  Widget _owedLine(String owed, List<Order> orders) {
    final secondary = AppColors.textSecondary.resolveFrom(context);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          context.l10n.customerOwesValue(owed),
          key: const Key('customerOwes'),
          style: AppTypography.callout.copyWith(
            color: secondary,
            fontFeatures: AppTypography.tabular,
          ),
        ),
        if (_receivable(orders).isNotEmpty) ...[
          Text(' · ', style: AppTypography.callout.copyWith(color: secondary)),
          CupertinoButton(
            key: const Key('customerReceive'),
            padding: EdgeInsets.zero,
            minimumSize: const Size(
              AppSizes.minTouchTarget,
              AppSizes.minTouchTarget,
            ),
            onPressed: () => _receive(orders),
            child: Text(
              context.l10n.receiveTitle,
              style: AppTypography.callout.copyWith(
                color: AppColors.accentText.resolveFrom(context),
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildOrderSections(List<Order> orders) {
    final l10n = context.l10n;
    final config = context.watch<SegmentConfigProvider>();
    final vehicles = distinctVehicles(orders);
    final name = _firstName;

    return [
      SectionLabel(l10n.devicesOfCustomer(config.devicePlural, name)),
      for (final v in vehicles) _vehicleRow(v, orders),
      if (_can(PermissionType.manageDevices))
        AddRow(
          label: l10n.addAnotherDevice(config.device.toLowerCase()),
          onTap: _addDevice,
        ),
      ?_nfseRow(),
      if (orders.isNotEmpty) ...[
        SectionLabel(l10n.latestOrders),
        for (final o in orders) _orderRow(o),
      ],
      if (_receipts != null && _canSeeReceipts) _receiptsSection(),
    ];
  }

  /// "Notas fiscais · 5": opens the notas of this customer. Only with notas.
  Widget? _nfseRow() {
    final invoices = _nfse.invoices;
    if (!_nfse.enabled || invoices.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: AppListRow(
        key: const Key('customerNfse'),
        title: context.l10n.nfseListTitle,
        trailing: '${invoices.where((invoice) => invoice.isIssued).length}',
        onTap: () => NfseListScreen.open(
          context,
          customerId: _customer?.id,
          customerName: _customer?.name,
        ),
      ),
    );
  }

  /// "Recebimentos": one row per active receipt ("R$ 700" / "14/10 · 2 OS").
  Widget _receiptsSection() {
    return StreamBuilder<List<Receipt>>(
      stream: _receipts,
      builder: (context, snapshot) {
        final receipts = snapshot.data ?? const <Receipt>[];
        if (receipts.isEmpty) return const SizedBox.shrink();
        final l10n = context.l10n;
        final format = FormatService();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionLabel(l10n.receiptsSection),
            for (final r in receipts)
              AppListRow(
                key: Key('customerReceipt_${r.id}'),
                title: format.formatCurrency(r.amount ?? 0),
                subtitle: l10n.receiptListSubtitle(
                  format.formatDate(r.paidAt ?? r.createdAt ?? DateTime.now()),
                  r.allocations?.length ?? 0,
                ),
                onTap: () {
                  final open = widget.onOpenReceipt;
                  if (open != null) {
                    open(context, r);
                  } else if (r.id != null) {
                    ReceiptDetailScreen.open(context, receiptId: r.id!);
                  }
                },
              ),
          ],
        );
      },
    );
  }

  Widget _vehicleRow(DeviceAggr vehicle, List<Order> orders) {
    final l10n = context.l10n;
    final parts = [
      if (vehicle.serial?.isNotEmpty ?? false) l10n.plateValue(vehicle.serial!),
      l10n.orderCountShort(orderCountForDevice(orders, vehicle.id)),
    ];
    return AppListRow(
      title: vehicle.name ?? '',
      subtitle: parts.join(' · '),
      onTap: () => Navigator.pushNamed(
        context,
        '/device_detail',
        arguments: {
          'device': Device.fromJson(vehicle.toJson()),
          'customer': _customer,
          'previousTitle': _customer?.name,
        },
      ),
    );
  }

  Widget _orderRow(Order order) {
    return OrderHistoryRow(
      order: order,
      showPrices: _showPrices,
      onTap: () => Navigator.pushNamed(
        context,
        '/order',
        arguments: {'order': order, 'previousTitle': _customer?.name},
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
