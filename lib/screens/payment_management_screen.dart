import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_charge.dart';
import 'package:praticos/models/order_document.dart';
import 'package:praticos/models/payment_settings.dart';
import 'package:praticos/models/payment_transaction.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/screens/payments/asaas_error_text.dart';
import 'package:praticos/screens/payments/create_charge_screen.dart';
import 'package:praticos/screens/payments/receipt_detail_screen.dart';
import 'package:praticos/screens/payments/receipt_share.dart';
import 'package:praticos/screens/payments/widgets/receipt_image_viewer.dart';
import 'package:praticos/screens/payments/widgets/order_charge_card.dart';
import 'package:praticos/screens/payments/widgets/order_charge_section.dart';
import 'package:praticos/screens/payments/widgets/receipt_file_picker.dart';
import 'package:praticos/screens/payments/widgets/receive_payment_sheet.dart';
import 'package:praticos/screens/payments/widgets/receive_summary.dart';
import 'package:praticos/screens/payments/widgets/receive_block.dart';
import 'package:praticos/screens/payments/widgets/receive_date_row.dart';
import 'package:praticos/services/customer_receipt_service.dart'
    show PickedReceiptFile;
import 'package:praticos/screens/payments/widgets/receive_discount_sheet.dart';
import 'package:praticos/screens/widgets/app_toast.dart';
import 'package:praticos/screens/widgets/pull_down_menu.dart';
import 'package:praticos/screens/payments/widgets/receive_payment_row.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/screens/widgets/secondary_button.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/screens/widgets/share_link_sheet.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/services/asaas_api_service.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/pdf/receipt_pdf.dart';
import 'package:praticos/services/photo_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/utils/asaas_billing.dart';
import 'package:praticos/utils/order_payment_math.dart';
import 'package:praticos/utils/payment_update_failure.dart';
import 'package:praticos/widgets/permission_widgets.dart'
    show AccessDeniedScreen;
import 'package:url_launcher/url_launcher.dart';

/// `/payment_management` route: the order's Receber, or "access denied"
/// when the person cannot receive on that order
/// ([AuthorizationService.canReceiveOnOrder]: financial access on any order,
/// a consultant only on the orders they created).
class PaymentManagementRoute extends StatelessWidget {
  const PaymentManagementRoute({super.key, this.canReceiveOn});

  /// Overrides [AuthorizationService.canReceiveOnOrder] (tests).
  final bool Function(Order? order)? canReceiveOn;

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final store = args?['orderStore'] as OrderStore?;
    return Observer(
      builder: (_) {
        final order = store?.order;
        final allowed =
            canReceiveOn?.call(order) ??
            AuthorizationService.instance.canReceiveOnOrder(order);
        if (allowed) return const PaymentManagementScreen();
        return AccessDeniedScreen(onBack: () => Navigator.of(context).pop());
      },
    );
  }
}

/// "Receber" screen of an order: who owes and what is "A receber", then
/// "Marcar como recebido" (blue) and "Mandar cobrança" (with Asaas). How much,
/// when and the receipt are in [ReceivePaymentSheet]. Same structure as
/// [ReceiveCustomerScreen]; below come the payments ("Já recebido").
///
/// With an open link its status replaces the blue button (the customer is the
/// one who acts) until it is overdue. The link's other actions (copy, cancel)
/// live in the "…" menu, with discount and "undo payments".
///
/// Payment method is not asked: it is shown only for payments that came from
/// Asaas. Tapping a payment opens its sheet (send recibo, view/attach receipt,
/// remove); a payment that is a share of a customer receipt opens the
/// "Recebimento" screen instead. No success dialogs: after confirming, the
/// screen shows the new balance or "Tudo recebido".
class PaymentManagementScreen extends StatefulWidget {
  const PaymentManagementScreen({
    super.key,
    this.store,
    this.canAttachReceipt,
    this.canViewReceipt,
    this.canGiveDiscount,
    this.onOpenExternalUrl,
    this.canCharge,
    this.paymentSettingsStream,
    this.chargesStream,
    this.chargeService,
    this.canSendReceipt,
    this.canOpenReceiptGroup,
    this.onSendReceipt,
    this.onOpenReceipt,
    this.initialReceipt,
    this.onInitialReceiptUsed,
  });

  /// Order store. When null it comes from the route arguments (`orderStore`).
  final OrderStore? store;

