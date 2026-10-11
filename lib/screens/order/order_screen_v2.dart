import 'package:flutter/cupertino.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart' show runInAction;
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_form.dart' as of_model;
import 'package:praticos/models/product.dart';
import 'package:praticos/models/service.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/catalog/catalog_source.dart';
import 'package:praticos/screens/customers/customer_list_screen.dart'
    show CustomerPick;
import 'package:praticos/screens/order/order_item_search_screen.dart';
import 'package:praticos/screens/order/order_item_sheet.dart';
import 'package:praticos/screens/order/order_screen_services.dart';
import 'package:praticos/screens/widgets/add_row.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/app_sheet.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/theme/status_style.dart';
import 'package:praticos/utils/order_items.dart';
import 'package:praticos/widgets/cached_image.dart';
import 'package:provider/provider.dart';

/// Redesigned order screen (phase 1, manual, no AI yet), behind the local
/// switch "Nova tela da OS" (see `OrderRoute`).
///
/// - **New order** opens the order itself, blank: "Quem é o cliente?" (plate
///   search picks customer and vehicle), "O que vai na OS?" (one search over
///   services and products; tapping adds), status and totals. Nothing is
///   written until "Salvar OS" (`OrderStore.deferSave`).
/// - **Existing order**: status with [StatusDot], next step by status (the
///   only blue button), customer/vehicle, items, totals and a "…" menu with
///   three groups: "Adicionar à OS", "Mandar para o cliente" · PDF, and
///   "Cancelar OS" / "Apagar OS". Changes save right away, like today.
/// - Items without price are `null`: they show "sem valor" and are not summed.
/// - No cover photo; photos show in "Fotos" only when the order has them.
/// - Foto / "Falar o que fazer" are placeholders for the assistant (hidden
///   unless [showAssistant]).
class OrderScreenV2 extends StatefulWidget {
  const OrderScreenV2({
    super.key,
    this.store,
    this.permissions,
    this.actions,
    this.catalogSource,
    this.catalogPermissions,
    this.mostUsed,
    this.showAssistant = false,
  });

  /// Injected in tests; defaults to a new [OrderStore].
  final OrderStore? store;
  final OrderPermissions? permissions;
  final OrderScreenActions? actions;

  /// Passed to "O que vai na OS?" (tests).
  final CatalogSource? catalogSource;
  final CatalogPermissions? catalogPermissions;
  final Future<List<String>> Function()? mostUsed;

  /// Shows the disabled Foto / Falar placeholders (assistant comes later).
  final bool showAssistant;

  @override
  State<OrderScreenV2> createState() => _OrderScreenV2State();
}

class _NextStep {
  const _NextStep(this.sentence, [this.actionLabel, this.onAction]);

  final String sentence;
  final String? actionLabel;
  final VoidCallback? onAction;
}

class _OrderScreenV2State extends State<OrderScreenV2> {
  late final OrderStore _store = widget.store ?? OrderStore();
  late final OrderPermissions _permissions =
      widget.permissions ?? OrderPermissions.current();
  late final OrderScreenActions _actions =
      widget.actions ?? const OrderScreenActions();

  bool _argsRead = false;
  bool _ready = false;
  bool _isNew = true;

  /// Set after "Sair sem salvar?" so the route can pop.
  bool _leaving = false;

