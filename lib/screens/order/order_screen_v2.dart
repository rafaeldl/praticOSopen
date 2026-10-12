import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart' show runInAction;
import 'package:praticos/config/feature_flags.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/mobx/reminder_store.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/models/order_form.dart' as of_model;
import 'package:praticos/models/product.dart';
import 'package:praticos/models/service.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/catalog/catalog_source.dart';
import 'package:praticos/screens/customers/customer_list_screen.dart'
    show CustomerPick;
import 'package:praticos/screens/order/assistant/assistant_input_sheet.dart';
import 'package:praticos/screens/order/order_item_search_screen.dart';
import 'package:praticos/screens/order/order_extras.dart';
import 'package:praticos/screens/order/order_item_sheet.dart';
import 'package:praticos/screens/order/order_screen_services.dart';
import 'package:praticos/screens/widgets/add_row.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/app_sheet.dart';
import 'package:praticos/utils/phone_format.dart';
import 'package:praticos/screens/widgets/device_picker_sheet.dart';
import 'package:praticos/screens/widgets/order_custom_fields.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/screens/widgets/order_media_actions.dart'
    show confirmDeleteOrderDocument;
import 'package:praticos/screens/widgets/order_status_share.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/services/ai_order_assist_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/pdf/pdf_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_glass.dart';
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
/// - Foto / "Falar o que fazer" (new order only, behind [kAiOrderAssistEnabled],
///   off by default): the camera opens only on Foto; Falar opens a text sheet
///   (keyboard dictation). The assistant's draft fills this same blank order
///   and what it filled is highlighted (marca-texto) until "Salvar OS".
class OrderScreenV2 extends StatefulWidget {
  const OrderScreenV2({
    super.key,
    this.store,
    this.permissions,
    this.actions,
    this.catalogSource,
    this.catalogPermissions,
    this.mostUsed,
    this.devicePicker,
    this.showAssistant = kAiOrderAssistEnabled,
    this.assistant,
    this.capturePhoto,
  });

  /// Injected in tests; defaults to a new [OrderStore].
  final OrderStore? store;
  final OrderPermissions? permissions;
  final OrderScreenActions? actions;

  /// Passed to "O que vai na OS?" (tests).
  final CatalogSource? catalogSource;
  final CatalogPermissions? catalogPermissions;
  final Future<List<String>> Function()? mostUsed;

  /// Which vehicle(s) a new item is for when the order has 2 or more
  /// (tests); defaults to [DevicePickerSheet.show].
  final Future<DevicePickerResult?> Function(
    BuildContext context,
    List<DeviceAggr> devices,
  )?
  devicePicker;

  /// Shows Foto / "Falar o que fazer" on a new order. Defaults to the
  /// compile-time flag [kAiOrderAssistEnabled] (off).
  final bool showAssistant;

  /// Assistant client; defaults to [AiOrderAssistService] (tests inject).
  final AiOrderAssistClient? assistant;

  /// Opens the camera; defaults to image_picker (tests inject).
  final Future<AiPhoto?> Function()? capturePhoto;

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

  // ─── Assistant state (new order only) ───
  /// What the assistant filled: item instances, 'customer', 'device:{id}'.
  final Set<Object> _marked = Set<Object>.identity();
  String? _customerGuess;
  String? _deviceGuess;
  bool _assistantBusy = false;

  FormatService get _format =>
      FormatService()..setLocale(context.l10n.localeName);

  /// Name of the screen that opened this OS, for the back button.
  String? _previousTitle;

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
    _previousTitle = args?['previousTitle'] as String?;
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
            : await _store.repository.getOrderByNumber(
                companyId,
                order.number!,
              );
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

  bool get _hasContent =>
      _store.customer != null ||
      _store.devices.isNotEmpty ||
      (_store.services?.isNotEmpty ?? false) ||
      (_store.products?.isNotEmpty ?? false);

  // ─── Customer and vehicle ────────────────────────────────────────────────