  /// Test seams; default to the attachPhotos / viewPhotos permission checks.
  final bool? canAttachReceipt;
  final bool? canViewReceipt;

  /// "Dar desconto" in the "…" menu. Defaults to financial access
  /// (`viewFinancialReports`): a consultant receives on their own orders
  /// but does not give discounts. Test seam.
  final bool? canGiveDiscount;

  /// Test seam; defaults to opening the link in the browser.
  final Future<void> Function(Uri uri)? onOpenExternalUrl;

  /// Test seams for the Asaas charge part; default to the chargeOrder
  /// permission, the company payment settings, the order charges and
  /// [AsaasApiService.instance].
  final bool? canCharge;
  final Stream<PaymentSettings>? paymentSettingsStream;
  final Stream<List<OrderCharge>>? chargesStream;
  final AsaasApiService? chargeService;

  /// Test seam; defaults to [AuthorizationService.canReceiveOnOrder] (who
  /// receives on this order sends its recibo).
  final bool? canSendReceipt;

  /// Test seam: whether a payment that is a share of a customer receipt
  /// opens that receipt. Defaults to financial access or having
  /// registered it (who else the rules don't let read the receipt).
  final bool Function(PaymentTransaction tx)? canOpenReceiptGroup;

  /// Test seams; default to the recibo share sheet and the "Recebimento"
  /// screen.
  final Future<void> Function(BuildContext context, ReceiptPdfData data)?
  onSendReceipt;

  /// Completes with true when the receipt was undone.
  final Future<bool> Function(BuildContext context, String receiptId)?
  onOpenReceipt;

  /// Receipt already attached when the screen opens (a file shared from
  /// another app, "Comprovante de um pagamento novo"). When null it comes
  /// from the route arguments (`receipt`).
  final PickedReceiptFile? initialReceipt;

  /// Called once [initialReceipt] is saved as the receipt of a new payment.
  /// When null it comes from the route arguments (`onReceiptUsed`).
  final VoidCallback? onInitialReceiptUsed;

  @override
  State<PaymentManagementScreen> createState() =>
      _PaymentManagementScreenState();
}

class _PaymentManagementScreenState extends State<PaymentManagementScreen> {
  bool _initialized = false;
  OrderStore? _store;

  /// See [PaymentManagementScreen.initialReceipt].
  PickedReceiptFile? _initialReceipt;
  VoidCallback? _onInitialReceiptUsed;

  /// True while a payment operation is running: the buttons are disabled so
  /// the same payment can't be sent twice.
  bool _busy = false;

  /// What was filled in the sheet: kept when saving fails.
  ReceiveDraft? _draft;

  /// Opened from the order screen: "‹ OS 183" just goes back to it.
  bool _fromOrder = false;

  /// Asaas charge state; null without an order store.
  OrderChargeController? _charge;

  /// Double-tap guards of the charge actions.
  bool _creatingCharge = false;
  bool _cancelingCharge = false;
  bool _confirmingReplace = false;

  /// Open charge the user chose to keep after the order total changed.
  String? _keptChargeId;

