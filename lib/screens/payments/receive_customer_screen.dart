import 'dart:async';

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
import 'package:praticos/screens/integrations/asaas_connection_screen.dart'
    show safePaymentSettings;
import 'package:praticos/screens/payments/asaas_error_text.dart';
import 'package:praticos/screens/payments/create_customer_charge_screen.dart';
import 'package:praticos/screens/payments/widgets/receipt_file_picker.dart';
import 'package:praticos/screens/payments/widgets/receive_amount_field.dart';
import 'package:praticos/screens/payments/widgets/receive_block.dart'
    show ReceiptChip;
import 'package:praticos/screens/payments/widgets/receive_date_row.dart';
import 'package:praticos/screens/payments/widgets/receive_orders_picker.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/app_toast.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/screens/widgets/pull_down_menu.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/services/asaas_api_service.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/customer_receipt_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/utils/currency_input.dart';
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

/// "Receber de João": one payment from a customer who owes on several
/// orders, split oldest order first ([allocatePayment]). "Escolher as OS"
/// limits the split to the chosen orders (still oldest first).
///
/// Amount (pre-filled with everything owed, never more), day the money came
/// in ("Hoje" by default, no future dates), optional receipt, the live
/// "Como fica" split and one blue "Recebi R$ X". On success it shows a toast
/// and pops with `true`. Pushed (not a sheet): it acts on existing orders.
///
/// With Asaas connected, "Mandar cobrança" creates one link for the chosen
/// orders (or shares the open one); the open link shows on top, with copy,
/// share and cancel in the "…". A consultant also sees "Outras OS de João"
/// (orders someone else created, only number, open amount and date, read
/// from the server); including one makes the save go through the server,
/// which needs connection.
class ReceiveCustomerScreen extends StatefulWidget {
  const ReceiveCustomerScreen({
    super.key,
    required this.orders,
    this.customer,
    this.customerName,
    this.service,
    this.canAttachReceipt,
    this.pickReceipt,
    this.pickOrders,
    this.chargeReady,
    this.openCharge,
    this.createCharge,
    this.shareLink,
    this.api,
    this.otherOrdersLoader,
  });

  /// Whether "Mandar cobrança" is available (tests). Defaults to the
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

  /// Overrides the "Escolher as OS" picker (tests).
  final Future<Set<String>?> Function(
    BuildContext context,
    List<Order> orders,
    Set<String> selected,
  )?
  pickOrders;

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
  late final List<OpenBalance> _balances = [
    for (final order in widget.orders) OpenBalance.ofOrder(order),
  ].where((b) => b.open > 0).toList();
  late final double _owed = totalOpen(_balances);
  late final TextEditingController _amount = TextEditingController(
    text: ReceiveAmountField.textFor(_owed),
  );

  /// Orders chosen in "Escolher as OS"; null = all of the customer's orders
  /// on the screen ([_balances], never [_others]).
  Set<String>? _chosen;

  /// "Outras OS de João": open orders someone else created (consultant).
  List<CustomerOpenOrder> _others = const [];

  bool _chargeReady = false;
  CustomerCharge? _openCharge;
  StreamSubscription<CustomerCharge?>? _chargeSub;

  /// Every order that can be chosen, oldest first: the screen's and the
  /// others (as light [Order]s with only id, number, open and date).
  List<Order> get _allOrders {
    final own = [
      for (final b in _balances)
        for (final o in widget.orders)
          if (o.id == b.orderId) o,
    ];
    if (_others.isEmpty) return own;
    final all = [
      ...own,
      for (final other in _others)
        Order()
          ..id = other.id
          ..number = other.number
          ..total = other.open
          ..paidAmount = 0
          ..createdAt = other.createdAt,
    ];
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    all.sort((a, b) {
      final byDate = (a.createdAt ?? epoch).compareTo(b.createdAt ?? epoch);
      return byDate != 0 ? byDate : (a.number ?? 0).compareTo(b.number ?? 0);
    });
    return all;
  }

  /// Balances the payment goes to (the chosen ones, oldest first).
  List<OpenBalance> get _active {
    if (_chosen == null) return List.of(_balances);
    return [
      for (final order in _allOrders)
        if (_chosen!.contains(order.id)) OpenBalance.ofOrder(order),
    ].where((b) => b.open > 0).toList();
  }

  /// Whether the chosen orders include someone else's (save via server).
  bool get _includesOthers =>
      _chosen != null && _others.any((o) => _chosen!.contains(o.id));

  /// Most that can be received now: what is open on [_active].
  double get _max => totalOpen(_active);

  DateTime _paidDay = DateTime.now();
  PickedReceiptFile? _receipt;
  bool _busy = false;

