import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/customer_charge.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_charge.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/repositories/tenant/customer_charge_repository.dart';
import 'package:praticos/repositories/tenant/order_charge_repository.dart';
import 'package:praticos/repositories/tenant/payment_settings_repository.dart';
import 'package:praticos/repositories/v2/order_repository_v2.dart';
import 'package:praticos/screens/integrations/asaas_connection_screen.dart'
    show safePaymentSettings;
import 'package:praticos/screens/payments/asaas_error_text.dart';
import 'package:praticos/screens/payments/create_customer_charge_screen.dart';
import 'package:praticos/screens/payments/widgets/order_charge_card.dart';
import 'package:praticos/screens/payments/widgets/receive_amount_field.dart';
import 'package:praticos/screens/payments/widgets/receive_date_row.dart'
    show paidAtFor;
import 'package:praticos/screens/payments/widgets/receive_payment_sheet.dart';
import 'package:praticos/screens/payments/widgets/receive_summary.dart';
import 'package:praticos/screens/widgets/app_list_row.dart'
    show kAppListRowStackScale;
import 'package:praticos/screens/widgets/app_toast.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/screens/widgets/pull_down_menu.dart';
import 'package:praticos/screens/widgets/secondary_button.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/services/asaas_api_service.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/customer_receipt_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/pdf/receipt_pdf.dart'
    show orderShortDescription;
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/utils/payment_allocation.dart';
import 'package:praticos/widgets/permission_widgets.dart';
import 'package:share_plus/share_plus.dart';

/// Whether "Mandar cobrança" goes through Asaas: the user may charge
/// (`chargeOrder`), the company is in the pilot and connected, and there is
/// a customer to charge.
bool customerChargeReady({
  required bool canCharge,
  required bool asaasEnabled,
  required bool asaasConnected,
  required String? customerId,
}) => canCharge && asaasEnabled && asaasConnected && customerId != null;

/// What a customer owes on several orders and the two ways out: "Marcar
/// como recebido" (the money already came in) and "Mandar cobrança" (it did
/// not, with Asaas connected).
///
/// On top the customer, what is "A receber" on the orders checked and the
/// two buttons; below, the orders. Tapping a row toggles its check; its ⓘ
/// opens the order. How much, when and the receipt are in
/// [ReceivePaymentSheet], which goes only after the person says it was paid;
/// the payment is split oldest order first ([allocatePayment]). On success
/// it shows a toast and pops with `true`. Pushed (not a sheet): it acts on
/// existing orders.
///
/// With a charge open, its status shows under the amount, the blue button
/// goes away (the customer is the one who acts) until it is overdue, and the
/// "…" copies or cancels it. A consultant also sees "Outras OS de João"
/// (orders someone else created, only number and open amount, read from the
/// server), unchecked and not openable; checking one makes the save go
/// through the server, which needs connection.
class ReceiveCustomerScreen extends StatefulWidget {
  const ReceiveCustomerScreen({
    super.key,
    required this.orders,
    this.checkedOrderIds,
    this.customer,
    this.customerName,
    this.service,
    this.canAttachReceipt,
    this.pickReceipt,
    this.chargeReady,
    this.openCharge,
    this.createCharge,
    this.shareLink,
    this.api,
    this.otherOrdersLoader,
    this.reloadOrder,
    this.orderCharges,
    this.startCharge = false,
  });

  /// Open single-order links by order id (tests). Defaults to Firestore.
  final Stream<Map<String, OrderCharge>>? orderCharges;

  /// Opens "Mandar cobrança" as soon as the screen knows there is no open
  /// charge ("Próxima cobrança" of the Financeiro).
  final bool startCharge;

  /// Reads an order again after it was opened from its ⓘ (tests). Defaults
  /// to Firestore.
  final Future<Order?> Function(String orderId)? reloadOrder;

  /// Whether "Mandar cobrança" is available (tests). Defaults to the
  /// `chargeOrder` permission plus the company's `settings/payments`.
  final Future<bool> Function()? chargeReady;

  /// The customer's open multi-order charge (tests). Defaults to Firestore.
  final Stream<CustomerCharge?>? openCharge;

  /// Opens the "Mandar cobrança" sheet (tests). Completes with the created
  /// charge or null.
  final Future<CustomerCharge?> Function(
    BuildContext context,
    List<OpenBalance> balances,
    double value,
  )?
  createCharge;

