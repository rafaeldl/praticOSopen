import 'package:flutter/cupertino.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart' show runInAction;
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/mobx/reminder_store.dart';
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
import 'package:praticos/screens/order/order_extras.dart';
import 'package:praticos/screens/order/order_item_sheet.dart';
import 'package:praticos/screens/order/order_screen_services.dart';
import 'package:praticos/screens/widgets/add_row.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/app_sheet.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/screens/widgets/order_media_actions.dart'
    show confirmDeleteOrderDocument;
import 'package:praticos/screens/widgets/order_status_share.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/theme/status_style.dart';
import 'package:praticos/utils/order_items.dart';
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
/// - "Adicionar à OS ›" adds what is rare: checklist, photos or document,
///   comment, address, schedule, due date, discount, recurring contract,
///   another vehicle. Once added, each shows in "Nesta OS" (only what
///   exists); comments show at the end of a saved order.
/// - After a status change, "Avisar o cliente?" offers the customer link
///   (same rules as the legacy screen, see `order_status_share.dart`).
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

  /// Opened from a comment notification: scroll to the comments.
  bool _scrollToComments = false;
  String? _highlightCommentId;

  /// Orders whose "Avisar o cliente?" was answered "Agora não".
  final Set<String> _dismissedSharePrompts = {};

  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

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
    _scrollToComments = args?['scrollToComments'] == true;
    _highlightCommentId = args?['commentId'] as String?;
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
    if (_scrollToComments) {
      _scrollToComments = false;
      _scrollToEnd();
    }
  }

  /// Comments live at the end of the order.
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
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
    await _offerNotifyCustomer(status);
  }

  /// "Avisar o cliente?" after approved / in progress / done.
  Future<void> _offerNotifyCustomer(String status) async {
    final order = _store.order;
    if (order == null ||
        !mounted ||
        !shouldOfferStatusShare(order, status,
            dismissedOrderIds: _dismissedSharePrompts)) {
      return;
    }
    final send = await askNotifyCustomer(context, order: order, status: status);
    if (!mounted) return;
    if (send) {
      await _actions.notifyCustomer(context, order, status);
    } else {
      _dismissedSharePrompts.add(order.id!);
    }
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

  bool get _hasAddress => _store.address?.trim().isNotEmpty ?? false;

  bool get _canGiveDiscount =>
      _store.order?.id != null &&
      _permissions.canViewPrices() &&
      !const ['quote', 'canceled'].contains(_store.status) &&
      _store.remainingBalance > 0;

  /// What the new screen still does not draw: segment custom fields and
  /// items per vehicle (2 or more vehicles).
  bool _needsCompleteScreen(SegmentConfigProvider config) =>
      _store.devices.length >= 2 ||
      config
          .fieldsGroupedBySectionLocalized(
            'service_order',
            exclude: orderBuiltInFieldKeys,
          )
          .isNotEmpty;

  /// "Adicionar à OS ›": only what the order does not have yet.
  Future<void> _showAddToOrder() async {
    final order = _store.order;
    if (order == null) return;
    final l10n = context.l10n;
    final config = context.read<SegmentConfigProvider>();
    final orderLabel = config.serviceOrder;
    final saved = order.id != null;
    final canEdit = _permissions.canEditMainFields(order);
    final options = <(String, String)>[
      if (saved && _permissions.canManageForms(order))
        ('checklist', l10n.orderAddChecklist),
      if (saved && _permissions.canAttachMedia())
        ('media', l10n.orderAddMedia),
      if (saved && order.company?.id != null)
        ('comment', l10n.orderAddComment),
      if (canEdit && config.fieldService && !_hasAddress)
        ('address', l10n.orderAddAddress),
      if (canEdit && config.useScheduling && order.scheduledDate == null)
        ('schedule', l10n.orderAddSchedule),
      if (canEdit && order.dueDate == null) ('due', l10n.orderAddDueDate),
      if (_canGiveDiscount) ('discount', l10n.orderAddDiscount),
      if (canEdit && saved && config.useContracts && !_store.hasContract)
        ('contract', l10n.orderAddContract(orderLabel)),
      if (canEdit) ('device', l10n.orderAddAnotherDevice(config.device)),
      if (saved && _needsCompleteScreen(config))
        ('more', l10n.orderAddOtherFields),
    ];
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(l10n.orderMenuAddTo(orderLabel)),
        actions: [
          for (final (key, label) in options)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, key),
              child: Text(label),
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
      case 'checklist':
        await _actions.addChecklist(context, _store);
      case 'media':
        await _actions.addMedia(context, _store);
      case 'comment':
        _scrollToEnd();
      case 'address':
        await _editAddress();
      case 'schedule':
        await _pickSchedule();
      case 'due':
        await _pickDueDate();
      case 'discount':
        await _giveDiscount();
      case 'contract':
        _store.toggleContract(true);
        await _actions.editContract(context, _store);
      case 'device':
        await _addDevice();
      case 'more':
        await _actions.openCompleteScreen(context, _store.order!);
        if (mounted) await _reload();
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickDueDate() async {
    final pick = await OrderDateSheet.show(
      context,
      initial: _store.order?.dueDate ?? DateTime.now(),
    );
    if (pick?.date != null && mounted) {
      _store.setDueDate(pick!.date!);
      setState(() {});
    }
  }

  Future<void> _pickSchedule() async {
    final current = _store.order?.scheduledDate;
    final pick = await OrderDateSheet.show(
      context,
      initial: current ?? DateTime.now(),
      removeLabel: current == null ? null : context.l10n.orderScheduleRemove,
    );
    if (pick == null || !mounted) return;
    if (pick.remove) {
      _store.clearScheduledDate();
    } else {
      ReminderStore? reminders;
      try {
        reminders = Provider.of<ReminderStore>(context, listen: false);
      } catch (_) {
        // No reminder settings in this tree: no local reminder.
      }
      _store.setScheduledDate(pick.date!, reminderStore: reminders);
    }
    setState(() {});
  }

  Future<void> _editAddress() async {
    final text = await AppSheet.show<String>(
      context,
      (_) => OrderAddressSheet(initial: _store.address),
    );
    if (text == null || !mounted) return;
    _setAddress(text);
  }

  void _setAddress(String text) {
    final keepPlace = text.isNotEmpty && text == _store.address;
    _store.setAddress(
      text.isEmpty ? null : text,
      lat: keepPlace ? _store.latitude : null,
      lng: keepPlace ? _store.longitude : null,
    );
  }

  Future<void> _addressActions() async {
    final order = _store.order;
    if (order == null) return;
    final l10n = context.l10n;
    final canEdit = _permissions.canEditMainFields(order);
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(_store.address ?? ''),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'map'),
            child: Text(l10n.openInMaps),
          ),
          if (canEdit)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, 'change'),
              child: Text(l10n.orderAddressChange),
            ),
          if (canEdit)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx, 'remove'),
              child: Text(l10n.orderAddressRemove),
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
      case 'map':
        await _actions.openInMaps(_store);
      case 'change':
        await _editAddress();
      case 'remove':
        _setAddress('');
    }
  }

  Future<void> _giveDiscount() async {
    final amount = await _actions.askDiscount(
      context,
      currentTotal: _store.total ?? 0,
      maxDiscount: _store.remainingBalance,
    );
    if (amount == null || !mounted) return;
    final ok = await _store.addDiscountTransaction(amount);
    if (!ok && mounted) await _alert(context.l10n.errorOccurred);
  }

  Future<void> _contractActions() async {
    final l10n = context.l10n;
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(l10n.recurringContract),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'change'),
            child: Text(l10n.orderContractChange),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, 'stop'),
            child: Text(l10n.deactivateContract),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.cancel),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'change') {
      await _actions.editContract(context, _store);
    } else {
      final stop = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(l10n.deactivateContract),
          content: Text(l10n.deactivateContractConfirm),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.deactivateContract),
            ),
          ],
        ),
      );
      if (stop == true) _store.toggleContract(false);
    }
    if (mounted) setState(() {});
  }

  Future<bool> _confirmDeleteChecklist(of_model.OrderForm form) async {
    final l10n = context.l10n;
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('${l10n.delete} ${l10n.checklist}'),
        content: Text(l10n.confirmDeleteMessageNamed(
          form.getLocalizedTitle(l10n.localeName),
        )),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    await _actions.deleteChecklist(_store, form);
    return true;
  }

  Future<bool> _confirmDeleteDocument(int index) async {
    if (!await confirmDeleteOrderDocument(context)) return false;
    return _store.deleteDocument(index);
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
                  controller: _scroll,
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
    final comments = _buildComments();

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

        ..._buildExtras(config),

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

        if (comments != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: comments,
          ),
      ],
    );
  }

  // ─── "Nesta OS" ──────────────────────────────────────────────────────────

  /// Only what this order has: schedule, due date, address, contract,
  /// checklists, then photos, documents and comments.
  List<Widget> _buildExtras(SegmentConfigProvider config) {
    final l10n = context.l10n;
    final order = _store.order;
    if (order == null) return const [];
    final canEdit = _permissions.canEditMainFields(order);
    final scheduled = order.scheduledDate;
    final dueDate = order.dueDate;
    final contract = _store.hasContract ? order.contract : null;
    final forms = _store.formsStream?.value ?? const <of_model.OrderForm>[];
    final canManageForms = _permissions.canManageForms(order);
    final photos = _store.photos.toList();
    final documents = _store.documents.toList();
    final canAttach = _permissions.canAttachMedia();
    final uploading = _store.isUploadingPhoto || _store.isUploadingDocument;
    final children = contract != null && contract.parentOrderId == null
        ? (_store.childOrders?.value?.whereType<Order>().toList() ??
            <Order>[])
        : <Order>[];
    children.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));

    final rows = <Widget>[
      if (scheduled != null)
        AppListRow(
          title: l10n.scheduledDate,
          trailing: _format.formatDateTime(scheduled),
          showChevron: false,
          onTap: canEdit ? _pickSchedule : null,
        ),
      if (dueDate != null)
        AppListRow(
          title: l10n.orderAddDueDate,
          trailing: _format.formatDateTime(dueDate),
          showChevron: false,
          onTap: canEdit ? _pickDueDate : null,
        ),
      if (_hasAddress)
        AppListRow(
          title: l10n.address,
          subtitle: _store.address,
          showChevron: false,
          onTap: _addressActions,
        ),
      if (contract != null && contract.parentOrderId != null)
        AppListRow(
          title: l10n.recurringContract,
          trailing: contract.parentOrderNumber == null
              ? null
              : l10n.orderNumberTitle(
                  config.serviceOrder, '${contract.parentOrderNumber}'),
          onTap: () => _actions.openOrder(
            context,
            Order()..id = contract.parentOrderId,
          ),
        )
      else if (contract != null)
        AppListRow(
          title: l10n.recurringContract,
          subtitle: contract.nextDueDate == null
              ? _frequencyLabel(contract.frequency)
              : l10n.orderContractSummary(
                  _frequencyLabel(contract.frequency),
                  _format.formatDate(contract.nextDueDate!),
                ),
          showChevron: false,
          onTap: _contractActions,
        ),
      for (final form in forms) _checklistRow(form, canManageForms),
    ];

    return [
      if (rows.isNotEmpty) ...[
        SectionLabel(l10n.orderInThisOrder(config.serviceOrder)),
        ...rows,
      ],
      if (children.isNotEmpty) ...[
        SectionLabel(l10n.generatedOrdersCount(children.length)),
        for (final child in children)
          AppListRow(
            title: l10n.orderNumberTitle(
                config.serviceOrder, '${child.number ?? ''}'),
            leading: StatusDot(color: OrderStatusStyle.dotColor(child.status)),
            trailing: child.createdAt == null
                ? null
                : _format.formatDate(child.createdAt!),
            onTap: () => _actions.openOrder(context, child),
          ),
      ],
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
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => _actions.viewPhoto(context, _store, i, config),
              child: Semantics(
                button: true,
                label: '${l10n.orderPhotosSection} ${i + 1}',
                child: _actions.photoThumb(
                  photos[i].url ?? '',
                  88,
                  BorderRadius.circular(AppRadii.field),
                ),
              ),
            ),
          ),
        ),
      ],
      if (documents.isNotEmpty) ...[
        SectionLabel(l10n.documents),
        for (var i = 0; i < documents.length; i++)
          _swipeToDelete(
            key: ValueKey('doc_${documents[i].id ?? i}'),
            enabled: canAttach,
            onDelete: () => _confirmDeleteDocument(i),
            child: AppListRow(
              title: documents[i].fileName ?? l10n.document,
              subtitle: [
                documents[i].typeLabel(l10n),
                if (documents[i].fileSizeFormatted.isNotEmpty)
                  documents[i].fileSizeFormatted,
              ].join(' · '),
              onTap: () => _actions.openDocument(context, documents[i]),
            ),
          ),
      ],
      if (uploading)
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageMargin,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              const CupertinoActivityIndicator(),
              const SizedBox(width: AppSpacing.sm),
              Text(
                l10n.orderUploading,
                style: AppTypography.callout.copyWith(
                  color: AppColors.textSecondary.resolveFrom(context),
                ),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _checklistRow(of_model.OrderForm form, bool canManage) {
    final l10n = context.l10n;
    final done = form.status == of_model.FormStatus.completed;
    final missing = checklistMissing(form);
    return _swipeToDelete(
      key: ValueKey('form_${form.id}'),
      enabled: canManage,
      onDelete: () => _confirmDeleteChecklist(form),
      child: AppListRow(
        leading: StatusDot(
          color: done ? AppColors.success : AppColors.warning,
        ),
        title: form.getLocalizedTitle(l10n.localeName),
        subtitle: done || missing == 0
            ? l10n.orderChecklistDone
            : l10n.orderChecklistMissing(missing),
        onTap: () => _actions.openChecklist(context, _store, form),
      ),
    );
  }

  /// iOS swipe to delete, asking first ([onDelete] resolves true when the
  /// row really went away).
  Widget _swipeToDelete({
    required Key key,
    required bool enabled,
    required Future<bool> Function() onDelete,
    required Widget child,
  }) {
    if (!enabled) return child;
    return Dismissible(
      key: key,
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        color: AppColors.danger.resolveFrom(context),
        child: Semantics(
          label: context.l10n.delete,
          child: const Icon(CupertinoIcons.delete, color: CupertinoColors.white),
        ),
      ),
      confirmDismiss: (_) => onDelete(),
      child: child,
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

  /// Comments (internal or for the customer), at the end of a saved order.
  Widget? _buildComments() {
    final order = _store.order;
    if (order?.id == null || order?.company?.id == null) return null;
    return _actions.comments(order!, highlightCommentId: _highlightCommentId);
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
          if ((_store.discount ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageMargin, AppSpacing.xs, AppSpacing.pageMargin, 0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.discount,
                      style: AppTypography.callout.copyWith(color: secondary),
                    ),
                  ),
                  Text(
                    '− ${_format.formatCurrency(_store.discount!)}',
                    style: AppTypography.callout.copyWith(
                      color: secondary,
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
