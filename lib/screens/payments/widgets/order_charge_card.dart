import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/order_charge.dart';
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

/// Status of an open charge: dot and sentence ("Esperando Elias pagar", or
/// "Venceu em 28/10" in red) and what was charged. Shared by the Receber
/// screens; the actions live on the screen, under it.
class ChargeStatusCard extends StatelessWidget {
  const ChargeStatusCard({
    super.key,
    required this.status,
    required this.detail,
    this.overdue = false,
    this.note,
  });

  final String status;
  final String detail;
  final bool overdue;

  /// Extra line ("Falta mais R$ 900 fora do link.").
  final String? note;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondary.resolveFrom(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.blockMargin,
        0,
        AppSpacing.blockMargin,
        AppSpacing.md,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.resolveFrom(context),
        borderRadius: BorderRadius.circular(AppRadii.field),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DotLine(
            color: overdue ? AppColors.danger : AppColors.warning,
            text: status,
            style: AppTypography.body.copyWith(
              color: overdue
                  ? AppColors.danger.resolveFrom(context)
                  : AppColors.text.resolveFrom(context),
              fontWeight: overdue ? FontWeight.w600 : null,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            key: const Key('chargeLinkDetail'),
            style: AppTypography.callout.copyWith(
              color: secondary,
              fontFeatures: AppTypography.tabular,
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 2),
            Text(
              note!,
              key: const Key('chargeMissingOutsideLink'),
              style: AppTypography.callout.copyWith(color: secondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// [ChargeStatusCard] of an order's open charge. [remaining] is what the
/// order still owes: above the charge value, it says how much is outside.
class OrderChargeStatus extends StatelessWidget {
  const OrderChargeStatus({
    super.key,
    required this.charge,
    required this.customerName,
    this.remaining = 0,
  });

  final OrderCharge charge;
  final String? customerName;
  final double remaining;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = FormatService();
    final value = format.formatCurrency(charge.value ?? 0);
    final due = format.formatDayMonthOrDate(charge.dueDateValue);
    final overdue = charge.status == ChargeStatus.overdue;
    final name = customerName;
    final installments = charge.mode == ChargeMode.cardInstallments;

    final String detail;
    if (chargeHasPaidInstallments(charge)) {
      final paid = _paidCount(charge);
      detail = l10n.chargeInstallmentsPaid(
        paid,
        charge.installmentCount ?? paid,
      );
    } else if (installments && charge.installmentCount != null && !overdue) {
      detail = l10n.chargeInstallmentsUntil(charge.installmentCount!, due);
    } else if (overdue) {
      detail = installments
          ? l10n.chargeDetailValue(value)
          : l10n.chargeDetailOverdue(value);
    } else {
      detail = l10n.chargeDetailUntil(value, due);
    }

    final outside = remaining - (charge.value ?? 0);
    return ChargeStatusCard(
      key: const Key('chargeLinkBlock'),
      overdue: overdue,
      status: overdue
          ? l10n.chargeExpiredOn(due)
          : name == null || name.isEmpty
          ? l10n.chargeWaitingPayment
          : l10n.chargeWaitingFor(name),
      detail: detail,
      note: outside > OrderPaymentMath.centTolerance
          ? l10n.chargeMissingOutsideLink(format.formatCurrency(outside))
          : null,
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