  /// Shares a link (tests). Defaults to the share sheet.
  final Future<void> Function(BuildContext context, String url)? shareLink;

  /// Payment endpoints (tests).
  final AsaasApiService? api;

  /// Open orders of the customer as the server lists them (tests). Defaults
  /// to the server for a consultant, nothing for financial roles (they
  /// already get every order).
  final Future<List<CustomerOpenOrder>> Function()? otherOrdersLoader;

  /// Open orders of the customer, oldest first (as `Debtor.openOrders`).
  final List<Order> orders;

  /// Orders that start checked; null checks all of [orders]. Coming from A
  /// receber it is the completed ones, so the screen opens with the amount of
  /// the row that was tapped and the others stay one tap away.
  final Set<String>? checkedOrderIds;
  final CustomerAggr? customer;

  /// Falls back to [customer]'s name.
  final String? customerName;

  /// Injected in tests.
  final CustomerReceiptService? service;

  /// Overrides the `attachPhotos` permission (tests).
  final bool? canAttachReceipt;

  /// Overrides the camera/gallery/files picker (tests).
  final Future<PickedReceiptFile?> Function(BuildContext context)? pickReceipt;

  /// Pushes the screen; completes with true when a payment was recorded.
  /// Unless the person can receive on every one of [orders]
  /// ([AuthorizationService.canReceiveOnOrder]: financial access, or a
  /// consultant on their own orders) it shows "access denied" instead.
  /// [canReceive] overrides that check (tests).
  static Future<bool> open(
    BuildContext context, {
    required List<Order> orders,
    Set<String>? checkedOrderIds,
    CustomerAggr? customer,
    String? customerName,
    bool? canAttachReceipt,
    bool? canReceive,
    bool startCharge = false,
  }) async {
    final done = await Navigator.of(context, rootNavigator: true).push<bool>(
      CupertinoPageRoute<bool>(
        settings: const RouteSettings(name: '/receive_customer'),
        builder: (context) {
          final screen = ReceiveCustomerScreen(
            orders: orders,
            checkedOrderIds: checkedOrderIds,
            customer: customer,
            customerName: customerName,
            canAttachReceipt: canAttachReceipt,
            startCharge: startCharge,
          );
          final allowed =
              canReceive ??
              (orders.isNotEmpty &&
                  orders.every(
                    AuthorizationService.instance.canReceiveOnOrder,
                  ));
          return allowed
              ? screen
              : AccessDeniedScreen(onBack: () => Navigator.of(context).pop());
        },
      ),
    );
    return done ?? false;
  }

  /// Whether the logged-in person can send this customer an Asaas charge.
  static Future<bool> chargeAvailable(String? customerId) async {
    final companyId = Global.companyAggr?.id;
    if (companyId == null || Global.currentUser == null) return false;
    final canCharge = AuthorizationService.instance.hasPermission(
      PermissionType.chargeOrder,
    );
    if (!canCharge) return false;
    final settings = await safePaymentSettings(
      PaymentSettingsRepository().watch(companyId),
    ).first.timeout(const Duration(seconds: 8));
    return customerChargeReady(
      canCharge: canCharge,
      asaasEnabled: settings.asaasEnabled,
      asaasConnected: settings.asaasConnected,
      customerId: customerId,
    );
  }

  @override
  State<ReceiveCustomerScreen> createState() => _ReceiveCustomerScreenState();
}

class _ReceiveCustomerScreenState extends State<ReceiveCustomerScreen> {
  /// The customer's orders, refreshed after one is opened from its ⓘ.
  late final List<Order> _orders = List.of(widget.orders);

  List<OpenBalance> get _balances => [
    for (final order in _orders) OpenBalance.ofOrder(order),
  ].where((b) => b.open > 0).toList();

  /// Orders checked in "Está pagando". Starts with the customer's own open
  /// orders ([ReceiveCustomerScreen.checkedOrderIds] when set); "Outras OS"
  /// start unchecked.
  late final Set<String> _checked = {
    for (final b in _balances)
      if (widget.checkedOrderIds?.contains(b.orderId) ?? true) b.orderId,
  };

  /// What was filled in the sheet: kept when saving fails.
  ReceiveDraft? _draft;

