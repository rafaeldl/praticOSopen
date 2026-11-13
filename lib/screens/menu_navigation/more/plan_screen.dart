import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/subscription_store.dart';
import 'package:praticos/models/subscription.dart';
import 'package:praticos/screens/menu_navigation/more/more_page.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/next_step_block.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/models/permission.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/global.dart';
import 'package:praticos/services/feature_gate_service.dart';
import 'package:praticos/services/plan_overview.dart';
import 'package:praticos/widgets/plan_feature_notice.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/paywall_launcher.dart';
import 'package:praticos/services/subscription_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Fiscal emitters of the current company (the CNPJs on the nota).
Future<int> _countTaxIds() async {
  final id = Global.companyAggr?.id;
  if (id == null) return 0;
  final snap = await FirebaseFirestore.instance
      .collection('companies')
      .doc(id)
      .collection('fiscalEmitters')
      .count()
      .get();
  return snap.count ?? 0;
}

/// "Plano" (#725): current plan and its period, orders this month, people
/// and CNPJs against the plan, one notice (80%, 100%, the month of grace,
/// orders waiting, talk to us) and what the next plan adds. The web shows
/// the same (PlanView.vue), from the same rule (planOverview,
/// docs/web-app/contract-cases/plan-overview.json). No assistant counter.
/// Paywall, Customer Center and restore for owner/admin with paid plans.
class PlanScreen extends StatefulWidget {
  const PlanScreen({
    super.key,
    this.onOpenTeam,
    this.loadTaxIds,
    this.hasPermission,
  });

  /// Permission check for the people row: opens Equipe only with
  /// `manageUsers`. Defaults to the current user.
  final bool Function(PermissionType permission)? hasPermission;

  /// Destination of the people row (default: the Equipe route).
  final VoidCallback? onOpenTeam;

  /// CNPJs set up for the nota; defaults to Firestore (tests inject).
  final Future<int> Function()? loadTaxIds;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  bool _can(PermissionType permission) =>
      (widget.hasPermission ?? AuthorizationService.instance.hasPermission)(
        permission,
      );

  /// Null until read (or when it could not be read): the row stays hidden.
  int? _taxIds;

  @override
  void initState() {
    super.initState();
    (widget.loadTaxIds ?? _countTaxIds)().then((emitters) {
      if (mounted) setState(() => _taxIds = emitters);
    }).catchError((Object error) {
      debugPrint('PlanScreen: tax IDs not read: $error');
    });
  }

  /// "Starter · renova em 10/11/2026"; just the plan name on Free.
  String _header(BuildContext context, Subscription subscription,
      SubscriptionPlan plan, DateTime now) {
    final expiresAt = subscription.expiresAt;
    final date = expiresAt == null
        ? null
        : FormatService().formatDate(expiresAt.toLocal());
    final l10n = context.l10n;
    final name = plan.displayName;
    switch (subscription.periodState(now)) {
      case SubscriptionPeriodState.free:
        return name;
      case SubscriptionPeriodState.paymentIssue:
        return l10n.planHeaderPaymentIssue(name);
      case SubscriptionPeriodState.courtesy:
        return date == null ? name : l10n.planHeaderCourtesy(name, date);
      case SubscriptionPeriodState.renewsOn:
        return date == null ? name : l10n.planHeaderRenews(name, date);
      case SubscriptionPeriodState.endsOn:
        return date == null ? name : l10n.planHeaderValidUntil(name, date);
    }
  }

  String _count(int value) =>
      FormatService().formatDecimal(value, decimalDigits: 0);

