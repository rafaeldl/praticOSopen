import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/screens/order/assistant/ai_actions_plan.dart';
import 'package:praticos/screens/order/new_order_form.dart';
import 'package:praticos/screens/payments/order_payment_actions.dart';
import 'package:praticos/screens/payments/widgets/order_charge_section.dart';
import 'package:praticos/screens/payments/widgets/receive_discount_sheet.dart';
import 'package:praticos/screens/payments/widgets/receive_payment_row.dart';
import 'package:praticos/screens/payments/widgets/receive_payment_sheet.dart';
import 'package:praticos/screens/widgets/form_sheet.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/services/ai_order_assist_service.dart';
import 'package:praticos/services/customer_receipt_service.dart'
    show PickedReceiptFile;
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// How long "Confirmar" waits for the open charge. Offline the read never
/// comes, and that must not block a payment that works offline.
const Duration kAiChargeReadTimeout = Duration(seconds: 2);

/// Sentence for a part of the request that is not on the card.
String aiActionNoticeText(AppLocalizations l10n, AiActionNotice notice) {
  final format = FormatService()..setLocale(l10n.localeName);
  return switch (notice.kind) {
    AiActionNoticeKind.cannotReceive => l10n.aiActionsCannotReceive,
    AiActionNoticeKind.cannotDiscount => l10n.aiActionsCannotDiscount,
    AiActionNoticeKind.canceled => l10n.aiActionsOrderCanceled,
    AiActionNoticeKind.nothingToReceive => l10n.aiActionsNothingToReceive,
    AiActionNoticeKind.onlyLeft => l10n.aiActionsOnlyLeft(
      format.formatCurrency(notice.amount ?? 0),
    ),
    AiActionNoticeKind.pendingChecklists => l10n.orderPendingChecklists(
      notice.count ?? 1,
    ),
    AiActionNoticeKind.statusDenied => l10n.permissionDenied,
  };
}

/// What came out of the card when confirmed.
class AiActionsConfirmation {
  const AiActionsConfirmation(this.plan, {required this.edited});

  final AiActionsPlan plan;
  final bool edited;
}

/// "Confere?": what the assistant understood, in steps, with one blue button.
/// The money rows open the same sheets as Receber. Pops with an
/// [AiActionsConfirmation]; closing it saves nothing.
class AiActionsSheet extends StatefulWidget {
  const AiActionsSheet({
    super.key,
    required this.actions,
    required this.order,
    required this.subtitle,
    required this.statusLabel,
    required this.store,
    this.customerName,
    this.canAttach = true,
    this.charges,
  });

  final AiOrderActions actions;
  final AiActionsContext order;

  /// "OS 186 · Revenda Sul".
  final String subtitle;

  /// Name of a status in this segment.
  final String Function(String status) statusLabel;
  final OrderStore store;
  final String? customerName;
  final bool canAttach;

  /// Open charge of the order (tests); defaults to a new controller.
  final OrderChargeController? charges;

  static Future<AiActionsConfirmation?> show(
    BuildContext context, {
    required AiOrderActions actions,
    required AiActionsContext order,
    required String subtitle,
    required String Function(String status) statusLabel,
    required OrderStore store,
    String? customerName,
    bool canAttach = true,
    OrderChargeController? charges,
  }) {
    return FormSheet.show<AiActionsConfirmation>(
      context,
      (_) => AiActionsSheet(
        actions: actions,
        order: order,
        subtitle: subtitle,
        statusLabel: statusLabel,
        store: store,
        customerName: customerName,
        canAttach: canAttach,
        charges: charges,
      ),
    );
  }

  @override
  State<AiActionsSheet> createState() => _AiActionsSheetState();
}

class _AiActionsSheetState extends State<AiActionsSheet> {
  late final OrderChargeController _charges =
      widget.charges ?? OrderChargeController(store: widget.store);
  Timer? _chargeWait;
  bool _chargeGaveUp = false;
  bool _edited = false;
  AiActionsEdits _edits = const AiActionsEdits();

  AiActionsPlan get _plan =>
      planAiActions(widget.actions, widget.order, edits: _edits);

  @override
  void initState() {
    super.initState();
    _charges.addListener(_onCharges);
    if (!_charges.ready) {
      _chargeWait = Timer(kAiChargeReadTimeout, () {
        if (mounted) setState(() => _chargeGaveUp = true);
      });
    }
  }

  @override
  void dispose() {
    _chargeWait?.cancel();
    _charges.removeListener(_onCharges);
    if (widget.charges == null) _charges.dispose();
    super.dispose();
  }

  void _onCharges() {
    if (mounted) setState(() {});
  }

  void _edit(AiActionsEdits edits) => setState(() {
    _edits = edits;
    _edited = true;
  });

  AiActionsEdits _with({
    double? discount,
    ReceiveDraft? payment,
  }) => AiActionsEdits(
    discount: discount ?? _edits.discount,
    payment: payment?.amount ?? _edits.payment,
    method: payment != null ? payment.paymentMethod : _edits.method,
    methodEdited: payment != null || _edits.methodEdited,
    paidDay: payment?.paidDay ?? _edits.paidDay,
    receipt: payment != null ? payment.receipt : _edits.receipt,
  );

