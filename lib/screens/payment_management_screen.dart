import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart' show ReactionDisposer, reaction;
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
import 'package:praticos/screens/payments/widgets/receive_amount_field.dart';
import 'package:praticos/screens/payments/widgets/receipt_file_picker.dart';
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
import 'package:praticos/utils/currency_input.dart';
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

/// "Receber" screen of an order: one block answering "did the customer pay?"
/// (amount already filled, one "Confirmar recebimento" button), the received payments
/// list ("Já recebido") and, for Asaas companies, the payment link: an open
/// link takes the top block ("Link mandado em…") and gets its own row, and
/// its actions (copy, send again, cancel) live in the "…" menu.
///
/// Payment method is not asked: it is shown only for payments that came from
/// Asaas. Discount and "undo payments" live in the "…" menu. Tapping a payment
/// opens its sheet (send recibo, view/attach receipt, remove); a payment that
/// is a share of a customer receipt opens the "Recebimento" screen instead.
/// No success dialogs: after
/// "Confirmar recebimento" the block turns into "Tudo recebido" or shows the new balance.
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

  final TextEditingController _valueController = TextEditingController();
  PickedReceiptFile? _receipt;

  /// What [_prefillValue] last wrote: while the field still shows it, a new
  /// balance (a link paid by the webhook, a reload) replaces it.
  String? _prefilledText;
  ReactionDisposer? _balanceReaction;

  /// Day the money came in ("Quando"); today by default.
  DateTime _paidDay = DateTime.now();

  /// Opened from the order screen: "‹ OS 183" just goes back to it.
  bool _fromOrder = false;

  /// Asaas charge state; null without an order store.
  OrderChargeController? _charge;

  /// Double-tap guards of the charge actions.
  bool _creatingCharge = false;
  bool _cancelingCharge = false;
  bool _confirmingReplace = false;

  /// "Recebi de outro jeito": the manual receive block replaces the open
  /// link block for this visit.
  bool _receiveOtherWay = false;

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
      _receipt = _initialReceipt;
      _prefillValue();
      final store = _store;
      if (store != null) {
        _balanceReaction = reaction<double>((_) => store.remainingBalance, (_) {
          if (mounted && _valueController.text == _prefilledText) {
            _prefillValue();
          }
        });
        _charge = OrderChargeController(
          store: store,
          canCharge: widget.canCharge,
          settingsStream: widget.paymentSettingsStream,
          chargesStream: widget.chargesStream,
        );
      }
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _balanceReaction?.call();
    _valueController.dispose();
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

  void _prefillValue() {
    final remaining = _store?.remainingBalance ?? 0.0;
    _valueController.text = remaining > 0
        ? ReceiveAmountField.textFor(remaining)
        : '';
    _prefilledText = _valueController.text;
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
      backgroundColor: AppColors.background.resolveFrom(context),
      child: Material(
        type: MaterialType.transparency,
        child: CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              backgroundColor: AppNavBar.barBackground(context),
              alwaysShowMiddle: false,
              largeTitle: Text(context.l10n.receiveTitle),
              leading: _buildOrderLink(),
              trailing: _buildMoreButton(),
            ),
            SliverToBoxAdapter(child: _buildSubtitle()),
            SliverSafeArea(
              top: false,
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildContent(),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
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

  /// "Ana Ribeiro · total R$ 1.250" under the title, plus
  /// " · desconto R$ 50" when the order has a discount.
  Widget _buildSubtitle() {
    return Observer(
      builder: (_) {
        final store = _store;
        if (store == null) return const SizedBox.shrink();
        final total = FormatService().formatCurrency(store.total ?? 0.0);
        final name = store.customerName;
        final discountValue = store.discount ?? 0.0;
        final discount = FormatService().formatCurrency(discountValue);
        final hasName = name != null && name.isNotEmpty;
        final String text;
        if (discountValue > 0) {
          text = hasName
              ? context.l10n.receiveSubtitleWithDiscount(name, total, discount)
              : context.l10n.receiveSubtitleNoCustomerWithDiscount(
                  total,
                  discount,
                );
        } else {
          text = hasName
              ? context.l10n.receiveSubtitle(name, total)
              : context.l10n.receiveSubtitleNoCustomer(total);
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageMargin,
            0,
            AppSpacing.pageMargin,
            AppSpacing.sm,
          ),
          child: Text(
            text,
            key: const Key('receiveSubtitle'),
            style: AppTypography.callout.copyWith(
              color: AppColors.textSecondary.resolveFrom(context),
              fontFeatures: AppTypography.tabular,
            ),
          ),
        );
      },
    );
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

  /// Everything below the subtitle: the top block (manual receive, open
  /// link or "the order changed"), the open link row, the payments and the
  /// "send a link" action.
  Widget _buildContent() {
    return ListenableBuilder(
      listenable: _charge ?? Listenable.merge(const <Listenable>[]),
      builder: (context, _) => Observer(
        builder: (_) {
          final store = _store;
          // Read the observables so the screen follows payment changes.
          final remaining = store?.remainingBalance ?? 0.0;
          final applies = store != null && _chargeApplies(store);
          if (applies) _charge!.reloadOnFirstShow();
          final open = applies ? _charge!.openCharge : null;
          const tolerance = OrderPaymentMath.centTolerance;

          final children = <Widget>[];
          var replacing = false;
          if (open == null) {
            children.add(_buildReceiveBlock());
          } else {
            final value = open.value ?? 0.0;
            final locked = chargeHasPaidInstallments(open);
            if (remaining <= tolerance) {
              children.add(_buildReceiveBlock(isPaid: true));
            } else if (!locked &&
                value > remaining + tolerance &&
                _keptChargeId != open.id) {
              // The order total dropped below the link value.
              replacing = true;
              children.addAll([
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
                    label: context.l10n.chargeKeepLink(
                      FormatService().formatCurrency(value),
                    ),
                    onPressed: () => setState(() => _keptChargeId = open.id),
                  ),
                ),
              ]);
            } else if (_receiveOtherWay) {
              children.add(_buildReceiveBlock());
            } else {
              children.addAll([
                ChargeLinkBlock(
                  charge: open,
                  customerName: store!.customerName,
                  onRemind: _shareOrderLink,
                ),
                _linkPadding(
                  TextLink(
                    key: const Key('chargeReceivedOtherWay'),
                    label: context.l10n.chargeReceivedOtherWay,
                    onPressed: () => setState(() => _receiveOtherWay = true),
                  ),
                ),
              ]);
            }
            children.addAll([
              SectionLabel(context.l10n.chargeLinkSection),
              ChargeLinkRow(
                charge: open,
                customerName: store!.customerName,
                replacing: replacing,
              ),
            ]);
          }

          children.add(_buildPayments());

          final canSendLink =
              applies &&
              open == null &&
              _charge!.connected &&
              remaining > tolerance &&
              !_charge!.blockedByInstallments;
          if (canSendLink) {
            final name = store.customerName;
            children.add(
              _linkPadding(
                TextLink(
                  key: const Key('chargeSendLink'),
                  label: name == null || name.isEmpty
                      ? context.l10n.chargeSendLink
                      : context.l10n.chargeSendLinkTo(name),
                  onPressed: _creatingCharge
                      ? null
                      : () => _onSendLinkPressed(remaining),
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          );
        },
      ),
    );
  }

  /// Text link aligned with the page margin.
  Widget _linkPadding(Widget link) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMargin),
      child: Align(alignment: AlignmentDirectional.centerStart, child: link),
    );
  }

  /// Manual receive block. [isPaid] overrides the store (an open link whose
  /// value is already covered within the cent tolerance).
  Widget _buildReceiveBlock({bool? isPaid}) {
    final status = _store?.status;
    String? blocked;
    // Payments are allowed from 'approved' on; not for quotes or canceled.
    if (status == 'quote') blocked = context.l10n.statusQuote;
    if (status == 'canceled') blocked = context.l10n.statusCancelled;
    return ReceiveBlock(
      isPaid: isPaid ?? _store?.isFullyPaid ?? false,
      blockedMessage: blocked,
      controller: _valueController,
      busy: _busy,
      onConfirm: _register,
      receiptName: _receipt?.name,
      onAttachReceipt: _canAttach ? _attachBeforeSaving : null,
      onRemoveReceipt: () => setState(() => _receipt = null),
      paidDay: _paidDay,
      onPickDay: _pickPaidDay,
    );
  }

  Future<void> _pickPaidDay() async {
    final day = await pickPaymentDay(context, _paidDay);
    if (day != null && mounted) setState(() => _paidDay = day);
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

  String? _validateValue(double value) {
    if (value <= 0) return context.l10n.valueMustBeGreaterThanZero;
    if (_store != null && value > _store!.remainingBalance) {
      return context.l10n.paymentCannotExceedBalance;
    }
    return null;
  }

  void _register() => _runBusy(_doRegister);

  Future<void> _doRegister() async {
    final store = _store;
    if (store == null) return;
    final value = parseCurrencyInput(_valueController.text);
    final error = _validateValue(value);
    if (error != null) {
      _showError(error);
      return;
    }

    final transaction = await store.addPayment(
      value,
      paidAt: paidAtFor(_paidDay),
    );
    var receiptOk = true;
    final receipt = _receipt;
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
    setState(() {
      _receipt = null;
      _paidDay = DateTime.now();
    });
    _prefillValue();
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
        if (open != null)
          PullDownGroup([
            if (hasInvoice)
              PullDownItem(
                value: 'copyLink',
                label: context.l10n.chargeCopyLink,
                icon: CupertinoIcons.doc_on_doc,
              ),
            PullDownItem(
              value: 'shareLink',
              label: context.l10n.chargeSendAgainWhatsApp,
              icon: CupertinoIcons.square_arrow_up,
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
      case 'shareLink':
        _shareOrderLink();
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
      _prefillValue();
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
    _prefillValue();
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
    if (mounted) _prefillValue();
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
                _prefillValue();
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

  Future<void> _attachBeforeSaving() async {
    final picked = await _pickReceipt();
    if (picked != null && mounted) setState(() => _receipt = picked);
  }

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