  String _noticeText(BuildContext context, PlanOverview overview) {
    final l10n = context.l10n;
    final orders = overview.row(PlanOverviewResource.orders)!;
    final people = overview.row(PlanOverviewResource.people)!;
    return switch (overview.notice!) {
      PlanOverviewNotice.ordersNear =>
        l10n.planNoticeOrdersNear(_count(orders.used), _count(orders.limit)),
      PlanOverviewNotice.ordersAtLimit =>
        l10n.planNoticeOrdersAtLimit(_count(orders.limit)),
      PlanOverviewNotice.ordersGrace =>
        l10n.planNoticeOrdersGrace(_count(orders.limit)),
      PlanOverviewNotice.ordersBlocked =>
        l10n.planNoticeOrdersBlocked(_count(orders.limit)),
      PlanOverviewNotice.ordersContactUs =>
        l10n.planNoticeOrdersContactUs(_count(orders.limit)),
      PlanOverviewNotice.peopleAtLimit =>
        l10n.planLimitTeam(_count(people.used), _count(people.limit)),
      PlanOverviewNotice.peopleContactUs =>
        l10n.planNoticePeopleContactUs(_count(people.limit)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subscription =
        context.watch<SubscriptionStore>().subscription ?? Subscription();
    final now = DateTime.now();
    final paid = SubscriptionService.paidPlansEnabled;
    // Bought on the web: only the active plan, no purchase (docs/WEB_CHECKOUT.md).
    final fromWeb = subscription.hasWebSubscription(now);
    final canPurchase =
        paid && PaywallLauncher.currentUserCanPurchase && !fromWeb;
    final issue =
        subscription.periodState(now) == SubscriptionPeriodState.paymentIssue;
    final overview = planOverview(
      subscription,
      people: subscription.usage.usersActive,
      taxIds: _taxIds ?? 0,
      now: now,
      enforced: FeatureGateService.planLimitsEnforced,
    );
    final notice = paid ? overview.notice : null;
    final contactUs = notice == PlanOverviewNotice.ordersContactUs ||
        notice == PlanOverviewNotice.peopleContactUs;
    final rows = [
      for (final row in overview.rows)
        if (row.resource != PlanOverviewResource.taxIds || _taxIds != null) row,
    ];
    final next = overview.next;
    void openPaywall() => PaywallLauncher.showPaywall(context);

    return MorePage(
      title: l10n.planTitle,
      children: [
        Padding(
          // Lined up with the large title (16 from the edge).
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.blockMargin, 0, AppSpacing.pageMargin, AppSpacing.lg),
          child: Text(
            _header(context, subscription, overview.plan, now),
            key: const ValueKey('plan_current'),
            style: AppTypography.callout.copyWith(
              color: (issue ? AppColors.danger : AppColors.textSecondary)
                  .resolveFrom(context),
              fontWeight: issue ? FontWeight.w600 : null,
            ),
          ),
        ),
        if (notice != null)
          NextStepBlock(
            key: ValueKey('plan_notice_${notice.name}'),
            label: l10n.planLimitLabel,
            text: _noticeText(context, overview),
            button: canPurchase && !contactUs
                ? PrimaryButton(
                    key: const ValueKey('plan_paywall'),
                    label: l10n.viewPlans,
                    onPressed: openPaywall,
                  )
                : null,
          ),
        if (paid) ...[
          SectionLabel(l10n.planUsageSection),
          MoreRows(rows: [
            for (final row in rows)
              _UsageRow(
                key: ValueKey('plan_usage_${row.resource.name}'),
                row: row,
                title: switch (row.resource) {
                  PlanOverviewResource.orders => l10n.planUsageOrders,
                  PlanOverviewResource.people => l10n.planUsageTeam,
                  PlanOverviewResource.taxIds => l10n.planUsageTaxIds,
                },
                value: row.level == PlanOverviewLevel.unlimited
                    ? _count(row.used)
                    : l10n.planUsageOf(_count(row.used), _count(row.limit)),
                onTap: row.resource == PlanOverviewResource.people &&
                        _can(PermissionType.manageUsers)
                    ? widget.onOpenTeam ??
                        () => Navigator.pushNamed(context, '/collaborator_list')
                    : null,
              ),
          ]),
          if (next != null && next.features.isNotEmpty) ...[
            SectionLabel(l10n.planNextTitle(next.plan.displayName)),
            MoreRows(
              key: const ValueKey('plan_next'),
              rows: [
                for (final feature in next.features)
                  AppListRow(
                    key: ValueKey('plan_next_${feature.name}'),
                    title: planFeatureName(l10n, feature),
                    titleStyle: AppTypography.body,
                  ),
              ],
            ),
          ],
        ],
        if (canPurchase)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageMargin, AppSpacing.lg, AppSpacing.pageMargin, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (notice == null || contactUs)
                  TextLink(
                    key: const ValueKey('plan_paywall'),
                    label: l10n.viewPlans,
                    onPressed: openPaywall,
                  ),
                TextLink(
                  key: const ValueKey('plan_manage'),
                  label: l10n.manageSubscription,
                  onPressed: () => PaywallLauncher.showCustomerCenter(context),
                ),
                TextLink(
                  key: const ValueKey('plan_restore'),
                  label: l10n.restorePurchases,
                  onPressed: () => PaywallLauncher.restore(context),
                ),
              ],
            ),
          ),
        if (paid && !canPurchase && !fromWeb)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageMargin,
              AppSpacing.md,
              AppSpacing.pageMargin,
              0,
            ),
            child: Text(
              l10n.askAdminToChangePlan,
              style: AppTypography.label.copyWith(
                color: AppColors.textSecondary.resolveFrom(context),
              ),
            ),
          ),
      ],
    );
  }
}

/// "OS este mês · 8 de 10" with the level under it: red dot and text at or
/// over the limit, amber dot near it.
class _UsageRow extends StatelessWidget {
  const _UsageRow({
    super.key,
    required this.row,
    required this.title,
    required this.value,
    this.onTap,
  });

  final PlanOverviewRow row;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final level = row.level;
    final status = switch (level) {
      PlanOverviewLevel.atLimit || PlanOverviewLevel.over =>
        row.resource == PlanOverviewResource.people
            ? l10n.planUsageAtLimitInvites
            : l10n.planUsageAtLimit,
      PlanOverviewLevel.near => l10n.planUsageNearLimit,
      PlanOverviewLevel.unlimited => l10n.planUsageUnlimited,
      PlanOverviewLevel.ok => null,
    };
    if (status == null || level == PlanOverviewLevel.unlimited) {
      return AppListRow(
        title: title,
        subtitle: status,
        trailing: value,
        titleStyle: AppTypography.body,
        onTap: onTap,
      );
    }
    final atLimit = level != PlanOverviewLevel.near;
    final color = (atLimit ? AppColors.danger : AppColors.warning);
    return AppListRow(
      title: title,
      trailing: value,
      titleStyle: AppTypography.body,
      onTap: onTap,
      subtitleWidget: Row(
        children: [
          StatusDot(color: color),
          const SizedBox(width: AppSpacing.xs + 2),
          Flexible(
            child: Text(
              status,
              style: AppTypography.callout.copyWith(
                color: atLimit
                    ? color.resolveFrom(context)
                    : AppColors.textSecondary.resolveFrom(context),
                fontWeight: atLimit ? FontWeight.w600 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