  Future<void> _editPayment(AiPaymentStep step) async {
    final l10n = context.l10n;
    final name = widget.customerName;
    final hasName = name != null && name.isNotEmpty;
    final draft = await ReceivePaymentSheet.show(
      context,
      title: hasName
          ? l10n.receiveReceivedFrom(name)
          : l10n.receiveReceivedTitle,
      max: step.max,
      preview: (amount) => receivePreview(l10n, amount, step.max),
      initial: ReceiveDraft(
        amount: step.amount ?? 0,
        paidDay: step.paidDay ?? DateTime.now(),
        paymentMethod: step.method,
        receipt: step.receipt as PickedReceiptFile?,
      ),
      canAttach: widget.canAttach,
      note: _chargeNote(l10n),
    );
    if (draft != null && mounted) _edit(_with(payment: draft));
  }

  Future<void> _editDiscount(AiActionsPlan plan) async {
    final amount = await showReceiveDiscountSheet(
      context,
      currentTotal: plan.total,
      maxDiscount: plan.discountMax,
      initial: plan.discount,
    );
    if (amount != null && mounted) _edit(_with(discount: amount));
  }

  String? _chargeNote(AppLocalizations l10n) {
    if (_charges.openCharge == null) return null;
    final name = widget.customerName;
    return name != null && name.isNotEmpty
        ? l10n.receiveChargeAdjusts(name)
        : l10n.receiveChargeAdjustsNoName;
  }

  String _paymentDetail(AppLocalizations l10n, AiPaymentStep step) {
    final format = FormatService()..setLocale(l10n.localeName);
    final day = step.paidDay;
    final today = DateTime.now();
    final past =
        day != null &&
        DateTime(day.year, day.month, day.day).isBefore(
          DateTime(today.year, today.month, today.day),
        );
    return [
      ?paymentMethodLabel(l10n, step.method),
      if (past) format.formatDate(day),
      if (step.amount == null)
        l10n.aiActionsTypeAmount
      else if (step.paysOff)
        l10n.aiActionsPaidOff
      else
        l10n.aiActionsLeft(format.formatCurrency(step.left!)),
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = FormatService()..setLocale(l10n.localeName);
    final plan = _plan;
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final payment = plan.payment;
    final discount = plan.discount;
    final chargeNote = payment == null ? null : _chargeNote(l10n);
    final notes = [
      for (final notice in plan.notices) aiActionNoticeText(l10n, notice),
      if (plan.issuesNfse) l10n.aiActionsIssuesNfse,
      ?chargeNote,
    ];
    final chargeRead = _charges.ready || _chargeGaveUp;
    return CupertinoPageScaffold(
      key: const Key('aiActionsSheet'),
      backgroundColor: AppColors.groupedBackground.resolveFrom(context),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.blockMargin + AppSpacing.lg,
                      AppSpacing.xl,
                      AppSpacing.blockMargin + AppSpacing.lg,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.aiActionsTitle,
                          style: AppTypography.title.copyWith(
                            color: AppColors.text.resolveFrom(context),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          widget.subtitle,
                          style: AppTypography.callout.copyWith(
                            color: secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FormCard(
                    children: [
                      if (discount != null)
                        FormRow(
                          key: const Key('aiActionsDiscountRow'),
                          icon: CupertinoIcons.tag,
                          title: l10n.aiActionsDiscount(
                            format.formatCurrency(discount),
                          ),
                          subtitle: l10n.aiActionsNewTotal(
                            format.formatCurrency(plan.total - discount),
                          ),
                          onTap: () => _editDiscount(plan),
                        ),
                      if (plan.approveFirst)
                        FormRow(
                          key: const Key('aiActionsApproveRow'),
                          icon: CupertinoIcons.checkmark_seal,
                          title: l10n.aiActionsMarkAs(
                            widget.statusLabel('approved').toLowerCase(),
                          ),
                          showChevron: false,
                        ),
                      if (payment != null)
                        FormRow(
                          key: const Key('aiActionsPaymentRow'),
                          icon: CupertinoIcons.money_dollar_circle,
                          title: payment.amount == null
                              ? l10n.aiActionsReceiveNoAmount
                              : l10n.aiActionsReceive(
                                  format.formatCurrency(payment.amount!),
                                ),
                          subtitle: _paymentDetail(l10n, payment),
                          onTap: () => _editPayment(payment),
                        ),
                      if (plan.status != null)
                        FormRow(
                          key: const Key('aiActionsStatusRow'),
                          icon: CupertinoIcons.checkmark_circle,
                          title: l10n.aiActionsMarkAs(
                            widget.statusLabel(plan.status!).toLowerCase(),
                          ),
                          showChevron: false,
                        ),
                    ],
                  ),
                  for (final note in notes)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.blockMargin + AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.blockMargin + AppSpacing.lg,
                        0,
                      ),
                      child: Text(
                        note,
                        style: AppTypography.label.copyWith(color: secondary),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.blockMargin,
              ),
              child: PrimaryButton(
                key: const Key('aiActionsConfirm'),
                label: l10n.confirm,
                onPressed: plan.canConfirm && chargeRead
                    ? () => Navigator.of(
                        context,
                      ).pop(AiActionsConfirmation(plan, edited: _edited))
                    : null,
              ),
            ),
            CupertinoButton(
              key: const Key('aiActionsDismiss'),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                l10n.notNow,
                style: AppTypography.callout.copyWith(
                  color: AppColors.accentText.resolveFrom(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
