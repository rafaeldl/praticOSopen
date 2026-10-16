import 'dart:async';

import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/customer_charge.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/repositories/tenant/customer_charge_repository.dart';
import 'package:praticos/repositories/tenant/payment_settings_repository.dart';
import 'package:praticos/repositories/v2/order_repository_v2.dart';
import 'package:praticos/screens/integrations/asaas_connection_screen.dart'
    show safePaymentSettings;
import 'package:praticos/screens/payments/asaas_error_text.dart';
import 'package:praticos/screens/payments/create_customer_charge_screen.dart';
import 'package:praticos/screens/payments/widgets/receipt_file_picker.dart';
import 'package:praticos/screens/payments/widgets/receive_amount_field.dart';
import 'package:praticos/screens/payments/widgets/receive_date_row.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/app_toast.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/screens/widgets/pull_down_menu.dart';
import 'package:praticos/services/asaas_api_service.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/customer_receipt_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/pdf/receipt_pdf.dart'
    show orderShortDescription;
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/utils/currency_input.dart';
import 'package:praticos/utils/payment_allocation.dart';
import 'package:praticos/widgets/permission_widgets.dart';
import 'package:share_plus/share_plus.dart';

/// Whether "Mandar link para pagar" goes through Asaas: the user may charge
/// (`chargeOrder`), the company is in the pilot and connected, and there is
/// a customer to charge.
bool customerChargeReady({
  required bool canCharge,
  required bool asaasEnabled,
  required bool asaasConnected,
  required String? customerId,
}) => canCharge && asaasEnabled && asaasConnected && customerId != null;

/// "Receber de João": one payment from a customer who owes on several
/// orders, split oldest order first ([allocatePayment]) over the orders
/// checked in "Está pagando".
///
/// An inset-grouped form: the amount (the only place it shows, starting at
/// the sum of the checked orders, never more), "Quando" and "Comprovante"
/// rows, the blue "Confirmar recebimento" and the "Está pagando" list. Each
/// order row toggles a check when tapped and says what this payment does to
/// it ("Quita", "Recebe R$ 300 · fica R$ 199,99"); its ⓘ opens the order.
/// On success it shows a toast and pops with `true`. Pushed (not a sheet):
/// it acts on existing orders.
///
/// With Asaas connected, the "…" has "Mandar link para pagar…" (one link for
/// the checked orders); an open link shows as a row on top and the "…" then
/// shares, copies or cancels it. A consultant also sees "Outras OS de João"
/// (orders someone else created, only number and open amount, read from the
/// server), unchecked and not openable; checking one makes the save go
/// through the server, which needs connection.
class ReceiveCustomerScreen extends StatefulWidget {
  const ReceiveCustomerScreen({
    super.key,
    required this.orders,
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
  });

  /// Reads an order again after it was opened from its ⓘ (tests). Defaults
  /// to Firestore.
  final Future<Order?> Function(String orderId)? reloadOrder;

  /// Whether "Mandar link para pagar" is available (tests). Defaults to the
  /// `chargeOrder` permission plus the company's `settings/payments`.
  final Future<bool> Function()? chargeReady;

  /// The customer's open multi-order charge (tests). Defaults to Firestore.
  final Stream<CustomerCharge?>? openCharge;

  /// Opens the "Link para pagar" sheet (tests). Completes with the created
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

