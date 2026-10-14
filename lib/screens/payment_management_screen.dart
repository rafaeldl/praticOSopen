import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order_charge.dart';
import 'package:praticos/models/order_document.dart';
import 'package:praticos/models/payment_settings.dart';
import 'package:praticos/models/payment_transaction.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/screens/payments/asaas_error_text.dart';
import 'package:praticos/screens/payments/create_charge_screen.dart';
import 'package:praticos/screens/payments/widgets/order_charge_card.dart';
import 'package:praticos/screens/payments/widgets/order_charge_section.dart';
import 'package:praticos/screens/payments/widgets/receive_amount_field.dart';
import 'package:praticos/screens/payments/widgets/receive_block.dart';
import 'package:praticos/screens/payments/widgets/receive_discount_sheet.dart';
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
import 'package:praticos/services/photo_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/utils/asaas_billing.dart';
import 'package:praticos/utils/currency_input.dart';
import 'package:praticos/utils/order_payment_math.dart';
import 'package:praticos/utils/payment_update_failure.dart';
import 'package:url_launcher/url_launcher.dart';

/// "Receber" screen of an order: one block answering "did the customer pay?"
/// (amount already filled, one "Recebi R$ X" button), the received payments
/// list ("Já recebido") and, for Asaas companies, the payment link: an open
/// link takes the top block ("Link mandado em…") and gets its own row, and
/// its actions (copy, send again, cancel) live in the "…" menu.
///
/// Payment method is not asked: it is shown only for payments that came from
/// Asaas. Discount and "undo payments" live in the "…" menu. Tapping a payment
/// opens its sheet (view/attach receipt, remove). No success dialogs: after
/// "Recebi" the block turns into "Tudo recebido" or shows the new balance.
class PaymentManagementScreen extends StatefulWidget {
  const PaymentManagementScreen({
    super.key,
    this.store,
    this.canAttachReceipt,
    this.canViewReceipt,
    this.onOpenExternalUrl,
    this.canCharge,
    this.paymentSettingsStream,
    this.chargesStream,
    this.chargeService,
  });

  /// Order store. When null it comes from the route arguments (`orderStore`).
  final OrderStore? store;

  /// Test seams; default to the attachPhotos / viewPhotos permission checks.
  final bool? canAttachReceipt;
  final bool? canViewReceipt;

  /// Test seam; defaults to opening the link in the browser.
  final Future<void> Function(Uri uri)? onOpenExternalUrl;

  /// Test seams for the Asaas charge part; default to the chargeOrder
  /// permission, the company payment settings, the order charges and
  /// [AsaasApiService.instance].
  final bool? canCharge;
  final Stream<PaymentSettings>? paymentSettingsStream;
  final Stream<List<OrderCharge>>? chargesStream;
  final AsaasApiService? chargeService;

  @override
  State<PaymentManagementScreen> createState() =>
      _PaymentManagementScreenState();
}

class _PickedReceipt {
  _PickedReceipt(this.file, this.contentType, this.name);
  final File file;
  final String contentType;
  final String name;
}

enum _ReceiptSource { camera, gallery, files }

class _PaymentManagementScreenState extends State<PaymentManagementScreen> {
  bool _initialized = false;
  OrderStore? _store;

  /// True while a payment operation is running: the buttons are disabled so
  /// the same payment can't be sent twice.
  bool _busy = false;

  final TextEditingController _valueController = TextEditingController();
  _PickedReceipt? _receipt;

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
      if (_store == null) {
        final args =
            ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        if (args != null && args.containsKey('orderStore')) {
          _store = args['orderStore'];
        }
        _fromOrder = args?['fromOrder'] == true;
      }
      _prefillValue();
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
    }
  }

  @override
  void dispose() {
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
  }

  bool get _canAttach =>
      widget.canAttachReceipt ??
      AuthorizationService.instance.hasPermission(PermissionType.attachPhotos);
  bool get _canView =>
      widget.canViewReceipt ??
      AuthorizationService.instance.hasPermission(PermissionType.viewPhotos);

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
        if (_store == null || status == 'quote' || status == 'canceled') {
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
    );
  }

  /// "Já recebido": the payments, newest first. Paid charges are not listed
  /// apart: their money is already here as transactions.
  Widget _buildPayments() {
    final transactions = _store?.transactions ?? <PaymentTransaction>[];
    if (transactions.isEmpty) return const SizedBox.shrink();
    final sorted = List<PaymentTransaction>.from(transactions)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
    _showMessage(context.l10n.chargeLinkCopied);
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

    final transaction = await store.addPayment(value);
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
      }
    }
    if (!mounted) return;
    if (transaction == null) {
      _showError(_paymentFailureMessage(store));
      return;
    }
    setState(() => _receipt = null);
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
          if (!tx.isAsaas)
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

  void _confirmRemove(PaymentTransaction tx) {
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

  Future<_PickedReceipt?> _pickReceipt() async {
    final source = await showCupertinoModalPopup<_ReceiptSource>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, _ReceiptSource.camera),
            child: Text(context.l10n.takePhoto),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, _ReceiptSource.gallery),
            child: Text(context.l10n.gallery),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, _ReceiptSource.files),
            child: Text(context.l10n.fromFiles),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(context.l10n.cancel),
        ),
      ),
    );
    if (source == null) return null;
    final photoService = PhotoService();
    String photoName() => 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg';
    switch (source) {
      case _ReceiptSource.camera:
        final file = await photoService.takePhoto();
        return file == null
            ? null
            : _PickedReceipt(file, 'image/jpeg', photoName());
      case _ReceiptSource.gallery:
        final file = await photoService.pickImageFromGallery();
        return file == null
            ? null
            : _PickedReceipt(file, 'image/jpeg', photoName());
      case _ReceiptSource.files:
        final result = await photoService.pickDocument();
        if (result == null || result.path == null) return null;
        return _PickedReceipt(
          File(result.path!),
          _contentTypeOf(result.extension?.toLowerCase() ?? ''),
          result.name,
        );
    }
  }

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
          builder: (context) => _ReceiptImageViewer(
            url: url!,
            title: doc.fileName ?? context.l10n.receipt,
          ),
        ),
      );
    } else {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  String _contentTypeOf(String extension) {
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
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

/// Full-screen receipt image viewer
class _ReceiptImageViewer extends StatelessWidget {
  final String url;
  final String title;

  const _ReceiptImageViewer({required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black.withValues(alpha: 0.8),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back, color: CupertinoColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        middle: Text(
          title,
          style: const TextStyle(color: CupertinoColors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      child: SafeArea(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 3.0,
          child: Center(
            child: Image.network(
              url,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const CupertinoActivityIndicator();
              },
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  CupertinoIcons.exclamationmark_triangle,
                  color: AppColors.textSecondary.resolveFrom(context),
                  size: 48,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
