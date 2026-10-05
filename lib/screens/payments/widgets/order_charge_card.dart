import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_charge.dart';
import 'package:praticos/repositories/tenant/order_charge_repository.dart';
import 'package:praticos/screens/payments/asaas_error_text.dart';
import 'package:praticos/screens/widgets/share_link_sheet.dart';
import 'package:praticos/services/asaas_api_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/utils/order_payment_math.dart';

/// Status dot color: blue pending, red overdue, green paid, grey closed.
Color chargeStatusColor(ChargeStatus? status) {
  switch (status) {
    case ChargeStatus.pending:
      return CupertinoColors.systemBlue;
    case ChargeStatus.overdue:
      return CupertinoColors.systemRed;
    case ChargeStatus.paid:
      return CupertinoColors.systemGreen;
    case ChargeStatus.canceled:
    case ChargeStatus.refunded:
    case null:
      return CupertinoColors.systemGrey;
  }
}

String chargeStatusLabel(AppLocalizations l10n, ChargeStatus? status) {
  switch (status) {
    case ChargeStatus.pending:
    case null:
      return l10n.chargeStatusPending;
    case ChargeStatus.overdue:
      return l10n.chargeStatusOverdue;
    case ChargeStatus.paid:
      return l10n.chargeStatusPaid;
    case ChargeStatus.canceled:
      return l10n.chargeStatusCanceled;
    case ChargeStatus.refunded:
      return l10n.chargeStatusRefunded;
  }
}

/// Whether a charge going from [prev] to [next] changed the order payments
/// (the webhook added or reverted a transaction): true when [next] is paid
/// or refunded and differs from [prev].
///
/// [prev] is null for a charge not seen before. The card never calls this
/// for the first stream emission (that is the initial state, not a
/// transition), so opening the screen doesn't trigger a reload.
bool chargeSettled(ChargeStatus? prev, ChargeStatus? next) =>
    (next == ChargeStatus.paid || next == ChargeStatus.refunded) &&
    prev != next;

/// Open charge with installments already paid: the server refuses to cancel
/// or replace it (`INSTALLMENTS_IN_PROGRESS`).
bool _hasPaidInstallments(OrderCharge charge) =>
    charge.isOpen && (charge.paidAsaasPaymentIds ?? const []).isNotEmpty;

/// "Charge" card of an order: current Asaas charge, its actions and the
/// "Charge with Asaas" button.
///
/// Only build it for users with `PermissionType.chargeOrder`: Firestore rules
/// deny reading `charges` to other roles.
class OrderChargeCard extends StatefulWidget {
  const OrderChargeCard({
    super.key,
    required this.order,
    required this.remainingBalance,
    required this.canCreateCharge,
    required this.onCreateCharge,
    this.onChargeSettled,
    this.chargesStream,
    this.service,
  });

  final Order order;
  final double remainingBalance;

  /// Account connected and user allowed to charge.
  final bool canCreateCharge;

  /// Opens the create charge screen. The card ignores new taps until the
  /// returned future completes (await the pushed route).
  final FutureOr<void> Function() onCreateCharge;

  /// Called when a watched charge becomes paid or refunded (see
  /// [chargeSettled]); the screen reloads the order payments.
  final VoidCallback? onChargeSettled;

  /// Test seam; defaults to [OrderChargeRepository.watch].
  final Stream<List<OrderCharge>>? chargesStream;

  /// Test seam; defaults to [AsaasApiService.instance].
  final AsaasApiService? service;

  @override
  State<OrderChargeCard> createState() => _OrderChargeCardState();
}

class _OrderChargeCardState extends State<OrderChargeCard> {
  final _formatService = FormatService();
  StreamSubscription<List<OrderCharge>>? _subscription;
  List<OrderCharge> _charges = const [];

  /// Last known status per charge id; null until the first emission.
  Map<String, ChargeStatus?>? _knownStatuses;

  bool _canceling = false;
  bool _creating = false;

  /// Replace dialog open (no spinner; just blocks a second dialog).
  bool _confirmingReplace = false;

  AsaasApiService get _service => widget.service ?? AsaasApiService.instance;