  bool get _canAttach =>
      widget.canAttachReceipt ??
      AuthorizationService.instance.hasPermission(PermissionType.attachPhotos);

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
    _amount.dispose();
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

  /// "Mandar cobrança": shares the open link, or creates one for the chosen
  /// orders (the typed amount, never more than they owe) and shares it.
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

  Future<void> _showChargeMenu(CustomerCharge charge) async {
    final l10n = context.l10n;
    final choice = await showPullDownMenu(
      context,
      groups: [
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
    );
    if (!mounted || choice == null) return;
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
    final day = await pickPaymentDay(context, _paidDay);
    if (day != null && mounted) setState(() => _paidDay = day);
  }

  Future<void> _attach() async {
    final picked = await (widget.pickReceipt ?? pickReceiptFile)(context);
    if (picked != null && mounted) setState(() => _receipt = picked);
  }

  Future<void> _chooseOrders() async {
    final openOrders = _allOrders;
    final current = _chosen ?? {for (final b in _balances) b.orderId};
    final picked =
        await (widget.pickOrders ??
            (context, orders, selected) => pickReceiveOrders(
              context,
              orders: orders,
              selected: selected,
            ))(context, openOrders, current);
    if (picked == null || picked.isEmpty || !mounted) return;
    final own = {for (final b in _balances) b.orderId};
    final allOwn = picked.length == own.length && picked.every(own.contains);
    setState(() {
      _chosen = allOwn ? null : picked;
      _amount.text = ReceiveAmountField.textFor(_max);
    });
  }

  Future<void> _confirm() async {
    final value = parseCurrencyInput(_amount.text);
    if (_busy || value <= 0 || _cents(value) > _cents(_max)) return;
    final l10n = context.l10n;
    final allocations = allocatePayment(_active, value);
    setState(() => _busy = true);
    final service = widget.service ?? CustomerReceiptService();
    final request = CustomerReceiptRequest(
      customer: widget.customer,
      orders: widget.orders,
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
    final format = FormatService();

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppNavBar.barBackground(context),
        border: null,
        trailing: _openCharge != null && !_busy
            ? GlassBarButton(
                key: const Key('receiveCustomerChargeMenu'),
                label: l10n.receiveCustomerChargeMenu,
                icon: CupertinoIcons.ellipsis,
                onPressed: () => _showChargeMenu(_openCharge!),
              )
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          bottom: false,
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _amount,
            builder: (context, value, _) {
              final amount = parseCurrencyInput(value.text);
              final active = _active;
              final tooMuch = _cents(amount) > _cents(_max);
              final canSave = !_busy && amount > 0 && !tooMuch;
              final previews = previewAllocation(
                active,
                tooMuch ? const [] : allocatePayment(active, amount),
              );
              return ListView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom + 40,
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
                      l10n.receiveCustomerOwes(
                        format.formatCurrency(_owed),
                        _balances.length,
                      ),
                      key: const Key('receiveCustomerOwes'),
                      style: AppTypography.callout.copyWith(
                        color: secondary,
                        fontFeatures: AppTypography.tabular,
                      ),
                    ),
                  ),
                  if (_openCharge != null) _buildOpenCharge(_openCharge!),
                  _buildAmountCard(amount, tooMuch),
                  SectionLabel(l10n.receiveCustomerHowItGoes),
                  for (final preview in previews)
                    AppListRow(
                      key: Key('receiveCustomerRow_${preview.balance.orderId}'),
                      title: _previewLine(preview, format),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageMargin,
                      AppSpacing.sm,
                      AppSpacing.pageMargin,
                      AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _chosen == null
                              ? l10n.receiveCustomerOldestFirst
                              : l10n.receiveCustomerChosenOnly,
                          key: const Key('receiveCustomerSplitNote'),
                          style: AppTypography.label.copyWith(color: secondary),
                        ),
                        if (_balances.length > 1 || _others.isNotEmpty)
                          TextLink(
                            key: const Key('receiveCustomerChoose'),
                            label: l10n.receiveCustomerChooseOrders,
                            onPressed: _busy ? null : _chooseOrders,
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.blockMargin,
                    ),
                    child: _busy
                        ? const SizedBox(
                            height: AppSizes.primaryButtonHeight,
                            child: Center(child: CupertinoActivityIndicator()),
                          )
                        : PrimaryButton(
                            key: const Key('receiveCustomerConfirm'),
                            label: l10n.receiveButton(
                              ReceiveAmountField.textFor(amount),
                            ),
                            onPressed: canSave ? _confirm : null,
                          ),
                  ),
                  if (_chargeReady && widget.customer?.id != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageMargin,
                        AppSpacing.sm,
                        AppSpacing.pageMargin,
                        0,
                      ),
                      child: Center(
                        child: TextLink(
                          key: const Key('receiveCustomerSendCharge'),
                          label: _openCharge != null
                              ? l10n.receiveCustomerShareCharge
                              : l10n.receiveCustomerSendCharge,
                          onPressed: _busy ? null : _sendCharge,
                        ),
                      ),
                    ),
                  ..._buildOthers(format),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// accentSoft block: amount, hint (or why the button is off), "Quando"
  /// and the receipt.
  Widget _buildAmountCard(double amount, bool tooMuch) {
    final l10n = context.l10n;
    final onSoft = AppColors.onAccentSoft.resolveFrom(context);
    final String hint;
    Color hintColor = onSoft;
    if (tooMuch) {
      final max = FormatService().formatCurrency(_max);
      hint = _chosen == null
          ? l10n.receiveCustomerTooMuch(max)
          : l10n.receiveCustomerTooMuchChosen(max);
      hintColor = AppColors.danger.resolveFrom(context);
    } else if (amount <= 0) {
      hint = l10n.receiveCustomerZero;
    } else {
      hint = l10n.receiveAmountHint;
    }

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.blockMargin,
        vertical: AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.accentSoft.resolveFrom(context),
        borderRadius: BorderRadius.circular(AppRadii.block),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.receiveCustomerAmountLabel,
            style: AppTypography.label.copyWith(color: onSoft),
          ),
          const SizedBox(height: AppSpacing.xs),
          ReceiveAmountField(controller: _amount),
          const SizedBox(height: AppSpacing.xs),
          Text(
            hint,
            key: const Key('receiveCustomerHint'),
            style: AppTypography.label.copyWith(
              color: hintColor,
              fontWeight: tooMuch ? FontWeight.w600 : null,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ReceiveDateRow(day: _paidDay, onTap: _busy ? null : _pickDay),
          if (_receipt != null)
            ReceiptChip(
              name: _receipt!.name,
              onRemove: _busy ? null : () => setState(() => _receipt = null),
            )
          else if (_canAttach)
            CupertinoButton(
              key: const Key('receiveCustomerAttach'),
              padding: EdgeInsets.zero,
              minimumSize: const Size(
                AppSizes.minTouchTarget,
                AppSizes.minTouchTarget,
              ),
              onPressed: _busy ? null : _attach,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.paperclip,
                    size: 20,
                    color: AppColors.accentText.resolveFrom(context),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      l10n.receiveAttachReceipt,
                      style: AppTypography.callout.copyWith(
                        color: AppColors.accentText.resolveFrom(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// The open multi-order link: amount, orders and due date.
  Widget _buildOpenCharge(CustomerCharge charge) {
    final l10n = context.l10n;
    final format = FormatService();
    final due = charge.dueDay;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: AppListRow(
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
    );
  }

  /// "Outras OS de João": the others not chosen yet (consultant).
  List<Widget> _buildOthers(FormatService format) {
    final l10n = context.l10n;
    final left = [
      for (final o in _others)
        if (_chosen == null || !_chosen!.contains(o.id)) o,
    ];
    if (left.isEmpty) return const [];
    return [
      const SizedBox(height: AppSpacing.lg),
      SectionLabel(l10n.receiveCustomerOthersTitle(_name)),
      for (final other in left)
        AppListRow(
          key: Key('receiveCustomerOther_${other.id}'),
          title: l10n.receiveCustomerPickRow(other.number ?? 0),
          subtitle: l10n.receiveCustomerPickSubtitle(
            format.formatCurrency(other.open),
            other.createdAt == null ? '-' : format.formatDate(other.createdAt!),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageMargin,
          AppSpacing.sm,
          AppSpacing.pageMargin,
          0,
        ),
        child: Text(
          l10n.receiveCustomerOthersNote,
          key: const Key('receiveCustomerOthersNote'),
          style: AppTypography.label.copyWith(
            color: AppColors.textSecondary.resolveFrom(context),
          ),
        ),
      ),
    ];
  }

  String _previewLine(AllocationPreview preview, FormatService format) {
    final l10n = context.l10n;
    final number = preview.balance.orderNumber ?? 0;
    if (preview.untouched) {
      return l10n.receiveCustomerUntouched(
        number,
        format.formatCurrency(preview.balance.open),
      );
    }
    if (preview.settles) {
      return l10n.receiveCustomerSettles(
        number,
        format.formatCurrency(preview.received),
      );
    }
    return l10n.receiveCustomerPartial(
      number,
      format.formatCurrency(preview.received),
      format.formatCurrency(preview.remaining),
    );
  }
}