  /// Open orders of the customer, oldest first (as `Debtor.orders`).
  final List<Order> orders;
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
    CustomerAggr? customer,
    String? customerName,
    bool? canAttachReceipt,
    bool? canReceive,
  }) async {
    final done = await Navigator.of(context, rootNavigator: true).push<bool>(
      CupertinoPageRoute<bool>(
        settings: const RouteSettings(name: '/receive_customer'),
        builder: (context) {
          final screen = ReceiveCustomerScreen(
            orders: orders,
            customer: customer,
            customerName: customerName,
            canAttachReceipt: canAttachReceipt,
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

  @override
  State<ReceiveCustomerScreen> createState() => _ReceiveCustomerScreenState();
}

class _ReceiveCustomerScreenState extends State<ReceiveCustomerScreen> {
  /// The customer's orders, refreshed after one is opened from its ⓘ.
  late final List<Order> _orders = List.of(widget.orders);

  List<OpenBalance> get _balances => [
    for (final order in _orders) OpenBalance.ofOrder(order),
  ].where((b) => b.open > 0).toList();

  /// Orders checked in "Está pagando". Starts with all of the customer's
  /// own open orders; "Outras OS" start unchecked.
  late final Set<String> _checked = {for (final b in _balances) b.orderId};

  late final TextEditingController _amount = TextEditingController(
    text: ReceiveAmountField.textFor(_max),
  );
  final FocusNode _amountFocus = FocusNode();

  /// The person typed an amount: checking orders no longer rewrites it.
  bool _typed = false;

  /// "Outras OS de João": open orders someone else created (consultant).
  List<CustomerOpenOrder> _others = const [];

  bool _chargeReady = false;
  CustomerCharge? _openCharge;
  StreamSubscription<CustomerCharge?>? _chargeSub;

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

  DateTime _paidDay = DateTime.now();
  PickedReceiptFile? _receipt;
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
    _amountFocus.addListener(_onFocus);
    _loadCharge();
    _loadOthers();
  }

  @override
  void dispose() {
    _chargeSub?.cancel();
    _amountFocus.removeListener(_onFocus);
    _amountFocus.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() {});
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
      if (mounted) setState(() => _openCharge = charge);
    }, onError: (Object _) {});
  }

  Future<bool> _defaultChargeReady() async {
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
      customerId: widget.customer?.id,
    );
  }

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

  /// "Mandar link para pagar…": shares the open link, or creates one for the
  /// checked own orders (the typed amount, never more than they owe) and
  /// shares it.
  Future<void> _sendCharge() async {
    final open = _openCharge;
    if (open?.invoiceUrl != null) {
      await _share(open!.invoiceUrl!);
      return;
    }
    final customer = widget.customer;
    final active = _active.where((b) => !_others.any((o) => o.id == b.orderId));
    final balances = active.toList();
    if (customer == null || balances.isEmpty) return;
    final typed = parseCurrencyInput(_amount.text);
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
            ))(context, balances, typed);
    if (created == null || !mounted) return;
    setState(() => _openCharge = created);
    if (created.invoiceUrl != null) await _share(created.invoiceUrl!);
  }

  /// The "…" of the top bar: the payment link, the rare path here.
  Future<void> _showMenu() async {
    final l10n = context.l10n;
    final charge = _openCharge;
    final choice = await showPullDownMenu(
      context,
      groups: [
        if (charge == null)
          PullDownGroup([
            PullDownItem(
              value: 'send',
              label: l10n.receiveCustomerSendLink,
              icon: CupertinoIcons.link,
            ),
          ])
        else ...[
          PullDownGroup([
            PullDownItem(
              value: 'share',
              label: l10n.receiveCustomerShareCharge,
              icon: CupertinoIcons.share,
            ),
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
      ],
    );
    if (!mounted || choice == null) return;
    if (choice == 'send') {
      await _sendCharge();
      return;
    }
    if (charge == null) return;
    final url = charge.invoiceUrl;
    if (choice == 'share' && url != null) await _share(url);
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

  Future<void> _pickDay() async {
    _amountFocus.unfocus();
    final day = await pickPaymentDay(context, _paidDay);
    if (day != null && mounted) setState(() => _paidDay = day);
  }

  Future<void> _attach() async {
    _amountFocus.unfocus();
    final picked = await (widget.pickReceipt ?? pickReceiptFile)(context);
    if (picked != null && mounted) setState(() => _receipt = picked);
  }

  /// Checks or unchecks an order. Until the person types an amount, the
  /// field follows the sum of the checked orders.
  void _toggle(String id) {
    setState(() {
      if (!_checked.remove(id)) _checked.add(id);
      if (!_typed) _amount.text = ReceiveAmountField.textFor(_max);
    });
  }

  /// Opens one of the customer's own orders (its ⓘ; "Outras OS" cannot be
  /// read). Coming back keeps what was typed and reads the order again, so a
  /// change made there (a payment, a new total) shows in the rows.
  Future<void> _openOrder(Order order) async {
    final id = order.id;
    if (id == null) return;
    _amountFocus.unfocus();
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
      if (!_typed) _amount.text = ReceiveAmountField.textFor(_max);
    });
  }

  static Future<Order?> _defaultReload(String orderId) async {
    final companyId = Global.companyAggr?.id;
    if (companyId == null) return null;
    return OrderRepositoryV2().getSingle(companyId, orderId);
  }

  Future<void> _confirm() async {
    final value = parseCurrencyInput(_amount.text);
    final active = _active;
    if (_busy || active.isEmpty || value <= 0 || _cents(value) > _cents(_max)) {
      return;
    }
    _amountFocus.unfocus();
    final l10n = context.l10n;
    final allocations = allocatePayment(active, value);
    setState(() => _busy = true);
    final service = widget.service ?? CustomerReceiptService();
    final request = CustomerReceiptRequest(
      customer: widget.customer,
      orders: _orders,
      allocations: allocations,
      paidAt: paidAtFor(_paidDay),
      file: _receipt,
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppColors.text.resolveFrom(context);
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final showMenu = !_busy && (_openCharge != null || _canSendLink);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.groupedBackground.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppNavBar.barBackground(context),
        border: null,
        trailing: showMenu
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
          child: Stack(
            children: [
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _amount,
                builder: (context, value, _) {
                  final amount = parseCurrencyInput(value.text);
                  final active = _active;
                  final tooMuch = _cents(amount) > _cents(_max);
                  final canSave =
                      !_busy && active.isNotEmpty && amount > 0 && !tooMuch;
                  final previews = {
                    for (final p in previewAllocation(
                      active,
                      canSave || _busy ? allocatePayment(active, amount) : [],
                    ))
                      p.balance.orderId: p,
                  };
                  final showLines = amount > 0 && !tooMuch;
                  return ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.paddingOf(context).bottom + 80,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.pageMargin,
                          AppSpacing.sm,
                          AppSpacing.pageMargin,
                          AppSpacing.xs,
                        ),
                        child: Semantics(
                          header: true,
                          child: Text(
                            l10n.receiveCustomerTitle(_name),
                            key: const Key('receiveCustomerTitle'),
                            style: AppTypography.title.copyWith(color: text),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.pageMargin,
                          0,
                          AppSpacing.pageMargin,
                          AppSpacing.sm,
                        ),
                        child: Text(
                          l10n.receiveCustomerOpenCount(_openCount),
                          key: const Key('receiveCustomerSentence'),
                          style: AppTypography.callout.copyWith(
                            color: secondary,
                          ),
                        ),
                      ),
                      if (_openCharge != null) _buildOpenCharge(_openCharge!),
                      _buildAmountSection(amount, tooMuch, active.isEmpty),
                      _buildDetailsSection(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.blockMargin,
                          AppSpacing.sm,
                          AppSpacing.blockMargin,
                          AppSpacing.md,
                        ),
                        child: _busy
                            ? const SizedBox(
                                height: AppSizes.primaryButtonHeight,
                                child: Center(
                                  child: CupertinoActivityIndicator(),
                                ),
                              )
                            : PrimaryButton(
                                key: const Key('receiveCustomerConfirm'),
                                label: l10n.receiveConfirmButton,
                                onPressed: canSave ? _confirm : null,
                              ),
                      ),
                      _buildOrdersSection(
                        header: l10n.receiveCustomerPaying,
                        footer: l10n.receiveCustomerOldestFirst,
                        footerKey: const Key('receiveCustomerSplitNote'),
                        orders: [
                          for (final b in _balances)
                            for (final o in _orders)
                              if (o.id == b.orderId) o,
                        ],
                        own: true,
                        previews: previews,
                        showLines: showLines,
                      ),
                      if (_others.isNotEmpty)
                        _buildOrdersSection(
                          header: l10n.receiveCustomerOthersTitle(_name),
                          footer: l10n.receiveCustomerOthersNote,
                          footerKey: const Key('receiveCustomerOthersNote'),
                          orders: [for (final o in _others) _otherAsOrder(o)],
                          own: false,
                          previews: previews,
                          showLines: showLines,
                        ),
                    ],
                  );
                },
              ),
              if (_amountFocus.hasFocus)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _KeyboardDoneBar(onDone: _amountFocus.unfocus),
                ),
            ],
          ),
        ),
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

  /// "Quanto recebeu": the only place the amount shows. Standard field with
  /// ⓧ to clear; the footer gives the hint or why the button is off.
  Widget _buildAmountSection(double amount, bool tooMuch, bool noneChecked) {
    final l10n = context.l10n;
    final String hint;
    var error = false;
    if (noneChecked) {
      hint = l10n.receiveCustomerNoneChecked;
      error = true;
    } else if (tooMuch) {
      hint = l10n.receiveCustomerTooMuchChosen(
        FormatService().formatCurrency(_max),
      );
      error = true;
    } else if (amount <= 0) {
      hint = l10n.receiveCustomerZero;
    } else {
      hint = l10n.receiveCustomerPartHint;
    }
    final format = FormatService().currencyFormat;
    return _section(
      header: _sectionText(l10n.receiveCustomerAmountLabel),
      footer: _sectionText(
        hint,
        key: const Key('receiveCustomerHint'),
        color: error ? AppColors.danger.resolveFrom(context) : null,
        bold: error,
      ),
      children: [
        Semantics(
          label: l10n.receiveCustomerAmountLabel,
          child: CupertinoTextField(
            key: const Key('receiveAmountField'),
            controller: _amount,
            focusNode: _amountFocus,
            enabled: !_busy,
            onChanged: (_) => _typed = true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              CurrencyTextInputFormatter.currency(
                locale: format.locale,
                symbol: format.currencySymbol,
                decimalDigits: 2,
              ),
            ],
            placeholder: ReceiveAmountField.textFor(0),
            placeholderStyle: AppTypography.title.copyWith(
              color: AppColors.textSecondary.resolveFrom(context),
              fontFeatures: AppTypography.tabular,
            ),
            clearButtonMode: OverlayVisibilityMode.editing,
            clearButtonSemanticLabel: l10n.clear,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: null,
            style: AppTypography.title.copyWith(
              color: AppColors.text.resolveFrom(context),
              fontFeatures: AppTypography.tabular,
            ),
            cursorColor: AppColors.accent.resolveFrom(context),
          ),
        ),
      ],
    );
  }

  /// "Quando ›" and "Comprovante ›" as plain form rows.
  Widget _buildDetailsSection() {
    final l10n = context.l10n;
    final accentText = AppColors.accentText.resolveFrom(context);
    return _section(
      children: [
        _FormRow(
          key: const Key('receiveDateRow'),
          label: l10n.receiveWhen,
          value: paymentDayLabel(l10n, _paidDay),
          valueKey: const Key('receiveDateValue'),
          onTap: _busy ? null : _pickDay,
        ),
        if (_receipt != null)
          _FormRow(
            key: const Key('receiveReceiptChip'),
            label: l10n.receipt,
            value: _receipt!.name,
            trailing: CupertinoButton(
              key: const Key('receiveRemoveReceipt'),
              padding: EdgeInsets.zero,
              minimumSize: const Size(
                AppSizes.minTouchTarget,
                AppSizes.minTouchTarget,
              ),
              onPressed: _busy ? null : () => setState(() => _receipt = null),
              child: Semantics(
                label: l10n.receiveRemoveReceipt,
                child: Icon(
                  CupertinoIcons.xmark_circle_fill,
                  size: 22,
                  color: AppColors.textSecondary.resolveFrom(context),
                ),
              ),
            ),
          )
        else if (_canAttach)
          _FormRow(
            key: const Key('receiveCustomerAttach'),
            label: l10n.receipt,
            value: l10n.receiveAttach,
            valueColor: accentText,
            onTap: _busy ? null : _attach,
          ),
      ],
    );
  }

  /// The open multi-order link: amount, orders and due date. Its actions
  /// (share again, copy, cancel) are in the "…".
  Widget _buildOpenCharge(CustomerCharge charge) {
    final l10n = context.l10n;
    final format = FormatService();
    final due = charge.dueDay;
    return _section(
      hasLeading: true,
      children: [
        AppListRow(
          key: const Key('receiveCustomerOpenCharge'),
          leading: Icon(
            CupertinoIcons.link,
            color: AppColors.accentText.resolveFrom(context),
          ),
          title: l10n.receiveCustomerOpenCharge(
            format.formatCurrency(charge.value ?? 0),
          ),
          subtitle: l10n.receiveCustomerOpenChargeDetail(
            charge.orderNumbers.join(', '),
            due == null ? '-' : format.formatDate(due),
          ),
        ),
      ],
    );
  }

  /// "Está pagando" (the customer's own orders, openable by their ⓘ) or
  /// "Outras OS de João" (someone else's, not openable).
  Widget _buildOrdersSection({
    required String header,
    required String footer,
    required Key footerKey,
    required List<Order> orders,
    required bool own,
    required Map<String, AllocationPreview> previews,
    required bool showLines,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: _section(
        hasLeading: _selectable,
        header: _sectionText(header),
        footer: _sectionText(footer, key: footerKey),
        children: [
          for (final order in orders)
            _buildOrderRow(
              order,
              own: own,
              preview: previews[order.id],
              showLine: showLines,
            ),
        ],
      ),
    );
  }

  Widget _buildOrderRow(
    Order order, {
    required bool own,
    required AllocationPreview? preview,
    required bool showLine,
  }) {
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
    String? line;
    if (checked && showLine && preview != null) {
      if (preview.settles) {
        line = l10n.receiveCustomerRowSettles;
      } else if (preview.untouched) {
        line = l10n.receiveCustomerRowLater;
      } else {
        line = l10n.receiveCustomerRowPartial(
          format.formatCurrency(preview.received),
          format.formatCurrency(preview.remaining),
        );
      }
    }
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

/// One order of "Está pagando": check circle, "OS 15 · Fiat Uno", what is
/// open on it and, under, what this payment does to it. Tapping the row
/// toggles the check; the ⓘ (own orders only) opens the order.
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

/// Plain form row: label on the left, value (or [trailing]) on the right,
/// chevron when it opens something. Wraps, never ellipsized.
class _FormRow extends StatelessWidget {
  const _FormRow({
    super.key,
    required this.label,
    required this.value,
    this.valueKey,
    this.valueColor,
    this.onTap,
    this.trailing,
  });

  final String label;
  final String value;
  final Key? valueKey;
  final Color? valueColor;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = AppColors.text.resolveFrom(context);
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          trailing == null ? AppSpacing.md : 0,
          trailing == null ? AppSpacing.lg : AppSpacing.xs,
          trailing == null ? AppSpacing.md : 0,
        ),
        child: Row(
          children: [
            Text(label, style: AppTypography.body.copyWith(color: text)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                value,
                key: valueKey,
                textAlign: TextAlign.end,
                style: AppTypography.body.copyWith(
                  color: valueColor ?? secondary,
                  fontFeatures: AppTypography.tabular,
                ),
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Icon(CupertinoIcons.chevron_forward, size: 18, color: secondary),
            ],
          ],
        ),
      ),
    );
    if (trailing != null) {
      return Semantics(label: '$label: $value', child: row);
    }
    return Semantics(
      button: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: row,
      ),
    );
  }
}

/// "OK" bar over the numeric keyboard (it has no return key).
class _KeyboardDoneBar extends StatelessWidget {
  const _KeyboardDoneBar({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('receiveKeyboardDone'),
      decoration: BoxDecoration(
        color: AppColors.surface.resolveFrom(context),
        border: Border(
          top: BorderSide(color: AppColors.separator.resolveFrom(context)),
        ),
      ),
      alignment: AlignmentDirectional.centerEnd,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        minimumSize: const Size(
          AppSizes.minTouchTarget,
          AppSizes.minTouchTarget,
        ),
        onPressed: onDone,
        child: Text(
          context.l10n.ok,
          style: AppTypography.bodyStrong.copyWith(
            color: AppColors.accentText.resolveFrom(context),
          ),
        ),
      ),
    );
  }
}
