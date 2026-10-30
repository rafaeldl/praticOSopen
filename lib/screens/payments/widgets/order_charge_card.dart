import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/order_charge.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/utils/order_payment_math.dart';

/// Status dot color: amber pending, red overdue, green paid, grey closed.
/// Returns the dynamic role; callers resolve it (e.g. [StatusDot]).
Color chargeStatusColor(ChargeStatus? status) {
  switch (status) {
    case ChargeStatus.pending:
      return AppColors.warning;
    case ChargeStatus.overdue:
      return AppColors.danger;
    case ChargeStatus.paid:
      return AppColors.success;
    case ChargeStatus.canceled:
    case ChargeStatus.refunded:
    case null:
      return AppColors.textSecondary;
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
/// (the webhook added or reverted transactions), so the screen must reload
/// them:
/// - [next] became paid or refunded (status differs from [prev]); or
/// - the number of paid installments (`paidAsaasPaymentIds`) changed: with
///   card installments the server books each installment on the order while
///   the charge stays pending until the last one.
///
/// [prev] is the same charge (by id) in the previous emission, or null for
/// a charge not seen before. Never called for the first stream emission
/// (that is the initial state, not a transition), so opening the screen
/// doesn't trigger a reload.
bool chargeSettled(OrderCharge? prev, OrderCharge next) {
  final status = next.status;
  if ((status == ChargeStatus.paid || status == ChargeStatus.refunded) &&
      prev?.status != status) {
    return true;
  }
  return _paidCount(prev) != _paidCount(next);
}

int _paidCount(OrderCharge? charge) => charge?.paidAsaasPaymentIds?.length ?? 0;

/// Open charge with installments already paid: the server refuses to cancel
/// or replace it (`INSTALLMENTS_IN_PROGRESS`).
bool chargeHasPaidInstallments(OrderCharge charge) =>
    charge.isOpen && (charge.paidAsaasPaymentIds ?? const []).isNotEmpty;

/// Top block of the Receber screen while a payment link is open: when it was
/// sent, what is still missing and until when the link is valid, plus a
/// WhatsApp reminder. No filled button: the customer is the one who acts.
class ChargeLinkBlock extends StatelessWidget {
  const ChargeLinkBlock({
    super.key,
    required this.charge,
    required this.customerName,
    required this.onRemind,
    this.remaining = 0,
  });

  final OrderCharge charge;
  final String? customerName;
  final VoidCallback onRemind;

  /// What the order still owes; above the link value, the block says how
  /// much is missing outside the link.
  final double remaining;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = FormatService();
    final onSoft = AppColors.onAccentSoft.resolveFrom(context);
    final value = format.formatCurrency(charge.value ?? 0);
    final due = format.formatDayMonthOrDate(charge.dueDateValue);
    final overdue = charge.status == ChargeStatus.overdue;

    final String label;
    if (overdue && due.isNotEmpty) {
      label = l10n.chargeLinkExpiredOn(due);
    } else if (charge.createdAt != null) {
      label = l10n.chargeLinkSentOn(
        format.formatDayMonthOrDate(charge.createdAt),
      );
    } else {
      label = l10n.chargeLinkSent;
    }

    final name = customerName;
    var sentence = name == null || name.isEmpty
        ? l10n.chargeNotPaidYetNoCustomer(value)
        : l10n.chargeNotPaidYet(name, value);
    if (!overdue && due.isNotEmpty) {
      sentence = '$sentence ${l10n.chargeLinkValidUntil(due)}';
    }
    final outside = remaining - (charge.value ?? 0);

    return _BlockCard(
      key: const Key('chargeLinkBlock'),
      background: AppColors.accentSoft.resolveFrom(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.label.copyWith(color: onSoft)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            sentence,
            key: const Key('chargeLinkSentence'),
            style: AppTypography.highlight.copyWith(
              color: onSoft,
              fontFeatures: AppTypography.tabular,
            ),
          ),
          if (outside > OrderPaymentMath.centTolerance) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.chargeMissingOutsideLink(format.formatCurrency(outside)),
              key: const Key('chargeMissingOutsideLink'),
              style: AppTypography.callout.copyWith(color: onSoft),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          CupertinoButton(
            key: const Key('chargeRemindWhatsApp'),
            padding: EdgeInsets.zero,
            minimumSize: const Size(
              AppSizes.minTouchTarget,
              AppSizes.minTouchTarget,
            ),
            onPressed: onRemind,
            child: Text(
              l10n.chargeRemindWhatsApp,
              style: AppTypography.callout.copyWith(
                color: onSoft,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: onSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Top block when the order total changed after the link was sent and the
/// link now charges more than what is missing. One blue button creates a new
/// link (the server cancels the open one); null [onGenerate] hides it
/// (account disconnected).
class ChargeChangedBlock extends StatelessWidget {
  const ChargeChangedBlock({
    super.key,
    required this.remaining,
    required this.chargeValue,
    required this.onGenerate,
    this.busy = false,
  });

  final double remaining;
  final double chargeValue;
  final VoidCallback? onGenerate;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = FormatService();
    final onSoft = AppColors.onWarningSoft.resolveFrom(context);
    final remainingText = format.formatCurrency(remaining);
    return _BlockCard(
      key: const Key('chargeChangedBlock'),
      background: AppColors.warningSoft.resolveFrom(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.chargeOrderChanged,
            style: AppTypography.label.copyWith(color: onSoft),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.chargeNowMissing(
              remainingText,
              format.formatCurrency(chargeValue),
            ),
            style: AppTypography.highlight.copyWith(
              color: onSoft,
              fontFeatures: AppTypography.tabular,
            ),
          ),
          if (onGenerate != null) ...[
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              key: const Key('chargeRegenerateButton'),
              label: l10n.chargeGenerateNew(remainingText),
              onPressed: busy ? null : onGenerate,
            ),
          ],
        ],
      ),
    );
  }
}

/// Top block after the server canceled an installment plan the order no
/// longer owes in full: says so and offers a link with what is missing.
class ChargeCanceledBlock extends StatelessWidget {
  const ChargeCanceledBlock({
    super.key,
    required this.remaining,
    required this.onSend,
    this.busy = false,
  });

  final double remaining;
  final VoidCallback onSend;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onSoft = AppColors.onWarningSoft.resolveFrom(context);
    final remainingText = FormatService().formatCurrency(remaining);
    return _BlockCard(
      key: const Key('chargeCanceledBlock'),
      background: AppColors.warningSoft.resolveFrom(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.chargeInstallmentsCanceled,
            style: AppTypography.label.copyWith(color: onSoft),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.chargeSendNewLink(remainingText),
            style: AppTypography.highlight.copyWith(
              color: onSoft,
              fontFeatures: AppTypography.tabular,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            key: const Key('chargeSendNewLinkButton'),
            label: l10n.chargeGenerateNew(remainingText),
            onPressed: busy ? null : onSend,
          ),
        ],
      ),
    );
  }
}

/// "Link de pagamento" row under "Link para pagar". Informational only (no
/// chevron, not tappable): its actions live in the screen's "…" menu.
class ChargeLinkRow extends StatelessWidget {
  const ChargeLinkRow({
    super.key,
    required this.charge,
    required this.customerName,
    this.replacing = false,
  });

  final OrderCharge charge;
  final String? customerName;

  /// The "new link" block is showing: say that it cancels this one.
  final bool replacing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = FormatService();
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final due = format.formatDayMonthOrDate(charge.dueDateValue);
    final overdue = charge.status == ChargeStatus.overdue;
    final name = customerName;

    final Widget status;
    if (overdue) {
      final danger = AppColors.danger.resolveFrom(context);
      status = _DotLine(
        color: AppColors.danger,
        text: l10n.chargeExpiredOn(due),
        style: AppTypography.callout.copyWith(
          color: danger,
          fontWeight: FontWeight.w600,
        ),
      );
    } else {
      status = _DotLine(
        color: AppColors.warning,
        text: name == null || name.isEmpty
            ? l10n.chargeWaitingPayment
            : l10n.chargeWaitingFor(name),
        style: AppTypography.callout.copyWith(color: secondary),
      );
    }

    final String detail;
    if (chargeHasPaidInstallments(charge)) {
      final paid = _paidCount(charge);
      detail = l10n.chargeInstallmentsPaid(
        paid,
        charge.installmentCount ?? paid,
      );
    } else if (replacing) {
      detail = l10n.chargeUntilReplaced(due);
    } else if (charge.mode == ChargeMode.cardInstallments &&
        charge.installmentCount != null) {
      detail = l10n.chargeInstallmentsUntil(charge.installmentCount!, due);
    } else {
      detail = l10n.chargeMethodsUntil(due);
    }

    return AppListRow(
      key: const Key('chargeLinkRow'),
      title: l10n.chargePaymentLink,
      trailing: format.formatCurrency(charge.value ?? 0),
      subtitleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          status,
          const SizedBox(height: 2),
          Text(
            detail,
            key: const Key('chargeLinkDetail'),
            style: AppTypography.label.copyWith(color: secondary),
          ),
        ],
      ),
    );
  }
}

/// Status dot followed by its text (which wraps, never ellipsized).
class _DotLine extends StatelessWidget {
  const _DotLine({
    required this.color,
    required this.text,
    required this.style,
  });

  final Color color;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StatusDot(key: const Key('chargeStatusDot'), color: color),
        const SizedBox(width: AppSpacing.sm),
        Flexible(child: Text(text, style: style)),
      ],
    );
  }
}

/// Same card look as the Receber block ([AppRadii.block], soft fill).
class _BlockCard extends StatelessWidget {
  const _BlockCard({super.key, required this.child, required this.background});

  final Widget child;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.blockMargin,
        vertical: AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.block),
      ),
      child: child,
    );
  }
}