  /// Header tap (saved OS): change the customer or a vehicle, which no
  /// longer have their own section (app-os).
  Future<void> _showPeopleMenu() async {
    final l10n = context.l10n;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _pickCustomer();
            },
            child: Text(l10n.orderChangeCustomer),
          ),
          for (final device in _store.devices)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                _changeDevice(device);
              },
              child: Text(l10n.orderChangeDevice(device.name ?? '')),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: Text(l10n.cancel),
        ),
      ),
    );
  }

  Future<void> _pickCustomer() async {
    final result = await Navigator.pushNamed(
      context,
      '/customer_list',
      arguments: {'order': _store.order},
    );
    if (!mounted || result is! CustomerPick) return;
    _store.setCustomer(result.customer);
    if (result.device != null) _store.addDevice(result.device!);
    setState(() {
      _marked.remove('customer');
      _customerGuess = null;
    });
  }

  Future<void> _addDevice() async {
    final result = await Navigator.pushNamed(
      context,
      '/device_list',
      arguments: {'order': _store.order},
    );
    if (!mounted || result is! Device) return;
    _store.addDevice(result);
    setState(() => _deviceGuess = null);
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
    // 2+ vehicles: same question as the legacy screen (which vehicle, all of
    // them, several, or general). Set only now so cancelling leaves no state.
    if (_store.devices.length >= 2) {
      final result = await (widget.devicePicker ?? DevicePickerSheet.show)(
        context,
        _store.devices.toList(),
      );
      if (!mounted || result == null) return;
      applyDevicePick(_store, result);
    }
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

  String _serviceName(OrderService s) => s.service?.name ?? s.description ?? '';

  String _productName(OrderProduct p) => p.product?.name ?? p.description ?? '';

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
      final pending = forms
          .where((f) => f.status != of_model.FormStatus.completed)
          .length;
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
        !shouldOfferStatusShare(
          order,
          status,
          dismissedOrderIds: _dismissedSharePrompts,
        )) {
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

  /// "OS" for the default label; a segment that renames the order keeps it.
  String _shortOrderLabel(SegmentConfigProvider config) {
    final l10n = context.l10n;
    return config.serviceOrder == l10n.order
        ? l10n.orderShort
        : config.serviceOrder;
  }

  // ─── "…" menu ────────────────────────────────────────────────────────────

  Future<void> _showMenu() async {
    final order = _store.order;
    if (order == null) return;
    final l10n = context.l10n;
    final config = context.read<SegmentConfigProvider>();
    final orderLabel = _shortOrderLabel(config);
    final canCancel =
        _store.status != 'canceled' &&
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
          if (canShareOrderPdf(
            canViewPrices: _permissions.canViewPrices(),
            useFinancial: config.useFinancial,
          ))
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, 'pdf'),
              child: Text(l10n.orderMenuPdfOf(orderLabel)),
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

  /// "Adicionar à OS ›": only what the order does not have yet.
  Future<void> _showAddToOrder() async {
    final order = _store.order;
    if (order == null) return;
    final l10n = context.l10n;
    final config = context.read<SegmentConfigProvider>();
    final orderLabel = _shortOrderLabel(config);
    final saved = order.id != null;
    final canEdit = _permissions.canEditMainFields(order);
    final options = <(String, String)>[
      if (canEdit) ('item', l10n.orderAddItem),
      if (saved && _permissions.canManageForms(order))
        ('checklist', l10n.orderAddChecklist),
      if (canEdit && order.dueDate == null) ('due', l10n.orderAddDueDate),
      if (canEdit && config.useScheduling && order.scheduledDate == null)
        ('schedule', l10n.orderAddSchedule),
      if (canEdit && config.fieldService && !_hasAddress)
        ('address', l10n.orderAddAddress),
      if (canEdit)
        ('device', l10n.orderAddAnotherDevice(config.device.toLowerCase())),
      if (_canGiveDiscount) ('discount', l10n.orderAddDiscount),
      if (saved && order.company?.id != null) ('comment', l10n.orderAddComment),
      if (saved && _permissions.canAttachMedia()) ('media', l10n.orderAddMedia),
      if (canEdit && saved && order.assignedTo == null)
        ('responsible', l10n.orderAddResponsible),
      if (canEdit && saved && config.useContracts && !_store.hasContract)
        ('contract', l10n.orderAddContractMonthly),
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
      case 'item':
        await _addItem();
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
      case 'responsible':
        await _pickResponsible();
    }
    if (mounted) setState(() {});
  }

  /// "Responsável": who of the team takes care of this order.
  Future<void> _pickResponsible() async {
    final l10n = context.l10n;
    final team = await _actions.teamMembers();
    if (!mounted || team.isEmpty) return;
    final current = _store.order?.assignedTo;
    final picked = await showCupertinoModalPopup<Object>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(l10n.orderAddResponsible),
        actions: [
          for (final user in team)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, user),
              child: Text(user.name ?? user.email ?? ''),
            ),
          if (current != null)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.orderResponsibleRemove),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.cancel),
        ),
      ),
    );
    if (!mounted || picked == null) return;
    setState(() => _store.setAssignedTo(picked is UserAggr ? picked : null));
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
        content: Text(
          l10n.confirmDeleteMessageNamed(
            form.getLocalizedTitle(l10n.localeName),
          ),
        ),
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
    setState(() {
      _isNew = false;
      _marked.clear();
      _customerGuess = null;
      _deviceGuess = null;
    });
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

  // ─── Assistant ───────────────────────────────────────────────────────────

  Future<AiPhoto?> _capturePhoto() async {
    if (widget.capturePhoto != null) return widget.capturePhoto!();
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 70,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    return AiPhoto(await file.readAsBytes());
  }

  /// Foto: camera first, then the same sheet to add what to do (optional).
  Future<void> _onPhoto() async {
    final photo = await _capturePhoto();
    if (!mounted || photo == null) return;
    await _openAssistant(photos: [photo]);
  }

  Future<void> _openAssistant({List<AiPhoto> photos = const []}) async {
    final input = await AppSheet.show<AssistantInput>(
      context,
      (_) => AssistantInputSheet(
        initialPhotos: photos,
        capturePhoto: _capturePhoto,
      ),
    );
    if (!mounted || input == null || input.isEmpty) return;
    await _runAssistant(input);
  }

  Future<void> _runAssistant(AssistantInput input) async {
    final l10n = context.l10n;
    setState(() => _assistantBusy = true);
    AiOrderDraft? draft;
    String? error;
    try {
      final client = widget.assistant ?? AiOrderAssistService();
      draft = await client.assist(
        text: input.text,
        photos: input.photos,
        locale: l10n.localeName.split('_').first,
      );
    } on AiOrderAssistException catch (e) {
      error = switch (e.error) {
        AiAssistError.disabled => l10n.orderAssistantErrorDisabled,
        AiAssistError.quotaExceeded => l10n.orderAssistantErrorQuota(
          '${e.limit ?? ''}'.trim(),
        ),
        _ => l10n.orderAssistantErrorUnavailable,
      };
    } catch (_) {
      error = l10n.orderAssistantErrorUnavailable;
    }
    if (!mounted) return;
    // Stop the spinner before any dialog.
    setState(() => _assistantBusy = false);
    if (error != null) {
      await _alert(l10n.orderAssistantErrorTitle, error);
    } else if (!_applyDraft(draft!)) {
      await _alert(
        l10n.orderAssistantErrorTitle,
        l10n.orderAssistantNothingFound,
      );
    }
  }

  /// Fills the blank order with the draft, without saving (deferSave). Never
  /// replaces a customer already chosen; adds devices and items. Returns false
  /// when the draft had nothing to use.
  bool _applyDraft(AiOrderDraft draft) {
    var used = false;
    if (_store.customer == null) {
      if (draft.customer != null) {
        _store.setCustomer(
          Customer()
            ..id = draft.customer!.id
            ..name = draft.customer!.name
            ..phone = draft.customer!.phone,
        );
        _marked.add('customer');
        _customerGuess = null;
        used = true;
      } else if (draft.customerGuess?.isNotEmpty ?? false) {
        _customerGuess = draft.customerGuess;
        used = true;
      }
    }
    if (draft.device != null) {
      final d = draft.device!;
      _store.addDevice(
        Device()
          ..id = d.id
          ..name = d.name
          ..serial = d.serial
          ..manufacturer = d.manufacturer,
      );
      _marked.add('device:${d.id}');
      _deviceGuess = null;
      used = true;
    } else {
      final guess = [
        draft.deviceGuessName,
        draft.deviceGuessSerial,
      ].where((v) => v != null && v.isNotEmpty).join(' · ');
      if (guess.isNotEmpty) {
        _deviceGuess = guess;
        used = true;
      }
    }
    for (final item in draft.items) {
      if (item.isProduct) {
        final line = OrderProduct()
          ..product = (ProductAggr()
            ..id = item.catalogId
            ..name = item.name)
          ..value = item.value
          ..quantity = item.quantity
          ..total = item.value == null ? null : item.value! * item.quantity;
        _store.addProduct(line);
        _marked.add(line);
      } else {
        final line = OrderService()
          ..service = (ServiceAggr()
            ..id = item.catalogId
            ..name = item.name)
          ..value = item.value;
        _store.addService(line);
        _marked.add(line);
      }
      used = true;
    }
    setState(() {});
    return used;
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
                    if (_isNew)
                      CupertinoSliverNavigationBar(
                        largeTitle: Text(_title(config)),
                        backgroundColor:
                            AppColors.background.resolveFrom(context),
                        border: null,
                      )
                    else
                      AppNavBar(
                        largeTitle: Text(_title(config)),
                        previousTitle: _previousTitle,
                        trailing: GlassBarButton(
                          label: l10n.orderMoreActions,
                          icon: CupertinoIcons.ellipsis,
                          onPressed: _showMenu,
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
    return _header(config).title;
  }

  /// Vehicle in the large title, "Cliente · OS 186" under it (app-os).
  OrderHeaderTexts _header(SegmentConfigProvider config) {
    final number = _store.orderStream?.value?.number ?? _store.order?.number;
    return orderHeaderTexts(
      deviceName: _store.devices.isEmpty ? null : _store.devices.first.name,
      customerName: _store.customer?.name,
      orderLabel: number == null
          ? config.serviceOrder
          : '${_shortOrderLabel(config)} $number',
    );
  }

  Widget _buildContent(SegmentConfigProvider config) {
    final l10n = context.l10n;
    final canViewPrices = _permissions.canViewPrices();
    final services = _store.services?.toList() ?? const <OrderService>[];
    final products = _store.products?.toList() ?? const <OrderProduct>[];
    final summary = summarizeOrderItems(services, products);
    final nextStep = _isNew ? null : _nextStep(config, canViewPrices);
    final comments = _buildComments();

    final subtitle = _isNew ? null : _header(config).subtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (subtitle != null)
          Semantics(
            button: true,
            hint: l10n.orderChangeCustomer,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _showPeopleMenu,
              child: Padding(
                // Lined up with the large title (16 from the edge).
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.blockMargin,
                  0,
                  AppSpacing.pageMargin,
                  AppSpacing.xs,
                ),
                child: Text(
                  subtitle,
                  key: const ValueKey('order_header_subtitle'),
                  style: AppTypography.callout.copyWith(
                    color: AppColors.textSecondary.resolveFrom(context),
                  ),
                ),
              ),
            ),
          ),
        // Saved OS: status lives in the top block, above the next step
        // (app-os). New OS has no next step yet, so it keeps the status row.
        if (nextStep != null)
          _buildNextStep(nextStep, config)
        else
          _buildStatusRow(config),
        if (_isNew && _marked.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageMargin,
              AppSpacing.xs,
              AppSpacing.pageMargin,
              0,
            ),
            child: Text(
              l10n.orderAssistantFilledNote,
              style: AppTypography.label.copyWith(
                color: AppColors.textSecondary.resolveFrom(context),
              ),
            ),
          ),

        // Customer and vehicle: picked here on a new OS. A saved OS shows
        // them in the header (app-os) and only asks for what is missing.
        if (_isNew) ...[
          SectionLabel(config.customer),
          if (_store.customer == null && _customerGuess != null)
            AppListRow(
              title: l10n.orderAssistantCustomerGuess(_customerGuess!),
              marked: true,
              onTap: _pickCustomer,
            )
          else if (_store.customer == null)
            AddRow(label: l10n.pickCustomerTitle, onTap: _pickCustomer)
          else
            AppListRow(
              title: _store.customer!.name ?? '',
              subtitle: (_store.customer!.phone?.isNotEmpty ?? false)
                  ? formatPhone(_store.customer!.phone)
                  : null,
              marked: _marked.contains('customer'),
              onTap: _pickCustomer,
            ),
          for (final device in _store.devices)
            AppListRow(
              title: device.name ?? '',
              subtitle: (device.serial?.isNotEmpty ?? false)
                  ? device.serial
                  : null,
              marked: _marked.contains('device:${device.id}'),
              onTap: () => _changeDevice(device),
            ),
          if (_deviceGuess != null)
            AppListRow(
              title: l10n.orderAssistantDeviceGuess(_deviceGuess!),
              marked: true,
              onTap: _addDevice,
            ),
          if (_store.customer != null && _store.devices.isEmpty)
            AddRow(
              label: l10n.orderPickDevice(config.device),
              onTap: _addDevice,
            ),
        ] else ...[
          if (_store.customer == null || _store.devices.isEmpty)
            SectionLabel(config.customer),
          if (_store.customer == null)
            AddRow(label: l10n.pickCustomerTitle, onTap: _pickCustomer)
          else if (_store.devices.isEmpty)
            AddRow(
              label: l10n.orderPickDevice(config.device),
              onTap: _addDevice,
            ),
        ],

        // What will be done
        if (_store.devices.length >= 2)
          ..._buildItemsByDevice(services, products, canViewPrices)
        else ...[
          SectionLabel(l10n.orderItemsSection),
          for (var i = 0; i < services.length; i++)
            _serviceRow(services, i, canViewPrices),
          for (var i = 0; i < products.length; i++)
            _productRow(products, i, canViewPrices),
        ],
        AddRow(label: l10n.orderWhatGoesTitle, onTap: _addItem),

        // Total closes the list of items, before "Nesta OS" (app-os).
        if (canViewPrices && (services.isNotEmpty || products.isNotEmpty))
          _buildSummary(summary),

        ..._buildCustomFields(config),

        ..._buildExtras(config),

        if (_isNew && _store.customer == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageMargin,
              AppSpacing.xl,
              AppSpacing.pageMargin,
              0,
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

  Widget _serviceRow(List<OrderService> services, int i, bool canViewPrices) =>
      AppListRow(
        title: _serviceName(services[i]),
        subtitle: context.l10n.orderItemKindService,
        trailing: canViewPrices ? _price(services[i].value) : null,
        showChevron: false,
        marked: _marked.contains(services[i]),
        onTap: () => _editService(i),
      );

  Widget _productRow(List<OrderProduct> products, int i, bool canViewPrices) {
    final l10n = context.l10n;
    return AppListRow(
      title: _productName(products[i]),
      subtitle: (products[i].quantity ?? 1) > 1
          ? '${l10n.orderItemKindProduct} · ${l10n.orderItemQuantityValue('${products[i].quantity}')}'
          : l10n.orderItemKindProduct,
      trailing: canViewPrices ? _price(productLineTotal(products[i])) : null,
      showChevron: false,
      marked: _marked.contains(products[i]),
      onTap: () => _editProduct(i),
    );
  }

  /// 2+ vehicles: one block per vehicle (then "Geral" for items without
  /// one), each with its subtotal, like the legacy screen groups them.
  List<Widget> _buildItemsByDevice(
    List<OrderService> services,
    List<OrderProduct> products,
    bool canViewPrices,
  ) {
    final l10n = context.l10n;
    final groups = <(String? id, String name)>[
      for (final d in _store.devices)
        (
          d.id,
          (d.serial?.trim().isNotEmpty ?? false)
              ? '${d.name} - ${d.serial}'
              : d.name ?? '',
        ),
      (null, l10n.generalNoDevice),
    ];
    final widgets = <Widget>[];
    for (final (id, name) in groups) {
      // Items of a removed vehicle (stale id) fall into "Geral" too.
      bool inGroup(String? deviceId) => id == null
          ? deviceId == null || !_store.devices.any((d) => d.id == deviceId)
          : deviceId == id;
      final groupServices = [
        for (var i = 0; i < services.length; i++)
          if (inGroup(services[i].deviceId)) i,
      ];
      final groupProducts = [
        for (var i = 0; i < products.length; i++)
          if (inGroup(products[i].deviceId)) i,
      ];
      if (groupServices.isEmpty && groupProducts.isEmpty) continue;
      widgets.add(SectionLabel(name));
      for (final i in groupServices) {
        widgets.add(_serviceRow(services, i, canViewPrices));
      }
      for (final i in groupProducts) {
        widgets.add(_productRow(products, i, canViewPrices));
      }
      if (canViewPrices) {
        final subtotal = summarizeOrderItems(
          [for (final i in groupServices) services[i]],
          [for (final i in groupProducts) products[i]],
        );
        widgets.add(
          AppListRow(
            title: l10n.subtotal,
            titleStyle: AppTypography.callout,
            trailing: _format.formatCurrency(subtotal.total),
            showChevron: false,
          ),
        );
      }
    }
    if (widgets.isEmpty) widgets.add(SectionLabel(l10n.orderItemsSection));
    return widgets;
  }

  /// Segment custom fields of the order (same fields and save as the legacy
  /// screen, see `order_custom_fields.dart`).
  List<Widget> _buildCustomFields(SegmentConfigProvider config) {
    final grouped = orderCustomFieldsFor(config);
    if (grouped.isEmpty) return const [];
    return [
      OrderCustomFieldSections(
        grouped: grouped,
        customData: _store.order?.customData,
        locale: config.locale,
        onChanged: (data) {
          setState(() => _store.order?.customData = data);
          _store.createItem();
        },
        sectionBuilder: (context, name, rows) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionLabel(name),
            CupertinoListSection.insetGrouped(
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.blockMargin,
              ),
              children: rows,
            ),
          ],
        ),
      ),
    ];
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
        ? (_store.childOrders?.value?.whereType<Order>().toList() ?? <Order>[])
        : <Order>[];
    children.sort(
      (a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
    );

    final rows = <Widget>[
      if (scheduled != null)
        AppListRow(
          title: l10n.scheduledDate,
          trailing: _format.formatDateTime(scheduled),
          showChevron: false,
          onTap: canEdit ? _pickSchedule : null,
        ),
      if (order.assignedTo != null)
        AppListRow(
          title: l10n.orderAddResponsible,
          trailing: order.assignedTo!.name ?? order.assignedTo!.email,
          showChevron: false,
          onTap: canEdit ? _pickResponsible : null,
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
                  config.serviceOrder,
                  '${contract.parentOrderNumber}',
                ),
          onTap: () =>
              _actions.openOrder(context, Order()..id = contract.parentOrderId),
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
              config.serviceOrder,
              '${child.number ?? ''}',
            ),
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
        leading: StatusDot(color: done ? AppColors.success : AppColors.warning),
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
          child: const Icon(
            CupertinoIcons.delete,
            color: CupertinoColors.white,
          ),
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

  String _price(double? value) => value == null
      ? context.l10n.catalogNoPrice
      : _format.formatCurrency(value);

  Widget _buildStatusRow(SegmentConfigProvider config, {bool inBlock = false}) {
    final l10n = context.l10n;
    final status = _store.status;
    final due = _store.order?.dueDate;
    final overdue =
        due != null &&
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
            padding: inBlock
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(
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
                        color: inBlock
                            ? AppColors.onAccentSoft.resolveFrom(context)
                            : AppColors.textSecondary.resolveFrom(context),
                        fontWeight: inBlock ? FontWeight.w600 : null,
                      ),
                      children: [
                        if (overdue)
                          TextSpan(
                            text: ' · ${l10n.orderOverdue}',
                            style: AppTypography.callout.copyWith(
                              fontWeight: FontWeight.w700,
                              color: OrderStatusStyle.overdueColor.resolveFrom(
                                context,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Text(
                  l10n.orderChangeStatusLink,
                  style: AppTypography.callout.copyWith(
                    color: inBlock
                        ? AppColors.onAccentSoft.resolveFrom(context)
                        : AppColors.accentText.resolveFrom(context),
                    decoration: inBlock ? TextDecoration.underline : null,
                    decorationColor: AppColors.onAccentSoft.resolveFrom(
                      context,
                    ),
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
        return toStatus(
          l10n.orderNextStepQuote,
          l10n.orderNextStepQuoteAction,
          'approved',
        );
      case 'approved':
        return toStatus(
          l10n.orderNextStepApproved,
          l10n.orderNextStepApprovedAction,
          'progress',
        );
      case 'progress':
        return toStatus(
          l10n.orderNextStepProgress,
          l10n.orderNextStepProgressAction,
          'done',
        );
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
        return toStatus(
          l10n.orderNextStepCanceled(config.serviceOrder),
          l10n.orderNextStepReopen,
          'quote',
        );
    }
    return null;
  }

  Widget _buildNextStep(_NextStep step, SegmentConfigProvider config) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.blockMargin,
        AppSpacing.sm,
        AppSpacing.blockMargin,
        0,
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
            _buildStatusRow(config, inBlock: true),
            const SizedBox(height: AppSpacing.xs),
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
    final showPayment =
        !_isNew && !const ['quote', 'canceled'].contains(_store.status);
    final remaining = _store.remainingBalance;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageMargin,
            ),
            color: AppColors.separator.resolveFrom(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageMargin,
              AppSpacing.md,
              AppSpacing.pageMargin,
              0,
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
                AppSpacing.pageMargin,
                AppSpacing.xs,
                AppSpacing.pageMargin,
                0,
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
                AppSpacing.pageMargin,
                AppSpacing.xs,
                AppSpacing.pageMargin,
                0,
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
                      _format.formatCurrency(remaining),
                    )
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
                if (_assistantBusy)
                  _AssistantBusy(label: l10n.orderAssistantReading)
                else
                  _AssistantButtons(
                    hint: _hasContent ? null : l10n.orderAssistantHint,
                    onPhoto: _onPhoto,
                    onTalk: () => _openAssistant(),
                  ),
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

/// Applies the answer of [DevicePickerSheet] to the store so the next
/// `addService`/`addProduct` goes to the chosen vehicle(s): one, several,
/// all (a copy each) or general (none).
void applyDevicePick(OrderStore store, DevicePickerResult result) {
  store
    ..pendingDeviceId = null
    ..pendingDuplicateAll = false
    ..pendingDeviceIds = null;
  switch (result.action) {
    case DevicePickerAction.specific:
      store.pendingDeviceId = result.device?.id;
    case DevicePickerAction.all:
      store.pendingDuplicateAll = true;
    case DevicePickerAction.multiSpecific:
      store.pendingDeviceIds = result.deviceIds;
    case DevicePickerAction.general:
      break;
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
    store.addService(
      OrderService()
        ..service = aggr
        ..value = item.value,
    );
  } else {
    final origin = item.origin;
    final aggr = origin is Product
        ? origin.toAggr()
        : (ProductAggr()
            ..id = item.id
            ..name = item.name
            ..value = item.value
            ..photo = item.photo);
    store.addProduct(
      OrderProduct()
        ..product = aggr
        ..value = item.value
        ..quantity = 1
        ..total = item.value,
    );
  }
}

/// Foto (glass) and "Falar o que fazer" (graphite), floating above
/// "Salvar OS". The camera opens only when Foto is tapped.
class _AssistantButtons extends StatelessWidget {
  const _AssistantButtons({
    required this.onPhoto,
    required this.onTalk,
    this.hint,
  });

  final VoidCallback onPhoto;
  final VoidCallback onTalk;

  /// "Tire foto da placa e fale o serviço" while the order is blank.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppColors.text.resolveFrom(context);
    final onAssistant = AppColors.onAssistantFill.resolveFrom(context);
    final radius = BorderRadius.circular(AppRadii.button);
    Widget label(IconData icon, String value, Color color) => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            value,
            style: AppTypography.callout.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              hint!,
              textAlign: TextAlign.center,
              style: AppTypography.label.copyWith(
                color: AppColors.textSecondary.resolveFrom(context),
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: AppGlass(
                borderRadius: radius,
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  minimumSize: const Size.fromHeight(52),
                  borderRadius: radius,
                  onPressed: onPhoto,
                  child: label(
                    CupertinoIcons.camera,
                    l10n.orderPhotoAction,
                    text,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 2,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                minimumSize: const Size.fromHeight(52),
                color: AppColors.assistantFill.resolveFrom(context),
                borderRadius: radius,
                onPressed: onTalk,
                child: label(
                  CupertinoIcons.mic,
                  l10n.orderTalkAction,
                  onAssistant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AssistantBusy extends StatelessWidget {
  const _AssistantBusy({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return AppGlass(
      borderRadius: BorderRadius.circular(AppRadii.button),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CupertinoActivityIndicator(),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                label,
                style: AppTypography.callout.copyWith(
                  color: AppColors.text.resolveFrom(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Large title and the line under it of an existing order.
typedef OrderHeaderTexts = ({String title, String? subtitle});

/// app-os header: the vehicle as the title and "Cliente · OS 186" under it.
/// Without a vehicle the customer takes the title; without either, the
/// order label does.
OrderHeaderTexts orderHeaderTexts({
  String? deviceName,
  String? customerName,
  required String orderLabel,
}) {
  final device = deviceName?.trim() ?? '';
  final customer = customerName?.trim() ?? '';
  if (device.isNotEmpty) {
    return (
      title: device,
      subtitle: customer.isEmpty ? orderLabel : '$customer · $orderLabel',
    );
  }
  if (customer.isNotEmpty) return (title: customer, subtitle: orderLabel);
  return (title: orderLabel, subtitle: null);
}