  @override
  void initState() {
    super.initState();
    _subscription = (widget.chargesStream ?? _watchCharges()).listen(
      _onCharges,
      // E.g. permission denied by the rules: behave as "no charge".
      onError: (Object _) {
        if (mounted) setState(() => _charges = const []);
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Stream<List<OrderCharge>> _watchCharges() {
    final companyId = widget.order.company?.id ?? Global.companyAggr?.id;
    final orderId = widget.order.id;
    if (companyId == null || orderId == null) {
      return Stream.value(const <OrderCharge>[]);
    }
    return OrderChargeRepository().watch(companyId, orderId);
  }

  void _onCharges(List<OrderCharge> charges) {
    final previous = _knownStatuses;
    final settled = previous != null &&
        charges.any((c) => chargeSettled(previous[c.id], c.status));
    _knownStatuses = {for (final c in charges) c.id ?? '': c.status};
    if (!mounted) return;
    setState(() => _charges = charges);
    if (settled) widget.onChargeSettled?.call();
  }

  bool get _blockedByInstallments => _charges.any(_hasPaidInstallments);

  bool get _showCreateButton =>
      widget.canCreateCharge &&
      widget.remainingBalance > 0 &&
      !_blockedByInstallments;

  @override
  Widget build(BuildContext context) {
    _formatService.setLocale(Localizations.localeOf(context).toString());
    final charge = OrderCharge.current(_charges);
    if (charge == null && !_showCreateButton) {
      return const SizedBox.shrink();
    }
    return CupertinoListSection.insetGrouped(
      header: Text(context.l10n.chargeSectionTitle.toUpperCase()),
      children: [
        if (charge != null) ..._buildChargeRows(context, charge),
        if (_showCreateButton) _buildCreateTile(context, charge),
      ],
    );
  }

  List<Widget> _buildChargeRows(BuildContext context, OrderCharge charge) {
    final l10n = context.l10n;
    final value = charge.value ?? 0;
    final locked = _hasPaidInstallments(charge);
    // Only when the order became smaller than the charge; a down payment
    // (charge below the balance) is fine.
    final balanceBelowCharge = charge.isOpen &&
        !locked &&
        value > widget.remainingBalance + OrderPaymentMath.centTolerance;
    final canShare = charge.isOpen || charge.status == ChargeStatus.paid;
    final hasInvoice = (charge.invoiceUrl ?? '').isNotEmpty;

    return [
      CupertinoListTile(
        key: const Key('chargeStatusTile'),
        leading: Center(
          child: Container(
            key: const Key('chargeStatusDot'),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: CupertinoDynamicColor.resolve(
                  chargeStatusColor(charge.status), context),
              shape: BoxShape.circle,
            ),
          ),
        ),
        title: Text(chargeStatusLabel(l10n, charge.status)),
        subtitle: Text(_subtitle(l10n, charge)),
        additionalInfo: Text(_formatService.formatCurrency(value)),
      ),
      if (balanceBelowCharge) _buildBalanceWarning(context, charge),
      if (canShare)
        CupertinoListTile(
          key: const Key('chargeShareTile'),
          leading: const Icon(CupertinoIcons.square_arrow_up),
          title: Text(l10n.chargeShareOrderLink),
          onTap: () => ShareLinkSheet.show(context, widget.order),
        ),
      if (canShare && hasInvoice)
        CupertinoListTile(
          key: const Key('chargeCopyInvoiceTile'),
          leading: const Icon(CupertinoIcons.doc_on_doc),
          title: Text(l10n.chargeCopyInvoiceLink),
          onTap: () => _copyInvoice(charge),
        ),
      if (charge.isOpen && !locked)
        CupertinoListTile(
          key: const Key('chargeCancelTile'),
          leading: const Icon(
            CupertinoIcons.xmark_circle,
            color: CupertinoColors.systemRed,
          ),
          title: Text(
            l10n.chargeCancel,
            style: const TextStyle(color: CupertinoColors.systemRed),
          ),
          trailing: _canceling ? const CupertinoActivityIndicator() : null,
          onTap: _canceling ? null : () => _confirmCancel(charge),
        ),
    ];
  }

  String _subtitle(AppLocalizations l10n, OrderCharge charge) {
    final due =
        l10n.chargeDueOn(_formatService.formatDate(charge.dueDateValue));
    if (charge.mode == ChargeMode.cardInstallments &&
        charge.installmentCount != null) {
      return '${l10n.chargeInstallmentsSummary(charge.installmentCount!)} · $due';
    }
    return due;
  }

  Widget _buildBalanceWarning(BuildContext context, OrderCharge charge) {
    final l10n = context.l10n;
    return Padding(
      key: const Key('chargeBalanceWarning'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_triangle_fill,
                color: CupertinoColors.systemOrange,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.chargeTotalChanged(
                    _formatService.formatCurrency(widget.remainingBalance),
                    _formatService.formatCurrency(charge.value ?? 0),
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            ],
          ),
          if (_showCreateButton)
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(
                key: const Key('chargeRegenerateButton'),
                padding: const EdgeInsets.only(top: 6),
                minimumSize: Size.zero,
                onPressed: _creating ? null : _runCreate,
                child: Text(
                  l10n.chargeRegenerate,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCreateTile(BuildContext context, OrderCharge? current) {
    final primary = CupertinoTheme.of(context).primaryColor;
    return CupertinoListTile(
      key: const Key('createChargeTile'),
      leading: Icon(CupertinoIcons.creditcard, color: primary),
      title: Text(
        context.l10n.chargeWithAsaas,
        style: TextStyle(color: primary),
      ),
      trailing: _creating
          ? const CupertinoActivityIndicator()
          : const CupertinoListTileChevron(),
      onTap: _creating ? null : () => _onCreatePressed(current),
    );
  }

  Future<void> _onCreatePressed(OrderCharge? current) async {
    if (current == null || !current.isOpen) {
      await _runCreate();
      return;
    }
    if (_confirmingReplace || _creating) return;
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
    if (confirmed == true) await _runCreate();
  }

  /// Runs [OrderChargeCard.onCreateCharge] once at a time (double tap guard).
  Future<void> _runCreate() async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      await widget.onCreateCharge();
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _copyInvoice(OrderCharge charge) async {
    await Clipboard.setData(ClipboardData(text: charge.invoiceUrl!));
    if (!mounted) return;
    _showMessage(context.l10n.chargeInvoiceLinkCopied);
  }

  Future<void> _confirmCancel(OrderCharge charge) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(dialogContext.l10n.chargeCancel),
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
            child: Text(dialogContext.l10n.chargeCancel),
          ),
        ],
      ),
    );
    if (confirmed != true || charge.id == null || widget.order.id == null) {
      return;
    }
    if (!mounted || _canceling) return;

    setState(() => _canceling = true);
    try {
      await _service.cancelCharge(widget.order.id!, charge.id!);
    } on AsaasApiException catch (e) {
      if (mounted) _showMessage(asaasErrorText(context.l10n, e));
    } catch (_) {
      // Unexpected response: generic text, never the raw error.
      if (mounted) {
        _showMessage(
            asaasErrorText(context.l10n, AsaasApiException(null, '')));
      }
    } finally {
      if (mounted) setState(() => _canceling = false);
    }
  }

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
}