  /// "Outras OS de João": open orders someone else created (consultant).
  List<CustomerOpenOrder> _others = const [];

  bool _chargeReady = false;
  CustomerCharge? _openCharge;
  StreamSubscription<CustomerCharge?>? _chargeSub;

  /// Open single-order links, by order id.
  Map<String, OrderCharge> _orderCharges = const {};
  final List<StreamSubscription<dynamic>> _orderChargeSubs = [];
  final Map<String, OrderCharge> _orderChargesSeen = {};
  bool _startedCharge = false;

  /// Every order that can be checked, oldest first: the screen's and the
  /// others (as light [Order]s with only id, number, open and date).
  List<Order> get _allOrders {
    final own = [
      for (final b in _balances)
        for (final o in _orders)
          if (o.id == b.orderId) o,
    ];
    if (_others.isEmpty) return own;
    final all = [...own, for (final other in _others) _otherAsOrder(other)];
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    all.sort((a, b) {
      final byDate = (a.createdAt ?? epoch).compareTo(b.createdAt ?? epoch);
      return byDate != 0 ? byDate : (a.number ?? 0).compareTo(b.number ?? 0);
    });
    return all;
  }

  static Order _otherAsOrder(CustomerOpenOrder other) => Order()
    ..id = other.id
    ..number = other.number
    ..total = other.open
    ..paidAmount = 0
    ..createdAt = other.createdAt;

  /// Balances the payment goes to (the checked ones, oldest first).
  List<OpenBalance> get _active => [
    for (final order in _allOrders)
      if (_checked.contains(order.id)) OpenBalance.ofOrder(order),
  ].where((b) => b.open > 0).toList();

  /// Whether the checked orders include someone else's (save via server).
  bool get _includesOthers => _others.any((o) => _checked.contains(o.id));

  /// Most that can be received now: what is open on [_active].
  double get _max => totalOpen(_active);

  /// Open orders listed (own and others).
  int get _openCount => _balances.length + _others.length;

  /// With one open order there is nothing to choose: no check, no toggle.
  bool get _selectable => _openCount > 1;

  bool _busy = false;

  bool get _canAttach =>
      widget.canAttachReceipt ??
      AuthorizationService.instance.hasPermission(PermissionType.attachPhotos);

  bool get _canSendLink => _chargeReady && widget.customer?.id != null;

  String get _name =>
      widget.customerName ??
      widget.customer?.name ??
      context.l10n.customerWithoutName;

  @override
  void initState() {
    super.initState();
    _loadCharge();
    _loadOthers();
  }

  @override
  void dispose() {
    _chargeSub?.cancel();
    for (final sub in _orderChargeSubs) {
      sub.cancel();
    }
    super.dispose();
  }