  FormatService get _format =>
      FormatService()..setLocale(context.l10n.localeName);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsRead) return;
    _argsRead = true;
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final order = args?['order'] as Order?;
    if (order != null && (order.id != null || order.number != null)) {
      _isNew = false;
      _loadExisting(order);
    } else {
      _startNew(order);
    }
  }

  void _startNew(Order? prefill) {
    _store.deferSave = true;
    _store.loadOrder();
    final customer = prefill?.customer;
    final devices = prefill?.effectiveDevices ?? const <DeviceAggr>[];
    if (customer != null || devices.isNotEmpty) {
      runInAction(() {
        final order = _store.order!;
        if (customer != null) {
          order.customer = customer;
          _store.customer = customer;
        }
        for (final d in devices) {
          _store.addDevice(Device.fromJson(d.toJson()));
        }
        order.syncDeviceIds();
      });
    }
    _ready = true;
  }

  Future<void> _loadExisting(Order order) async {
    final companyId = _store.companyId;
    Order? fresh;
    if (companyId != null) {
      try {
        fresh = order.id != null
            ? await _store.repository.getSingle(companyId, order.id!)
            : await _store.repository.getOrderByNumber(companyId, order.number!);
      } catch (_) {
        // Shows what came in the arguments.
      }
    }
    if (!mounted) return;
    _store.setOrder(fresh ?? order);
    setState(() => _ready = true);
  }

  Future<void> _reload() async {
    final order = _store.order;
    if (order?.id == null) return;
    await _loadExisting(order!);
  }

  bool get _hasContent =>
      _store.customer != null ||
      _store.devices.isNotEmpty ||
      (_store.services?.isNotEmpty ?? false) ||
      (_store.products?.isNotEmpty ?? false);

  // ─── Customer and vehicle ────────────────────────────────────────────────

  Future<void> _pickCustomer() async {
    final result = await Navigator.pushNamed(
      context,
      '/customer_list',
      arguments: {'order': _store.order},
    );
    if (!mounted || result is! CustomerPick) return;
    _store.setCustomer(result.customer);
    if (result.device != null) _store.addDevice(result.device!);
    setState(() {});
  }

  Future<void> _addDevice() async {
    final result = await Navigator.pushNamed(
      context,
      '/device_list',
      arguments: {'order': _store.order},
    );
    if (!mounted || result is! Device) return;
    _store.addDevice(result);
  }

  Future<void> _changeDevice(DeviceAggr device) async {
    final l10n = context.l10n;
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(device.name ?? ''),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'change'),
            child: Text(l10n.orderDeviceActionChange),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, 'remove'),
            child: Text(l10n.orderDeviceActionRemove),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.cancel),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'remove' && device.id != null) {
      _store.removeDevice(device.id!);
      return;
    }
    if (choice != 'change') return;
    final result = await Navigator.pushNamed(
      context,
      '/device_list',
      arguments: {'order': _store.order},
    );
    if (!mounted || result is! Device || device.id == null) return;
    _store.removeDevice(device.id!);
    _store.addDevice(result);
  }

  // ─── Items ───────────────────────────────────────────────────────────────

  Future<void> _addItem() async {
    final pick = await Navigator.of(context).push<OrderItemPick>(
      CupertinoPageRoute(
        builder: (_) => OrderItemSearchScreen(
          source: widget.catalogSource,
          permissions: widget.catalogPermissions,
          mostUsed: widget.mostUsed,
        ),
      ),
    );
    if (!mounted || pick == null) return;
    addPickToOrder(_store, pick);
  }

  Future<void> _editService(int index) async {
    final item = _store.services![index];
    final edit = await AppSheet.show<OrderItemEdit>(
      context,
      (_) => OrderItemSheet(
        name: _serviceName(item),
        value: item.value,
        showPrice: _permissions.canViewPrices(),
      ),
    );
    if (!mounted || edit == null) return;
    if (edit.remove) {
      _store.deleteService(index);
      return;
    }
    item.value = edit.value;
    _store.updateOrder();
  }

  Future<void> _editProduct(int index) async {
    final item = _store.products![index];
    final edit = await AppSheet.show<OrderItemEdit>(
      context,
      (_) => OrderItemSheet(
        name: _productName(item),
        value: item.value,
        quantity: item.quantity ?? 1,
        showPrice: _permissions.canViewPrices(),
      ),
    );
    if (!mounted || edit == null) return;
    if (edit.remove) {
      _store.deleteProduct(index);
      return;
    }
    item
      ..value = edit.value
      ..quantity = edit.quantity
      ..total = edit.value == null ? null : edit.value! * edit.quantity;
    _store.updateOrder();
  }

  String _serviceName(OrderService s) =>
      s.service?.name ?? s.description ?? '';

  String _productName(OrderProduct p) =>
      p.product?.name ?? p.description ?? '';

  // ─── Status ──────────────────────────────────────────────────────────────

  Future<void> _alert(String title, [String? message]) {
    final l10n = context.l10n;
    return showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  Future<void> _selectStatus() async {
    final order = _store.order;
    if (order == null) return;
    final l10n = context.l10n;
    final config = context.read<SegmentConfigProvider>();
    final statuses = _permissions.availableStatuses(order);
    if (statuses.isEmpty) {
      await _alert(l10n.permissionDenied);
      return;
    }
    final picked = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(l10n.changeStatus),
        actions: [
          for (final key in statuses)
            CupertinoActionSheetAction(
              isDestructiveAction: key == 'canceled',
              onPressed: () => Navigator.pop(ctx, key),
              child: Text(config.getStatus(key)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.cancel),
        ),
      ),
    );
    if (picked != null && mounted) await _trySetStatus(picked);
  }

  Future<void> _trySetStatus(String status) async {
    final order = _store.order;
    if (order == null) return;
    final l10n = context.l10n;
    if (!_permissions.canChangeStatus(order, status)) {
      await _alert(l10n.permissionDenied);
      return;
    }
    if (status == 'done') {
      final forms = _store.formsStream?.value ?? const <of_model.OrderForm>[];
      final pending =
          forms.where((f) => f.status != of_model.FormStatus.completed).length;
      if (pending > 0) {
        await _alert(l10n.orderPendingChecklists(pending));
        return;
      }
    }
    if (status == 'canceled' && !await _confirmCancel()) return;
    _store.setStatus(status);
  }

  Future<bool> _confirmCancel() async {
    final l10n = context.l10n;
    final orderLabel = context.read<SegmentConfigProvider>().serviceOrder;
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(l10n.orderCancelConfirmTitle(orderLabel)),
        content: Text(l10n.orderCancelConfirmMessage),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.back),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.orderMenuCancel(orderLabel)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  // ─── "…" menu ────────────────────────────────────────────────────────────

  Future<void> _showMenu() async {
    final order = _store.order;
    if (order == null) return;
    final l10n = context.l10n;
    final config = context.read<SegmentConfigProvider>();
    final orderLabel = config.serviceOrder;
    final canCancel = _store.status != 'canceled' &&
        _permissions.canChangeStatus(order, 'canceled');
    final canDelete = order.id != null && _permissions.canDelete(order);
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          // 1. Adicionar à OS ›
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'add'),
            child: Text('${l10n.orderMenuAddTo(orderLabel)} ›'),
          ),
          // 2. Mandar para o cliente · PDF
          if (order.id != null)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, 'send'),
              child: Text(l10n.orderMenuSendToCustomer),
            ),
          if (_permissions.canViewPrices())
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, 'pdf'),
              child: Text(l10n.orderMenuPdf),
            ),
          // 3. Cancelar OS / Apagar OS
          if (canCancel)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: Text(l10n.orderMenuCancel(orderLabel)),
            ),
          if (canDelete)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx, 'delete'),
              child: Text(l10n.orderMenuDelete(orderLabel)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.cancel),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'add':
        await _showAddToOrder();
      case 'send':
        await _actions.shareWithCustomer(context, order);
      case 'pdf':
        await _actions.sharePdf(context, order, config);
      case 'cancel':
        await _trySetStatus('canceled');
      case 'delete':
        await _confirmDelete();
    }
  }

  Future<void> _showAddToOrder() async {
    final l10n = context.l10n;
    final config = context.read<SegmentConfigProvider>();
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(l10n.orderMenuAddTo(config.serviceOrder)),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'due'),
            child: Text(l10n.orderAddDueDate),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'device'),
            child: Text(l10n.orderAddAnotherDevice(config.device)),
          ),
          if (_store.order?.id != null)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, 'more'),
              child: Text(l10n.orderAddMore),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.cancel),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'due':
        await _pickDueDate();
      case 'device':
        await _addDevice();
      case 'more':
        await _actions.openCompleteScreen(context, _store.order!);
        if (mounted) await _reload();
    }
  }

  Future<void> _pickDueDate() async {
    var picked = _store.order?.dueDate ?? DateTime.now();
    final l10n = context.l10n;
    final ok = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => Container(
        height: 300,
        color: AppColors.surface.resolveFrom(ctx),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: CupertinoButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l10n.save),
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  initialDateTime: picked,
                  mode: CupertinoDatePickerMode.dateAndTime,
                  use24hFormat: true,
                  onDateTimeChanged: (d) => picked = d,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true && mounted) {
      _store.setDueDate(picked);
      setState(() {});
    }
  }

  Future<void> _confirmDelete() async {
    final l10n = context.l10n;
    final orderLabel = context.read<SegmentConfigProvider>().serviceOrder;
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(l10n.orderDeleteConfirmTitle(orderLabel)),
        content: Text(l10n.orderDeleteConfirmMessage),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.back),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.orderMenuDelete(orderLabel)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _store.deleteOrder();
    if (mounted) Navigator.of(context).pop();
  }

  // ─── Save / leave ────────────────────────────────────────────────────────

  void _save() {
    if (_store.customer == null) return;
    _store.deferSave = false;
    _store.updateTotal();
    _store.createItem();
    setState(() => _isNew = false);
  }

  Future<void> _confirmDiscard() async {
    final l10n = context.l10n;
    final leave = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(l10n.orderDiscardTitle),
        content: Text(l10n.orderDiscardMessage),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.orderKeepEditing),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.discard),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      setState(() => _leaving = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final config = context.watch<SegmentConfigProvider>();
    if (!_ready) {
      return CupertinoPageScaffold(
        backgroundColor: AppColors.background.resolveFrom(context),
        navigationBar: CupertinoNavigationBar(
          backgroundColor: AppColors.background.resolveFrom(context),
          border: null,
        ),
        child: const LoadingState(),
      );
    }

    return Observer(
      builder: (_) {
        final blockPop = _isNew && !_leaving && _hasContent;
        return PopScope(
          canPop: !blockPop,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmDiscard();
          },
          child: CupertinoPageScaffold(
            backgroundColor: AppColors.background.resolveFrom(context),
            child: Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    CupertinoSliverNavigationBar(
                      largeTitle: Text(_title(config)),
                      backgroundColor:
                          AppColors.background.resolveFrom(context),
                      border: null,
                      trailing: _isNew
                          ? null
                          : CupertinoButton(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(44, 44),
                              onPressed: _showMenu,
                              child: Semantics(
                                label: l10n.orderMoreActions,
                                child: const Icon(CupertinoIcons.ellipsis_circle),
                              ),
                            ),
                    ),
                    SliverToBoxAdapter(child: _buildContent(config)),
                    const SliverToBoxAdapter(child: SizedBox(height: 140)),
                  ],
                ),
                if (_isNew) _buildBottom(config),
              ],
            ),
          ),
        );
      },
    );
  }

  String _title(SegmentConfigProvider config) {
    final l10n = context.l10n;
    if (_isNew) return l10n.orderNewTitle(config.serviceOrder);
    final number = _store.orderStream?.value?.number ?? _store.order?.number;
    if (number == null) return config.serviceOrder;
    return l10n.orderNumberTitle(config.serviceOrder, '$number');
  }

  Widget _buildContent(SegmentConfigProvider config) {
    final l10n = context.l10n;
    final canViewPrices = _permissions.canViewPrices();
    final services = _store.services?.toList() ?? const <OrderService>[];
    final products = _store.products?.toList() ?? const <OrderProduct>[];
    final summary = summarizeOrderItems(services, products);
    final nextStep = _isNew ? null : _nextStep(config, canViewPrices);
    final photos = _store.photos.toList();
    final dueDate = _store.order?.dueDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStatusRow(config),
        if (nextStep != null) _buildNextStep(nextStep),

        // Customer and vehicle
        SectionLabel(config.customer),
        if (_store.customer == null)
          AddRow(label: l10n.pickCustomerTitle, onTap: _pickCustomer)
        else
          AppListRow(
            title: _store.customer!.name ?? '',
            subtitle: (_store.customer!.phone?.isNotEmpty ?? false)
                ? _store.customer!.phone
                : null,
            onTap: _pickCustomer,
          ),
        for (final device in _store.devices)
          AppListRow(
            title: device.name ?? '',
            subtitle: (device.serial?.isNotEmpty ?? false) ? device.serial : null,
            showChevron: false,
            onTap: () => _changeDevice(device),
          ),
        if (_store.customer != null && _store.devices.isEmpty)
          AddRow(label: l10n.orderPickDevice(config.device), onTap: _addDevice),

        // What will be done
        SectionLabel(l10n.orderItemsSection),
        for (var i = 0; i < services.length; i++)
          AppListRow(
            title: _serviceName(services[i]),
            subtitle: l10n.orderItemKindService,
            trailing: canViewPrices ? _price(services[i].value) : null,
            showChevron: false,
            onTap: () => _editService(i),
          ),
        for (var i = 0; i < products.length; i++)
          AppListRow(
            title: _productName(products[i]),
            subtitle: (products[i].quantity ?? 1) > 1
                ? '${l10n.orderItemKindProduct} · ${l10n.orderItemQuantityValue('${products[i].quantity}')}'
                : l10n.orderItemKindProduct,
            trailing:
                canViewPrices ? _price(productLineTotal(products[i])) : null,
            showChevron: false,
            onTap: () => _editProduct(i),
          ),
        AddRow(label: l10n.orderWhatGoesTitle, onTap: _addItem),

        if (dueDate != null)
          AppListRow(
            title: l10n.orderAddDueDate,
            trailing: _format.formatDateTime(dueDate),
            showChevron: false,
            onTap: _pickDueDate,
          ),

        if (photos.isNotEmpty) ...[
          SectionLabel(l10n.orderPhotosSection),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageMargin,
              ),
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (_, i) => CachedImage(
                imageUrl: photos[i].url ?? '',
                width: 88,
                height: 88,
                borderRadius: BorderRadius.circular(AppRadii.field),
              ),
            ),
          ),
        ],

        if (canViewPrices && (services.isNotEmpty || products.isNotEmpty))
          _buildSummary(summary),

        if (_isNew && _store.customer == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageMargin, AppSpacing.xl, AppSpacing.pageMargin, 0,
            ),
            child: Text(
              l10n.orderSaveNeedsCustomer,
              style: AppTypography.label.copyWith(
                color: AppColors.textSecondary.resolveFrom(context),
              ),
            ),
          ),
      ],
    );
  }

  String _price(double? value) =>
      value == null ? context.l10n.catalogNoPrice : _format.formatCurrency(value);

  Widget _buildStatusRow(SegmentConfigProvider config) {
    final l10n = context.l10n;
    final status = _store.status;
    final due = _store.order?.dueDate;
    final overdue = due != null &&
        due.isBefore(DateTime.now()) &&
        const ['quote', 'approved', 'progress'].contains(status);
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _selectStatus,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageMargin,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                StatusDot(
                  color: overdue
                      ? OrderStatusStyle.overdueColor
                      : OrderStatusStyle.dotColor(status),
                  size: 10,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: config.getStatus(status),
                      style: AppTypography.callout.copyWith(
                        color: AppColors.textSecondary.resolveFrom(context),
                      ),
                      children: [
                        if (overdue)
                          TextSpan(
                            text: ' · ${l10n.orderOverdue}',
                            style: AppTypography.callout.copyWith(
                              fontWeight: FontWeight.w700,
                              color: OrderStatusStyle.overdueColor
                                  .resolveFrom(context),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Text(
                  l10n.orderChangeStatusLink,
                  style: AppTypography.callout.copyWith(
                    color: AppColors.accentText.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _NextStep? _nextStep(SegmentConfigProvider config, bool canViewPrices) {
    final order = _store.order;
    if (order == null) return null;
    final l10n = context.l10n;
    _NextStep toStatus(String sentence, String label, String target) =>
        _permissions.canChangeStatus(order, target)
            ? _NextStep(sentence, label, () => _trySetStatus(target))
            : _NextStep(sentence);

    switch (_store.status) {
      case 'quote':
        return toStatus(l10n.orderNextStepQuote, l10n.orderNextStepQuoteAction,
            'approved');
      case 'approved':
        return toStatus(l10n.orderNextStepApproved,
            l10n.orderNextStepApprovedAction, 'progress');
      case 'progress':
        return toStatus(l10n.orderNextStepProgress,
            l10n.orderNextStepProgressAction, 'done');
      case 'done':
        final remaining = _store.remainingBalance;
        if (canViewPrices && remaining > 0) {
          final amount = _format.formatCurrency(remaining);
          return _NextStep(
            l10n.orderNextStepDoneUnpaid(amount),
            l10n.orderNextStepReceive(amount),
            () => _actions.openPayments(context, _store),
          );
        }
        if (order.id == null) return _NextStep(l10n.orderNextStepDone);
        return _NextStep(
          canViewPrices ? l10n.orderNextStepDonePaid : l10n.orderNextStepDone,
          l10n.orderNextStepSend,
          () => _actions.shareWithCustomer(context, order),
        );
      case 'canceled':
        return toStatus(l10n.orderNextStepCanceled(config.serviceOrder),
            l10n.orderNextStepReopen, 'quote');
    }
    return null;
  }

  Widget _buildNextStep(_NextStep step) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.blockMargin, AppSpacing.sm, AppSpacing.blockMargin, 0,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.accentSoft.resolveFrom(context),
          borderRadius: BorderRadius.circular(AppRadii.block),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              step.sentence,
              style: AppTypography.highlight.copyWith(
                color: AppColors.onAccentSoft.resolveFrom(context),
              ),
            ),
            if (step.actionLabel != null) ...[
              const SizedBox(height: AppSpacing.md),
              _primaryButton(step.actionLabel!, step.onAction),
            ],
          ],
        ),
      ),
    );
  }

  Widget _primaryButton(String label, VoidCallback? onPressed) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size.fromHeight(AppSizes.primaryButtonHeight),
      color: AppColors.accent.resolveFrom(context),
      disabledColor: AppColors.secondaryFill.resolveFrom(context),
      borderRadius: BorderRadius.circular(AppRadii.button),
      onPressed: onPressed,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppTypography.bodyStrong.copyWith(
          color: onPressed == null
              ? AppColors.textSecondary.resolveFrom(context)
              : AppColors.onAccent.resolveFrom(context),
        ),
      ),
    );
  }

  Widget _buildSummary(OrderItemsSummary summary) {
    final l10n = context.l10n;
    final text = AppColors.text.resolveFrom(context);
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final total = _store.total ?? summary.total;
    final showPayment = !_isNew &&
        !const ['quote', 'canceled'].contains(_store.status);
    final remaining = _store.remainingBalance;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMargin),
            color: AppColors.separator.resolveFrom(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageMargin, AppSpacing.md, AppSpacing.pageMargin, 0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.orderTotalLabel,
                    style: AppTypography.bodyStrong.copyWith(color: text),
                  ),
                ),
                Text(
                  _format.formatCurrency(total),
                  style: AppTypography.bodyStrong.copyWith(
                    color: text,
                    fontFeatures: AppTypography.tabular,
                  ),
                ),
              ],
            ),
          ),
          if (summary.hasUnpriced)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageMargin, AppSpacing.xs, AppSpacing.pageMargin, 0,
              ),
              child: Text(
                l10n.orderUnpricedCount(summary.unpricedCount),
                style: AppTypography.label.copyWith(color: secondary),
              ),
            ),
          if (showPayment)
            AppListRow(
              title: remaining > 0
                  ? l10n.orderRemainingToReceive(
                      _format.formatCurrency(remaining))
                  : l10n.orderFullyPaid,
              titleStyle: AppTypography.callout,
              onTap: () => _actions.openPayments(context, _store),
            ),
        ],
      ),
    );
  }

  Widget _buildBottom(SegmentConfigProvider config) {
    final l10n = context.l10n;
    return Positioned(
      left: AppSpacing.blockMargin,
      right: AppSpacing.blockMargin,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.showAssistant) ...[
                _AssistantPlaceholder(),
                const SizedBox(height: AppSpacing.sm),
              ],
              _primaryButton(
                l10n.orderSaveButton(config.serviceOrder),
                _store.customer == null ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Adds what was picked in "O que vai na OS?" to the order: price copied from
/// the catalog (null stays null, "sem valor"), quantity 1.
void addPickToOrder(OrderStore store, OrderItemPick pick) {
  final item = pick.item;
  if (pick.kind == CatalogKind.service) {
    final origin = item.origin;
    final aggr = origin is Service
        ? origin.toAggr()
        : (ServiceAggr()
          ..id = item.id
          ..name = item.name
          ..value = item.value
          ..photo = item.photo);
    store.addService(OrderService()
      ..service = aggr
      ..value = item.value);
  } else {
    final origin = item.origin;
    final aggr = origin is Product
        ? origin.toAggr()
        : (ProductAggr()
          ..id = item.id
          ..name = item.name
          ..value = item.value
          ..photo = item.photo);
    store.addProduct(OrderProduct()
      ..product = aggr
      ..value = item.value
      ..quantity = 1
      ..total = item.value);
  }
}

/// Foto / "Falar o que fazer": the assistant arrives in phase 2. Shown
/// disabled ("Em breve") so the camera and microphone are never requested.
class _AssistantPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final secondary = AppColors.textSecondary.resolveFrom(context);
    Widget button(IconData icon, String label) => Expanded(
          child: Semantics(
            enabled: false,
            button: true,
            label: '$label, ${l10n.orderAssistantSoon}',
            excludeSemantics: true,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              decoration: BoxDecoration(
                color: AppColors.secondaryFill.resolveFrom(context),
                borderRadius: BorderRadius.circular(AppRadii.button),
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: secondary),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      label,
                      style: AppTypography.callout.copyWith(color: secondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    return Row(
      children: [
        button(CupertinoIcons.camera, l10n.orderPhotoAction),
        const SizedBox(width: AppSpacing.sm),
        button(CupertinoIcons.mic, l10n.orderTalkAction),
      ],
    );
  }
}