  AsaasApiService get _chargeService =>
      widget.chargeService ?? AsaasApiService.instance;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _store = widget.store;
      _initialReceipt = widget.initialReceipt;
      _onInitialReceiptUsed = widget.onInitialReceiptUsed;
      if (_store == null) {
        final args =
            ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        if (args != null && args.containsKey('orderStore')) {
          _store = args['orderStore'];
        }
        _fromOrder = args?['fromOrder'] == true;
        _initialReceipt ??= args?['receipt'] as PickedReceiptFile?;
        _onInitialReceiptUsed ??= args?['onReceiptUsed'] as VoidCallback?;
      }
      final store = _store;
      if (store != null) {
        _charge = OrderChargeController(
          store: store,
          canCharge: widget.canCharge,
          settingsStream: widget.paymentSettingsStream,
          chargesStream: widget.chargesStream,
        );
      }
      _initialized = true;
      // A file shared from another app: the sheet opens with it attached.
      final receipt = _initialReceipt;
      if (receipt != null) {
        _draft = ReceiveDraft(
          amount: _store?.remainingBalance ?? 0,
          paidDay: DateTime.now(),
          receipt: receipt,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && (_store?.remainingBalance ?? 0) > 0) _openReceive();
        });
      }
    }
  }

  @override
  void dispose() {
    _charge?.dispose();
    super.dispose();
  }

  Future<void> _runBusy(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _canAttach =>
      widget.canAttachReceipt ??
      AuthorizationService.instance.hasPermission(PermissionType.attachPhotos);
  bool get _canView =>
      widget.canViewReceipt ??
      AuthorizationService.instance.hasPermission(PermissionType.viewPhotos);
  bool get _canSendReceipt =>
      widget.canSendReceipt ??
      AuthorizationService.instance.canReceiveOnOrder(_store?.order);
  bool _canOpenReceiptGroup(PaymentTransaction tx) {
    final override = widget.canOpenReceiptGroup;
    if (override != null) return override(tx);
    if (AuthorizationService.instance.canViewFinancialReports) return true;
    final uid = Global.currentUser?.uid;
    return uid != null && tx.createdBy?.id == uid;
  }

  bool get _canDiscount =>
      widget.canGiveDiscount ??
      AuthorizationService.instance.canViewFinancialReports;

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.groupedBackground.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppNavBar.barBackground(context),
        border: null,
        leading: _buildOrderLink(),
        trailing: _buildMoreButton(),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            children: [_buildContent()],
          ),
        ),
      ),
    );
  }

  /// "‹ OS 183", the back button: back to the order when it opened this
  /// screen; otherwise (Financeiro) this screen is replaced by the order, so
  /// the stack never piles up Receber → OS → Receber.
  Widget _buildOrderLink() {
    final order = _store?.order;
    if (order == null || order.number == null) return const SizedBox.shrink();
    return GlassBackButton(
      key: const Key('receiveOrderLink'),
      previousTitle: context.l10n.receiveOrderLink(order.number!),
      onPressed: () => _fromOrder
          ? Navigator.of(context).pop()
          : Navigator.of(
              context,
            ).pushReplacementNamed('/order', arguments: {'order': order}),
    );
  }

  /// "A receber · OS 18 · C180", the summary label.
  String _summaryLabel() {
    final l10n = context.l10n;
    final order = _store?.order;
    final number = order?.number;
    if (order == null || number == null) return l10n.receiveSummaryPlain;
    final description = orderShortDescription(order);
    return l10n.receiveSummaryOrder(
      description == null
          ? l10n.receiveCustomerPickRow(number)
          : l10n.receiveCustomerOrderRow(number, description),
    );
  }

  /// "total R$ 1.250", plus " · desconto R$ 50" when the order has a
  /// discount; only when it says more than the amount does.
  String? _summaryDetail(OrderStore store, double remaining) {
    final format = FormatService();
    final totalValue = store.total ?? 0.0;
    final discountValue = store.discount ?? 0.0;
    final total = format.formatCurrency(totalValue);
    if (discountValue > 0) {
      return context.l10n.receiveSubtitleNoCustomerWithDiscount(
        total,
        format.formatCurrency(discountValue),
      );
    }
    final same =
        (totalValue - remaining).abs() <= OrderPaymentMath.centTolerance;
    return same ? null : context.l10n.receiveSubtitleNoCustomer(total);
  }

  Widget _buildMoreButton() {
    return Observer(
      builder: (_) {
        final status = _store?.status;
        final store = _store;
        if (store == null || status == 'quote' || status == 'canceled') {
          return const SizedBox.shrink();
        }
        // Nothing to offer: no discount, no link and no payment to undo.
        if (!_canDiscount &&
            _visibleOpenCharge() == null &&
            !store.transactions.any((t) => !t.isAsaas)) {
          return const SizedBox.shrink();
        }
        return GlassBarButton(
          key: const Key('receiveMoreButton'),
          label: context.l10n.receiveMoreOptions,
          icon: CupertinoIcons.ellipsis,
          onPressed: () {
            if (!_busy) _showMoreMenu();
          },
        );
      },
    );
  }

  /// Whether the Asaas charge part applies: pilot on, user allowed, order
  /// saved and accepting payments (not a quote nor canceled).
  bool _chargeApplies(OrderStore store) {
    final status = store.status;
    return (_charge?.enabled ?? false) &&
        store.order?.id != null &&
        status != 'quote' &&
        status != 'canceled';
  }

  /// The open charge this screen shows, or null.
  OrderCharge? _visibleOpenCharge() {
    final store = _store;
    if (store == null || !_chargeApplies(store)) return null;
    return _charge?.openCharge;
  }

  /// The whole screen: summary, charge status, the actions and the payments.
  Widget _buildContent() {
    return ListenableBuilder(
      listenable: _charge ?? Listenable.merge(const <Listenable>[]),
      builder: (context, _) => Observer(
        builder: (_) {
          final store = _store;
          final l10n = context.l10n;
          // Read the observables so the screen follows payment changes.
          final remaining = store?.remainingBalance ?? 0.0;
          final applies = store != null && _chargeApplies(store);
          if (applies) _charge!.reloadOnFirstShow();
          final open = applies ? _charge!.openCharge : null;
          const tolerance = OrderPaymentMath.centTolerance;
          final name = store?.customerName;
          final title = name == null || name.isEmpty ? l10n.receiveTitle : name;
          final status = store?.status;
          final blocked = status == 'quote'
              ? l10n.statusQuote
              : status == 'canceled'
              ? l10n.statusCancelled
              : null;
          final paid = open != null
              ? remaining <= tolerance
              : store?.isFullyPaid ?? false;

          final children = <Widget>[];
          if (blocked != null || paid) {
            children.add(
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageMargin,
                  AppSpacing.sm,
                  AppSpacing.pageMargin,
                  0,
                ),
                child: Text(
                  title,
                  key: const Key('receiveTitle'),
                  style: AppTypography.title.copyWith(
                    color: AppColors.text.resolveFrom(context),
                  ),
                ),
              ),
            );
            children.add(ReceiveBlock(blockedMessage: blocked));
            if (open != null) {
              children.add(OrderChargeStatus(charge: open, customerName: name));
            }
          } else {
            children.add(
              ReceiveSummary(
                titleKey: const Key('receiveTitle'),
                title: title,
                label: _summaryLabel(),
                amount: FormatService().formatCurrency(remaining),
                detail: store == null ? null : _summaryDetail(store, remaining),
              ),
            );
            children.addAll(_buildChargeAndActions(open, remaining, name));
          }
          children.add(_buildPayments());
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          );
        },
      ),
    );
  }

  /// What can be done with [remaining] still owed: one blue button at most.
  List<Widget> _buildChargeAndActions(
    OrderCharge? open,
    double remaining,
    String? customerName,
  ) {
    final l10n = context.l10n;
    final store = _store!;
    final applies = _chargeApplies(store);
    const tolerance = OrderPaymentMath.centTolerance;
    final mark = _actionLink(
      TextLink(
        key: const Key('receiveConfirm'),
        label: l10n.receiveMarkReceived,
        onPressed: _busy ? null : _openReceive,
      ),
    );

    if (open != null) {
      final value = open.value ?? 0.0;
      final locked = chargeHasPaidInstallments(open);
      // The order total dropped below the link value.
      if (!locked &&
          value > remaining + tolerance &&
          _keptChargeId != open.id) {
        return [
          ChargeChangedBlock(
            remaining: remaining,
            chargeValue: value,
            busy: _creatingCharge,
            onGenerate: _charge!.connected
                ? () => _runCreateCharge(remaining)
                : null,
          ),
          _linkPadding(
            TextLink(
              key: const Key('chargeKeepLink'),
              label: l10n.chargeKeepLink(FormatService().formatCurrency(value)),
              onPressed: () => setState(() => _keptChargeId = open.id),
            ),
          ),
          mark,
        ];
      }
      final overdue = open.status == ChargeStatus.overdue;
      return [
        OrderChargeStatus(
          charge: open,
          customerName: customerName,
          remaining: remaining,
        ),
        _actionPadding(
          overdue
              ? PrimaryButton(
                  key: const Key('chargeSendAgain'),
                  label: l10n.chargeSendAgain,
                  onPressed: _shareOrderLink,
                )
              : SecondaryButton(
                  key: const Key('chargeSendAgain'),
                  label: l10n.chargeSendAgain,
                  onPressed: _shareOrderLink,
                ),
        ),
        mark,
      ];
    }

    final connected = applies && _charge!.connected;
    if (connected &&
        _charge!.autoCanceledCharge != null &&
        remaining > tolerance) {
      return [
        ChargeCanceledBlock(
          remaining: remaining,
          busy: _creatingCharge,
          onSend: () => _onSendLinkPressed(remaining),
        ),
        mark,
      ];
    }

    return [
      _actionPadding(
        _busy
            ? const SizedBox(
                height: AppSizes.primaryButtonHeight,
                child: Center(child: CupertinoActivityIndicator()),
              )
            : PrimaryButton(
                key: const Key('receiveConfirm'),
                label: l10n.receiveMarkReceived,
                onPressed: _openReceive,
              ),
      ),
      if (connected && !_charge!.blockedByInstallments)
        _actionPadding(
          SecondaryButton(
            key: const Key('chargeSendLink'),
            label: l10n.chargeSend,
            onPressed: _creatingCharge
                ? null
                : () => _onSendLinkPressed(remaining),
          ),
        )
      else if (!applies && store.order?.id != null)
        _actionPadding(
          SecondaryButton(
            key: const Key('receiveShareOrderLink'),
            label: l10n.chargeSendOrderLink,
            onPressed: _shareOrderLink,
          ),
        ),
    ];
  }

  Widget _actionPadding(Widget button) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.blockMargin,
        0,
        AppSpacing.blockMargin,
        AppSpacing.sm,
      ),
      child: button,
    );
  }

  Widget _actionLink(Widget link) => Center(child: link);

  /// Text link aligned with the page margin.
  Widget _linkPadding(Widget link) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMargin),
      child: Align(alignment: AlignmentDirectional.centerStart, child: link),
    );
  }

  /// "Já recebido": the payments, newest first. Paid charges are not listed
  /// apart: their money is already here as transactions.
  Widget _buildPayments() {
    final transactions = _store?.transactions ?? <PaymentTransaction>[];
    if (transactions.isEmpty) return const SizedBox.shrink();
    final sorted = List<PaymentTransaction>.from(transactions)
      ..sort((a, b) => b.paidOn.compareTo(a.paidOn));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(context.l10n.receiveAlreadyReceived),
        for (final tx in sorted)
          ReceivePaymentRow(
            transaction: tx,
            showReceiptState: _canView,
            onTap: () => _showPaymentSheet(tx),
          ),
      ],
    );
  }

  // ============================================================
  // ASAAS CHARGE
  // ============================================================

  /// Opens the create-charge sheet and waits for it to close.
  Future<void> _openCreateCharge(double remaining) async {
    final order = _store?.order;
    if (order?.id == null) return;

    await FormSheet.show<OrderCharge>(
      context,
      (_) => CreateChargeScreen(order: order!, remainingBalance: remaining),
    );
  }

  /// Runs the create flow once at a time (double-tap guard while the
  /// create screen is open).
  Future<void> _runCreateCharge(double remaining) async {
    if (_creatingCharge) return;
    setState(() => _creatingCharge = true);
    try {
      await _openCreateCharge(remaining);
    } finally {
      if (mounted) setState(() => _creatingCharge = false);
    }
  }

  /// "Mandar link para … pagar". If a link is still open, confirm first: the
  /// new one cancels it on Asaas.
  Future<void> _onSendLinkPressed(double remaining) async {
    final open = _charge?.openCharge;
    if (open == null) {
      await _runCreateCharge(remaining);
      return;
    }
    if (_confirmingReplace || _creatingCharge) return;
    _confirmingReplace = true;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(dialogContext.l10n.chargeReplaceTitle),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(dialogContext.l10n.chargeReplaceConfirm),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.cancel),
          ),
          CupertinoDialogAction(
            key: const Key('confirmReplaceChargeAction'),
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.chargeReplace),
          ),
        ],
      ),
    );
    _confirmingReplace = false;
    if (!mounted) return;
    if (confirmed == true) await _runCreateCharge(remaining);
  }

  void _shareOrderLink() {
    final order = _store?.order;
    if (order != null) ShareLinkSheet.show(context, order);
  }

  Future<void> _copyChargeLink(OrderCharge charge) async {
    await Clipboard.setData(ClipboardData(text: charge.invoiceUrl!));
    if (!mounted) return;
    showAppToast(context, context.l10n.chargeLinkCopied);
  }

  Future<void> _confirmCancelCharge(OrderCharge charge) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(dialogContext.l10n.chargeCancelLink),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(dialogContext.l10n.chargeCancelConfirm),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.chargeKeep),
          ),
          CupertinoDialogAction(
            key: const Key('confirmCancelChargeAction'),
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.chargeCancelLink),
          ),
        ],
      ),
    );
    final orderId = _store?.order?.id;
    if (confirmed != true || charge.id == null || orderId == null) return;
    if (!mounted || _cancelingCharge) return;

    setState(() => _cancelingCharge = true);
    try {
      await _chargeService.cancelCharge(orderId, charge.id!);
    } on AsaasApiException catch (e) {
      if (mounted) _showMessage(asaasErrorText(context.l10n, e));
    } catch (_) {
      // Unexpected response: generic text, never the raw error.
      if (mounted) {
        _showMessage(asaasErrorText(context.l10n, AsaasApiException(null, '')));
      }
    } finally {
      if (mounted) setState(() => _cancelingCharge = false);
    }
  }

  // ============================================================
  // REGISTER PAYMENT
  // ============================================================

  /// What the amount does: says what stays open on the order.
  String? _preview(double amount, double remaining) {
    final left = remaining - amount;
    if (left <= OrderPaymentMath.centTolerance) {
      return context.l10n.receivePreviewAll(1);
    }
    return context.l10n.receivePreviewLeft(
      FormatService().formatCurrency(left),
    );
  }

  /// "Marcar como recebido": the sheet, then saving what came back.
  Future<void> _openReceive() async {
    final store = _store;
    if (store == null || _busy) return;
    final remaining = store.remainingBalance;
    final l10n = context.l10n;
    final name = store.customerName;
    final hasName = name != null && name.isNotEmpty;
    final open = _visibleOpenCharge();
    final draft = await ReceivePaymentSheet.show(
      context,
      title: hasName
          ? l10n.receiveReceivedFrom(name)
          : l10n.receiveReceivedTitle,
      max: remaining,
      preview: (amount) => _preview(amount, remaining),
      initial: _draft,
      canAttach: _canAttach,
      note: open == null
          ? null
          : hasName
          ? l10n.receiveChargeAdjusts(name)
          : l10n.receiveChargeAdjustsNoName,
    );
    if (draft == null || !mounted) return;
    _draft = draft;
    await _runBusy(() => _doRegister(draft));
  }

  Future<void> _doRegister(ReceiveDraft draft) async {
    final store = _store;
    if (store == null) return;
    final transaction = await store.addPayment(
      draft.amount,
      paidAt: paidAtFor(draft.paidDay),
    );
    var receiptOk = true;
    final receipt = draft.receipt;
    if (transaction != null && receipt != null) {
      final index = store.transactions.indexWhere(
        (t) => t.id == transaction.id,
      );
      if (index >= 0) {
        receiptOk = await store.attachReceiptToTransaction(
          index,
          receipt.file,
          receipt.contentType,
          receipt.name,
        );
        if (receiptOk && identical(receipt, _initialReceipt)) {
          _initialReceipt = null;
          _onInitialReceiptUsed?.call();
        }
      }
    }
    if (!mounted) return;
    if (transaction == null) {
      _showError(_paymentFailureMessage(store));
      return;
    }
    _draft = null;
    if (!receiptOk) _showError(_paymentFailureMessage(store));
  }

  /// Localized message for the last failed payment operation of [store].
  String _paymentFailureMessage(OrderStore store) {
    switch (store.lastPaymentFailure) {
      case PaymentUpdateFailure.requiresConnection:
        return context.l10n.paymentRequiresConnection;
      case PaymentUpdateFailure.asaasLocked:
        return context.l10n.asaasTransactionCannotBeRemoved;
      case PaymentUpdateFailure.failed:
      case null:
        return context.l10n.paymentUpdateFailed;
    }
  }

  // ============================================================
  // "..." MENU: discount and undo payments
  // ============================================================

  Future<void> _showMoreMenu() async {
    final store = _store;
    if (store == null) return;
    final hasManual = store.transactions.any((t) => !t.isAsaas);
    final open = _visibleOpenCharge();
    final hasInvoice = (open?.invoiceUrl ?? '').isNotEmpty;
    final canCancel =
        open != null && !chargeHasPaidInstallments(open) && !_cancelingCharge;
    final choice = await showPullDownMenu(
      context,
      groups: [
        if (hasInvoice)
          PullDownGroup([
            PullDownItem(
              value: 'copyLink',
              label: context.l10n.chargeCopyLink,
              icon: CupertinoIcons.doc_on_doc,
            ),
          ]),
        if (_canDiscount)
          PullDownGroup([
            PullDownItem(
              value: 'discount',
              label: context.l10n.receiveGiveDiscount,
              icon: CupertinoIcons.tag,
            ),
          ]),
        PullDownGroup([
          if (canCancel)
            PullDownItem(
              value: 'cancelLink',
              label: context.l10n.chargeCancelLink,
              icon: CupertinoIcons.xmark_circle,
              destructive: true,
            ),
          if (hasManual)
            PullDownItem(
              value: 'undo',
              label: context.l10n.receiveUndoPayments,
              icon: CupertinoIcons.arrow_uturn_left,
              destructive: true,
            ),
        ]),
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case 'copyLink':
        if (open != null) _copyChargeLink(open);
      case 'cancelLink':
        if (open != null) _confirmCancelCharge(open);
      case 'discount':
        _giveDiscount();
      case 'undo':
        _confirmUndoPayments();
    }
  }

  Future<void> _giveDiscount() async {
    final store = _store;
    if (store == null) return;
    final remaining = store.remainingBalance;
    if (remaining <= 0) return;
    final amount = await showReceiveDiscountSheet(
      context,
      currentTotal: store.total ?? 0.0,
      maxDiscount: remaining,
    );
    if (amount == null || !mounted) return;
    await _runBusy(() async {
      final ok = await store.addDiscountTransaction(amount);
      if (!mounted) return;
      if (!ok) {
        _showError(_paymentFailureMessage(store));
        return;
      }
    });
  }

  void _confirmUndoPayments() {
    // Shares of a customer receipt are undone from the receipt, never here.
    final groupId = (_store?.transactions ?? const <PaymentTransaction>[])
        .map((t) => t.receiptGroupId)
        .whereType<String>()
        .firstOrNull;
    if (groupId != null) {
      _explainReceiptGroup(groupId);
      return;
    }
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(context.l10n.receiveUndoPayments),
        content: Text(context.l10n.thisWillRemoveAllPayments),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(dialogContext);
              _runBusy(_doResetPayments);
            },
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
  }

  Future<void> _doResetPayments() async {
    final store = _store;
    if (store == null) return;
    final ok = await store.resetAllPayments();
    if (!mounted) return;
    if (!ok) {
      _showError(_paymentFailureMessage(store));
      return;
    }
  }

  // ============================================================
  // PAYMENT SHEET
  // ============================================================

  void _showPaymentSheet(PaymentTransaction tx) {
    // A share of a customer receipt: its own screen shows every OS it
    // covered, sends the recibo and undoes it as a whole.
    final groupId = tx.receiptGroupId;
    if (groupId != null && _canOpenReceiptGroup(tx)) {
      _openReceiptGroup(groupId);
      return;
    }
    // A share of a receipt someone else registered: shown, but it is undone
    // and its recibo sent from the receipt, by who can open it.
    final inOtherReceipt = groupId != null;
    final format = FormatService();
    final isPayment = tx.type == PaymentTransactionType.payment;
    final who = tx.isAsaas
        ? context.l10n.receiveRecordedAuto(format.formatDateTime(tx.createdAt))
        : context.l10n.receiveRecordedBy(
            tx.createdBy?.name ?? '-',
            format.formatDateTime(tx.createdAt),
          );
    final billing = receiveBillingLabel(context, tx);
    final canViewReceipt = tx.hasReceipt && _canView;
    // Receipt Asaas generated for a payment made through the link. It is a
    // payment record, not a photo: shown without the viewPhotos check.
    final asaasReceipt = tx.hasReceipt ? null : asaasReceiptUri(tx);
    final canAttachLater =
        isPayment && !tx.hasReceipt && asaasReceipt == null && _canAttach;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(
          '${isPayment ? '' : '- '}${format.formatCurrency(tx.amount)}'
          '${billing != null ? ' · $billing' : ''}',
        ),
        message: Text(who),
        actions: [
          if (isPayment && !tx.isAsaas && !inOtherReceipt && _canSendReceipt)
            CupertinoActionSheetAction(
              key: const Key('receiveSendReceipt'),
              onPressed: () {
                Navigator.pop(ctx);
                _sendReceipt(tx);
              },
              child: Text(context.l10n.receiptSend),
            ),
          if (canViewReceipt)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                _openReceipt(tx);
              },
              child: Text(context.l10n.receiveViewReceipt),
            ),
          if (asaasReceipt != null)
            CupertinoActionSheetAction(
              key: const Key('receiveAsaasReceipt'),
              onPressed: () {
                Navigator.pop(ctx);
                _openAsaasReceipt(asaasReceipt);
              },
              child: Text(context.l10n.receiveViewReceipt),
            ),
          if (canAttachLater)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                _attachToSaved(tx);
              },
              child: Text(context.l10n.receiveAttachReceipt),
            ),
          if (!tx.isAsaas && !inOtherReceipt)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                _confirmRemove(tx);
              },
              child: Text(context.l10n.receiveRemovePayment),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(context.l10n.cancel),
        ),
      ),
    );
  }

  Future<void> _openAsaasReceipt(Uri uri) async {
    final open = widget.onOpenExternalUrl;
    if (open != null) {
      await open(uri);
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  int _indexOf(PaymentTransaction tx) {
    final list = _store?.transactions ?? <PaymentTransaction>[];
    return list.indexWhere((t) => OrderPaymentMath.sameTransaction(t, tx));
  }

  Future<void> _openReceiptGroup(String receiptId) async {
    final open = widget.onOpenReceipt;
    final bool undone;
    if (open != null) {
      undone = await open(context, receiptId);
    } else {
      undone = await ReceiptDetailScreen.open(context, receiptId: receiptId);
    }
    if (!mounted) return;
    // The undo writes to every order of the receipt; this screen still
    // holds the old payments of this one.
    if (undone) await _store?.reloadPayments();
  }

  /// "Mandar recibo" of one payment of this order (no receipt document).
  Future<void> _sendReceipt(PaymentTransaction tx) async {
    final order = _store?.order;
    if (order == null) return;
    final data = ReceiptPdfData.fromPayment(order, tx);
    await (widget.onSendReceipt ?? shareReceiptPdf)(context, data);
  }

  /// A share of a customer receipt can't be removed alone: tells so and
  /// offers the receipt (undo there takes it out of every OS).
  void _explainReceiptGroup(String receiptId) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        content: Text(context.l10n.receiptPartOfGroup),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.cancel),
          ),
          CupertinoDialogAction(
            key: const Key('receiveOpenReceiptGroup'),
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(dialogContext);
              _openReceiptGroup(receiptId);
            },
            child: Text(context.l10n.receiptOpen),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(PaymentTransaction tx) {
    final groupId = tx.receiptGroupId;
    if (groupId != null) {
      _explainReceiptGroup(groupId);
      return;
    }
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(context.l10n.receiveRemovePayment),
        content: Text(
          context.l10n.confirmRemoveTransaction(
            tx.typeLabel(context.l10n).toLowerCase(),
            FormatService().formatCurrency(tx.amount),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(dialogContext);
              final store = _store;
              final index = _indexOf(tx);
              if (store == null || index < 0) return;
              _runBusy(() async {
                final ok = await store.removeTransaction(index);
                if (!mounted) return;
                if (!ok) {
                  _showError(_paymentFailureMessage(store));
                  return;
                }
              });
            },
            child: Text(context.l10n.remove),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RECEIPTS
  // ============================================================

  Future<PickedReceiptFile?> _pickReceipt() => pickReceiptFile(context);

  Future<void> _attachToSaved(PaymentTransaction tx) async {
    final picked = await _pickReceipt();
    final store = _store;
    if (picked == null || store == null || !mounted) return;
    final index = _indexOf(tx);
    if (index < 0) return;
    await _runBusy(() async {
      final ok = await store.attachReceiptToTransaction(
        index,
        picked.file,
        picked.contentType,
        picked.name,
      );
      if (!ok && mounted) _showError(_paymentFailureMessage(store));
    });
  }

  Future<void> _openReceipt(PaymentTransaction transaction) async {
    if (transaction.receiptDocumentId == null || _store == null) return;
    final doc = _store!.documents.cast<OrderDocument?>().firstWhere(
      (d) => d?.id == transaction.receiptDocumentId,
      orElse: () => null,
    );
    if (doc == null) return;

    // Refresh URL from storagePath to avoid stale tokens
    String? url = doc.url;
    if (doc.storagePath != null) {
      final freshUrl = await PhotoService().getFreshDownloadUrl(
        doc.storagePath!,
      );
      if (freshUrl != null) {
        url = freshUrl;
        doc.url = freshUrl;
      }
    }
    if (url == null || !mounted) return;

    if (doc.isImage) {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => ReceiptImageViewer(
            url: url!,
            title: doc.fileName ?? context.l10n.receipt,
          ),
        ),
      );
    } else {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  /// Plain message with "OK" (no title).
  void _showMessage(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.l10n.ok),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(context.l10n.attention),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: Text(context.l10n.ok),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