  Future<void> _loadCharge() async {
    bool ready;
    try {
      ready = await (widget.chargeReady ?? _defaultChargeReady)();
    } catch (_) {
      ready = false;
    }
    if (!mounted || !ready) return;
    setState(() => _chargeReady = true);
    final customerId = widget.customer?.id;
    final companyId = Global.companyAggr?.id;
    final stream =
        widget.openCharge ??
        (companyId == null || customerId == null
            ? null
            : CustomerChargeRepository().watchOpen(companyId, customerId));
    _chargeSub = stream?.listen((charge) {
      if (!mounted) return;
      setState(() => _openCharge = charge);
      if (widget.startCharge && !_startedCharge) {
        _startedCharge = true;
        if (charge == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _sendCharge();
          });
        }
      }
    }, onError: (Object _) {});
    _watchOrderCharges();
  }

  /// The single-order links of these orders: they show on the rows, and a
  /// new charge replaces them. Read only with `chargeOrder`, as the rules ask.
  void _watchOrderCharges() {
    final source = widget.orderCharges;
    if (source != null) {
      _orderChargeSubs.add(
        source.listen((charges) {
          if (mounted) setState(() => _orderCharges = charges);
        }, onError: (Object _) {}),
      );
      return;
    }
    final companyId = Global.companyAggr?.id;
    if (companyId == null) return;
    for (final balance in _balances) {
      final orderId = balance.orderId;
      _orderChargeSubs.add(
        OrderChargeRepository().watch(companyId, orderId).listen((charges) {
          if (!mounted) return;
          final current = OrderCharge.current(charges);
          if (current != null && current.isOpen) {
            _orderChargesSeen[orderId] = current;
          } else {
            _orderChargesSeen.remove(orderId);
          }
          setState(() => _orderCharges = Map.of(_orderChargesSeen));
        }, onError: (Object _) {}),
      );
    }
  }

  Future<bool> _defaultChargeReady() =>
      ReceiveCustomerScreen.chargeAvailable(widget.customer?.id);

  Future<void> _loadOthers() async {
    List<CustomerOpenOrder> listed;
    try {
      final loader = widget.otherOrdersLoader ?? _defaultOthersLoader();
      if (loader == null) return;
      listed = await loader();
    } catch (_) {
      // Offline or server error: the screen works with the own orders.
      return;
    }
    final mine = {for (final b in _balances) b.orderId};
    final others = [
      for (final o in listed)
        if (!o.own && !mine.contains(o.id) && o.open > 0) o,
    ];
    if (mounted && others.isNotEmpty) setState(() => _others = others);
  }

  /// Only a consultant (receives on their own orders) needs the server
  /// list; financial roles already have every order of the customer.
  Future<List<CustomerOpenOrder>> Function()? _defaultOthersLoader() {
    final customerId = widget.customer?.id;
    if (customerId == null || Global.currentUser == null) return null;
    final auth = AuthorizationService.instance;
    if (!auth.isConsultant ||
        auth.hasPermission(PermissionType.viewFinancialReports)) {
      return null;
    }
    final api = widget.api ?? AsaasApiService.instance;
    return () => api.listCustomerOpenOrders(customerId);
  }

  Future<void> _share(String url) =>
      (widget.shareLink ?? _defaultShare)(context, url);

  static Future<void> _defaultShare(BuildContext context, String url) async {
    await SharePlus.instance.share(ShareParams(text: url));
  }

  /// "Mandar cobrança": one link for the checked own orders, then the share
  /// sheet. A single-order link of those orders is replaced by this one, so
  /// the person confirms first.
  Future<void> _sendCharge() async {
    final customer = widget.customer;
    final balances = _active
        .where((b) => !_others.any((o) => o.id == b.orderId))
        .toList();
    if (customer == null || balances.isEmpty) return;
    if (balances.any((b) => _orderCharges.containsKey(b.orderId)) &&
        !await _confirmReplace()) {
      return;
    }
    if (!mounted) return;
    final created =
        await (widget.createCharge ??
            (context, balances, value) => FormSheet.show<CustomerCharge>(
              context,
              (_) => CreateCustomerChargeScreen(
                customer: customer,
                balances: balances,
                initialValue: value,
                service: widget.api,
              ),
            ))(context, balances, totalOpen(balances));
    if (created == null || !mounted) return;
    setState(() => _openCharge = created);
    if (created.invoiceUrl != null) await _share(created.invoiceUrl!);
  }

  Future<bool> _confirmReplace() async {
    final replace = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(dialogContext.l10n.chargeReplaceTitle),
        content: Text(dialogContext.l10n.chargeReplaceConfirm),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.cancel),
          ),
          CupertinoDialogAction(
            key: const Key('receiveCustomerChargeReplace'),
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.chargeReplace),
          ),
        ],
      ),
    );
    return replace == true;
  }

  /// "Mandar de novo": the same link, no new charge.
  Future<void> _resendCharge() async {
    final url = _openCharge?.invoiceUrl;
    if (url != null) await _share(url);
  }

  /// The "…" of the top bar, only with a charge open.
  Future<void> _showMenu() async {
    final l10n = context.l10n;
    final charge = _openCharge;
    if (charge == null) return;
    final choice = await showPullDownMenu(
      context,
      groups: [
        PullDownGroup([
          PullDownItem(
            value: 'copy',
            label: l10n.chargeCopyLink,
            icon: CupertinoIcons.doc_on_doc,
          ),
        ]),
        PullDownGroup([
          PullDownItem(
            value: 'cancel',
            label: l10n.chargeCancelLink,
            icon: CupertinoIcons.xmark_circle,
            destructive: true,
          ),
        ]),
      ],
    );
    if (!mounted) return;
    final url = charge.invoiceUrl;
    if (choice == 'copy' && url != null) {
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        showAppToast(
          context,
          l10n.chargeLinkCopied,
          icon: CupertinoIcons.checkmark_circle,
        );
      }
    }
    if (choice == 'cancel') _confirmCancelCharge(charge);
  }

  void _confirmCancelCharge(CustomerCharge charge) {
    final l10n = context.l10n;
    final amount = FormatService().formatCurrency(charge.value ?? 0);
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(l10n.receiveCustomerChargeCancelTitle(amount)),
        content: Text(l10n.chargeCancelConfirm),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.chargeKeepLink(amount)),
          ),
          CupertinoDialogAction(
            key: const Key('receiveCustomerChargeCancelConfirm'),
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(dialogContext);
              _cancelCharge(charge);
            },
            child: Text(l10n.chargeCancelLink),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelCharge(CustomerCharge charge) async {
    final l10n = context.l10n;
    final customerId = widget.customer?.id;
    final chargeId = charge.id;
    if (customerId == null || chargeId == null) return;
    setState(() => _busy = true);
    try {
      await (widget.api ?? AsaasApiService.instance).cancelCustomerCharge(
        customerId,
        chargeId,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _openCharge = null;
      });
      showAppToast(
        context,
        l10n.receiveCustomerChargeCanceled,
        icon: CupertinoIcons.checkmark_circle,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showAppToast(
        context,
        e is AsaasApiException
            ? asaasErrorText(l10n, e)
            : l10n.asaasErrorGeneric,
        icon: CupertinoIcons.exclamationmark_circle,
      );
    }
  }

  int _cents(double value) => (value * 100).round();

  /// Checks or unchecks an order; the amount at the top follows.
  void _toggle(String id) {
    setState(() {
      if (!_checked.remove(id)) _checked.add(id);
      _draft = null;
    });
  }

  /// Opens one of the customer's own orders (its ⓘ; "Outras OS" cannot be
  /// read). Coming back reads the order again, so a change made there (a
  /// payment, a new total) shows in the rows.
  Future<void> _openOrder(Order order) async {
    final id = order.id;
    if (id == null) return;
    await Navigator.of(
      context,
    ).pushNamed('/order', arguments: {'order': order});
    if (!mounted) return;
    Order? fresh;
    try {
      fresh = await (widget.reloadOrder ?? _defaultReload)(id);
    } catch (_) {
      // Offline or no access: keep what the screen had.
      return;
    }
    if (fresh == null || !mounted) return;
    final index = _orders.indexWhere((o) => o.id == id);
    if (index < 0) return;
    setState(() {
      _orders[index] = fresh!;
    });
  }

  static Future<Order?> _defaultReload(String orderId) async {
    final companyId = Global.companyAggr?.id;
    if (companyId == null) return null;
    return OrderRepositoryV2().getSingle(companyId, orderId);
  }

  /// Reads the screen's own orders in [active] from the server and, when
  /// what is open on any of them changed (a link paid, someone else
  /// received), puts the fresh orders on screen and returns true: nothing
  /// is written, the person checks the new amounts. Offline it returns
  /// false and the receipt goes on as before.
  Future<bool> _refreshChangedBalances(
    CustomerReceiptService service,
    List<OpenBalance> active,
  ) async {
    final ownIds = {for (final o in _orders) o.id};
    final ids = [
      for (final b in active)
        if (ownIds.contains(b.orderId)) b.orderId,
    ];
    if (ids.isEmpty) return false;
    final fresh = await service.readFromServer(ids);
    if (fresh == null || !mounted) return false;
    final before = {for (final b in active) b.orderId: _cents(b.open)};
    var changed = false;
    for (var i = 0; i < _orders.length; i++) {
      final id = _orders[i].id;
      if (!ids.contains(id)) continue;
      final order = fresh[id];
      final open = order == null ? 0 : _cents(OpenBalance.ofOrder(order).open);
      if (open == before[id]) continue;
      changed = true;
      if (order != null) _orders[i] = order;
    }
    if (!changed) return false;
    _orders.removeWhere((o) => ids.contains(o.id) && fresh[o.id] == null);
    setState(() => _draft = null);
    return true;
  }

  /// What the amount does, in one sentence: oldest orders first.
  String? _preview(double amount) {
    final l10n = context.l10n;
    final active = _active;
    final previews = previewAllocation(active, allocatePayment(active, amount));
    if (active.length < 2) return null;
    if (previews.every((p) => p.settles)) {
      return l10n.receivePreviewAll(active.length);
    }
    final format = FormatService();
    final settled = [
      for (final p in previews)
        if (p.settles) '${p.balance.orderNumber ?? '?'}',
    ];
    return [
      if (settled.isNotEmpty) l10n.receivePreviewSettles(settled.join(', ')),
      for (final p in previews)
        if (!p.settles && !p.untouched)
          l10n.receivePreviewPart(
            format.formatCurrency(p.received),
            '${p.balance.orderNumber ?? '?'}',
          ),
      l10n.receivePreviewLeft(format.formatCurrency(_max - amount)),
    ].join(' ');
  }

  /// "Marcar como recebido": the sheet, then saving what came back.
  Future<void> _openReceive() async {
    if (_busy || _active.isEmpty) return;
    final l10n = context.l10n;
    final draft = await ReceivePaymentSheet.show(
      context,
      title: l10n.receiveReceivedFrom(_name),
      max: _max,
      preview: _preview,
      initial: _draft,
      canAttach: _canAttach,
      pickReceipt: widget.pickReceipt,
      note: _openCharge == null ? null : l10n.receiveChargeAdjusts(_name),
    );
    if (draft == null || !mounted) return;
    _draft = draft;
    await _confirm(draft);
  }

  Future<void> _confirm(ReceiveDraft draft) async {
    final value = draft.amount;
    final active = _active;
    if (_busy || active.isEmpty || value <= 0 || _cents(value) > _cents(_max)) {
      return;
    }
    final l10n = context.l10n;
    setState(() => _busy = true);
    final service = widget.service ?? CustomerReceiptService();
    if (await _refreshChangedBalances(service, active)) {
      if (!mounted) return;
      setState(() => _busy = false);
      showAppToast(
        context,
        l10n.receiveCustomerBalanceChanged,
        icon: CupertinoIcons.exclamationmark_circle,
      );
      return;
    }
    if (!mounted) return;
    final allocations = allocatePayment(active, value);
    final request = CustomerReceiptRequest(
      customer: widget.customer,
      orders: _orders,
      allocations: allocations,
      paidAt: paidAtFor(draft.paidDay),
      file: draft.receipt,
    );
    try {
      // Someone else's order: only the server may write it (online).
      if (_includesOthers) {
        await service.recordOnline(request);
      } else {
        await service.record(request);
      }
    } on CustomerReceiptException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showAppToast(context, switch (e.reason) {
        CustomerReceiptFailure.upload => l10n.receiveCustomerUploadFailed,
        CustomerReceiptFailure.offline => l10n.receiveCustomerOffline,
        CustomerReceiptFailure.failed => l10n.paymentUpdateFailed,
      }, icon: CupertinoIcons.exclamationmark_circle);
      return;
    }
    if (!mounted) return;
    showAppToast(
      context,
      l10n.receiveCustomerDone(ReceiveAmountField.textFor(value), _name),
      icon: CupertinoIcons.checkmark_circle,
    );
    Navigator.of(context).pop(true);
  }

  String _summaryLabel() {
    final l10n = context.l10n;
    final checked = _active.length;
    return checked == _openCount
        ? l10n.receiveSummaryCount(_openCount)
        : l10n.receiveSummarySome(checked, _openCount);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final charge = _openCharge;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.groupedBackground.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppNavBar.barBackground(context),
        border: null,
        trailing: !_busy && charge != null
            ? GlassBarButton(
                key: const Key('receiveCustomerMenu'),
                label: l10n.receiveMoreOptions,
                icon: CupertinoIcons.ellipsis,
                onPressed: _showMenu,
              )
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
            ),
            children: [
              ReceiveSummary(
                titleKey: const Key('receiveCustomerTitle'),
                title: _name,
                label: _summaryLabel(),
                amount: FormatService().formatCurrency(_max),
              ),
              if (charge != null) _buildChargeStatus(charge),
              _buildActions(),
              _buildOrdersSection(
                header: l10n.receiveOrdersIncluded,
                orders: [
                  for (final b in _balances)
                    for (final o in _orders)
                      if (o.id == b.orderId) o,
                ],
                own: true,
              ),
              if (_others.isNotEmpty)
                _buildOrdersSection(
                  header: l10n.receiveCustomerOthersTitle(_name),
                  footer: l10n.receiveCustomerOthersNote,
                  footerKey: const Key('receiveCustomerOthersNote'),
                  orders: [for (final o in _others) _otherAsOrder(o)],
                  own: false,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The one or two buttons under the amount. With a charge open nothing is
  /// blue while the customer has time to pay; overdue, the next step is ours.
  Widget _buildActions() {
    final l10n = context.l10n;
    final charge = _openCharge;
    final canAct = !_busy && _active.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.blockMargin,
        0,
        AppSpacing.blockMargin,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_busy)
            const SizedBox(
              height: AppSizes.primaryButtonHeight,
              child: Center(child: CupertinoActivityIndicator()),
            )
          else if (charge == null) ...[
            PrimaryButton(
              key: const Key('receiveCustomerConfirm'),
              label: l10n.receiveMarkReceived,
              onPressed: canAct ? _openReceive : null,
            ),
            if (_canSendLink) ...[
              const SizedBox(height: AppSpacing.sm),
              SecondaryButton(
                key: const Key('receiveCustomerSendCharge'),
                label: l10n.chargeSend,
                onPressed: canAct ? _sendCharge : null,
              ),
            ],
          ] else ...[
            if (charge.status == 'overdue')
              PrimaryButton(
                key: const Key('receiveCustomerResend'),
                label: l10n.chargeSendAgain,
                onPressed: _resendCharge,
              )
            else
              SecondaryButton(
                key: const Key('receiveCustomerResend'),
                label: l10n.chargeSendAgain,
                onPressed: _resendCharge,
              ),
            const SizedBox(height: AppSpacing.xs),
            Center(
              child: TextLink(
                key: const Key('receiveCustomerConfirm'),
                label: l10n.receiveMarkReceived,
                onPressed: canAct ? _openReceive : null,
              ),
            ),
          ],
          if (_active.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: _sectionText(
                l10n.receiveCustomerNoneChecked,
                key: const Key('receiveCustomerHint'),
                color: AppColors.danger.resolveFrom(context),
                bold: true,
              ),
            ),
        ],
      ),
    );
  }

  CupertinoListSection _section({
    Widget? header,
    Widget? footer,
    required List<Widget> children,
    bool hasLeading = false,
    Key? key,
  }) {
    return CupertinoListSection.insetGrouped(
      key: key,
      header: header,
      footer: footer,
      hasLeading: hasLeading,
      backgroundColor: AppColors.groupedBackground.resolveFrom(context),
      decoration: BoxDecoration(
        color: AppColors.surface.resolveFrom(context),
        borderRadius: BorderRadius.circular(AppRadii.field),
      ),
      separatorColor: AppColors.separator.resolveFrom(context),
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.blockMargin,
        0,
        AppSpacing.blockMargin,
        AppSpacing.sm,
      ),
      children: children,
    );
  }

  Widget _sectionText(
    String text, {
    Key? key,
    Color? color,
    bool bold = false,
  }) {
    return Text(
      text,
      key: key,
      style: AppTypography.label.copyWith(
        color: color ?? AppColors.textSecondary.resolveFrom(context),
        fontWeight: bold ? FontWeight.w600 : null,
      ),
    );
  }

  /// The open multi-order charge: who the app is waiting for and what was
  /// charged. Its actions are the buttons under it and the "…".
  Widget _buildChargeStatus(CustomerCharge charge) {
    final l10n = context.l10n;
    final format = FormatService();
    final value = format.formatCurrency(charge.value ?? 0);
    final due = charge.dueDay == null ? '-' : format.formatDate(charge.dueDay);
    final overdue = charge.status == 'overdue';
    return ChargeStatusCard(
      key: const Key('receiveCustomerOpenCharge'),
      overdue: overdue,
      status: overdue
          ? l10n.chargeExpiredOn(due)
          : l10n.chargeWaitingFor(_name),
      detail: overdue
          ? l10n.chargeDetailOverdue(value)
          : l10n.chargeDetailUntil(value, due),
    );
  }

  /// The customer's own orders, openable by their ⓘ, or "Outras OS de João"
  /// (someone else's, not openable).
  Widget _buildOrdersSection({
    required String header,
    String? footer,
    Key? footerKey,
    required List<Order> orders,
    required bool own,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: _section(
        hasLeading: _selectable,
        header: _sectionText(header),
        footer: footer == null ? null : _sectionText(footer, key: footerKey),
        children: [for (final order in orders) _buildOrderRow(order, own: own)],
      ),
    );
  }

  Widget _buildOrderRow(Order order, {required bool own}) {
    final l10n = context.l10n;
    final format = FormatService();
    final id = order.id ?? '';
    final checked = _checked.contains(id);
    final number = order.number ?? 0;
    final description = own ? orderShortDescription(order) : null;
    final title = description == null
        ? l10n.receiveCustomerPickRow(number)
        : l10n.receiveCustomerOrderRow(number, description);
    final open = format.formatCurrency(OpenBalance.ofOrder(order).open);
    // A single-order link is the one thing a row says beyond its amount.
    final charge = _orderCharges[id];
    final String? line = charge == null
        ? null
        : charge.status == ChargeStatus.overdue
        ? l10n.chargeExpiredOn(format.formatDayMonthOrDate(charge.dueDateValue))
        : l10n.chargeWaitingPayment;
    return _OrderCheckRow(
      key: Key(own ? 'receiveCustomerRow_$id' : 'receiveCustomerOther_$id'),
      id: id,
      title: title,
      amount: open,
      line: line,
      checked: checked,
      selectable: _selectable,
      onToggle: _busy || !_selectable ? null : () => _toggle(id),
      openLabel: own ? l10n.receiveCustomerOpenOrder(number) : null,
      onOpen: own && !_busy ? () => _openOrder(order) : null,
    );
  }
}

/// One order: check circle, "OS 15 · Fiat Uno", what is open on it and,
/// under, its open link if there is one. Tapping the row toggles the check; the ⓘ (own orders only) opens the order.
class _OrderCheckRow extends StatelessWidget {
  const _OrderCheckRow({
    super.key,
    required this.id,
    required this.title,
    required this.amount,
    required this.line,
    required this.checked,
    required this.selectable,
    required this.onToggle,
    required this.openLabel,
    required this.onOpen,
  });

  final String id;
  final String title;
  final String amount;
  final String? line;
  final bool checked;
  final bool selectable;
  final VoidCallback? onToggle;

  /// Null hides the ⓘ (someone else's order).
  final String? openLabel;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final text = AppColors.text.resolveFrom(context);
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final stacked =
        MediaQuery.textScalerOf(context).scale(100) / 100 >=
        kAppListRowStackScale;
    final dim = selectable && !checked;
    final amountText = Text(
      amount,
      style: AppTypography.body.copyWith(
        color: dim ? secondary : text,
        fontFeatures: AppTypography.tabular,
      ),
    );

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: AppTypography.body.copyWith(color: dim ? secondary : text),
        ),
        if (stacked)
          Padding(padding: const EdgeInsets.only(top: 2), child: amountText),
        if (line != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              line!,
              key: Key('receiveCustomerLine_$id'),
              style: AppTypography.callout.copyWith(color: secondary),
            ),
          ),
      ],
    );

    final toggleArea = Semantics(
      button: selectable,
      selected: selectable ? checked : null,
      child: GestureDetector(
        key: Key('receiveCustomerToggle_$id'),
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.md,
              0,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                if (selectable) ...[
                  Icon(
                    checked
                        ? CupertinoIcons.checkmark_circle_fill
                        : CupertinoIcons.circle,
                    key: Key('receiveCustomerCheck_$id'),
                    size: 26,
                    color: checked
                        ? AppColors.accent.resolveFrom(context)
                        : secondary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(child: main),
                if (!stacked) ...[
                  const SizedBox(width: AppSpacing.md),
                  amountText,
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Row(
      children: [
        Expanded(child: toggleArea),
        if (openLabel != null)
          CupertinoButton(
            key: Key('receiveCustomerInfo_$id'),
            padding: EdgeInsets.zero,
            minimumSize: const Size(
              AppSizes.minTouchTarget,
              AppSizes.minTouchTarget,
            ),
            onPressed: onOpen,
            child: Semantics(
              label: openLabel,
              button: true,
              excludeSemantics: true,
              child: Icon(
                CupertinoIcons.info_circle,
                size: 24,
                color: AppColors.accentText.resolveFrom(context),
              ),
            ),
          )
        else
          const SizedBox(width: AppSpacing.lg),
      ],
    );
  }
}
