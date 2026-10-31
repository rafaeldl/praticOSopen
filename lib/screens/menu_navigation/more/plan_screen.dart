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
import 'package:praticos/services/ai_order_assist_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/paywall_launcher.dart';
import 'package:praticos/services/subscription_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Resource counted against the plan limits.
enum PlanResource { ai, team, photos, checklists }

/// How close one resource is to its limit.
enum PlanUsageLevel { unlimited, ok, near, atLimit }

/// Usage of one [resource]: [used] of [limit] (-1 = unlimited).
class PlanUsage {
  const PlanUsage(this.resource, this.used, this.limit);

  final PlanResource resource;
  final int used;
  final int limit;

  /// "Quase no limite" from 80% on.
  PlanUsageLevel get level {
    if (limit < 0) return PlanUsageLevel.unlimited;
    if (used >= limit) return PlanUsageLevel.atLimit;
    if (limit > 0 && used / limit >= 0.8) return PlanUsageLevel.near;
    return PlanUsageLevel.ok;
  }

  /// Usage of the resources, in the prototype order. The assistant comes
  /// first, when [ai] says it is on: it is what the month's limit is about.
  static List<PlanUsage> of(
    Subscription subscription,
    DateTime now, {
    AiStatus? ai,
  }) {
    final limits = subscription.effectiveLimits(now);
    final usage = subscription.usage;
    final aiUsed = ai?.used;
    final aiLimit = ai?.limit;
    return [
      if (ai?.enabled == true && aiUsed != null && aiLimit != null)
        PlanUsage(PlanResource.ai, aiUsed, aiLimit),
      PlanUsage(PlanResource.team, usage.usersActive, limits.users),
      PlanUsage(PlanResource.photos, usage.photosThisMonth, limits.photosPerMonth),
      PlanUsage(
          PlanResource.checklists, usage.formTemplatesActive, limits.formTemplates),
    ];
  }
}

/// "Plano": current plan and its period, what the company is using against
/// the limits, and the paywall, Customer Center and restore purchases
/// (owner/admin only, and only when the build has paid plans). When a limit
/// is reached, a block says so and holds the only blue button ("Ver planos").
class PlanScreen extends StatefulWidget {
  const PlanScreen({
    super.key,
    this.onOpenTeam,
    this.onOpenChecklists,
    this.loadAiStatus,
  });

  /// Destinations of the usage rows (defaults: Equipe and Checklists routes).
  final VoidCallback? onOpenTeam;
  final VoidCallback? onOpenChecklists;

  /// Assistant use of the month; defaults to the server (tests inject).
  final Future<AiStatus> Function()? loadAiStatus;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  AiStatus? _ai;

  @override
  void initState() {
    super.initState();
    (widget.loadAiStatus ?? () => AiOrderAssistService().status())().then((ai) {
      if (mounted) setState(() => _ai = ai);
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

  String _limitSentence(BuildContext context, PlanUsage usage) {
    final l10n = context.l10n;
    final used = _count(usage.used);
    final limit = _count(usage.limit);
    return switch (usage.resource) {
      PlanResource.ai => l10n.planLimitAi(used, limit),
      PlanResource.team => l10n.planLimitTeam(used, limit),
      PlanResource.photos => l10n.planLimitPhotos(used, limit),
      PlanResource.checklists => l10n.planLimitChecklists(used, limit),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subscription =
        context.watch<SubscriptionStore>().subscription ?? Subscription();
    final now = DateTime.now();
    final plan = subscription.effectivePlan(now);
    final paid = SubscriptionService.paidPlansEnabled;
    final canPurchase = paid && PaywallLauncher.currentUserCanPurchase;
    final issue =
        subscription.periodState(now) == SubscriptionPeriodState.paymentIssue;
    final usages = PlanUsage.of(subscription, now, ai: _ai);
    final reached = paid
        ? usages.where((u) => u.level == PlanUsageLevel.atLimit).firstOrNull
        : null;
    // Prototype: "Ver planos" also for whoever already pays.
    final paywallLabel = l10n.viewPlans;
    void openPaywall() => PaywallLauncher.showPaywall(context);

    return MorePage(
      title: l10n.planTitle,
      children: [
        Padding(
          // Lined up with the large title (16 from the edge).
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.blockMargin, 0, AppSpacing.pageMargin, AppSpacing.lg),
          child: Text(
            _header(context, subscription, plan, now),
            key: const ValueKey('plan_current'),
            style: AppTypography.callout.copyWith(
              color: (issue ? AppColors.danger : AppColors.textSecondary)
                  .resolveFrom(context),
              fontWeight: issue ? FontWeight.w600 : null,
            ),
          ),
        ),
        if (reached != null)
          NextStepBlock(
            key: const ValueKey('plan_limit_block'),
            label: l10n.planLimitLabel,
            text: _limitSentence(context, reached),
            button: canPurchase
                ? PrimaryButton(
                    key: const ValueKey('plan_paywall'),
                    label: paywallLabel,
                    onPressed: openPaywall,
                  )
                : null,
          ),
        if (paid) ...[
          SectionLabel(l10n.planUsageSection),
          MoreRows(rows: [
            for (final usage in usages)
              _UsageRow(
                key: ValueKey('plan_usage_${usage.resource.name}'),
                usage: usage,
                title: switch (usage.resource) {
                  PlanResource.ai => l10n.planUsageAi,
                  PlanResource.team => l10n.planUsageTeam,
                  PlanResource.photos => l10n.planUsagePhotos,
                  PlanResource.checklists => l10n.planUsageChecklists,
                },
                value: usage.level == PlanUsageLevel.unlimited
                    ? _count(usage.used)
                    : l10n.planUsageOf(_count(usage.used), _count(usage.limit)),
                onTap: switch (usage.resource) {
                  PlanResource.ai => null,
                  PlanResource.team => widget.onOpenTeam ??
                      () => Navigator.pushNamed(context, '/collaborator_list'),
                  PlanResource.photos => null,
                  PlanResource.checklists => widget.onOpenChecklists ??
                      () => Navigator.pushNamed(context, '/form_template_list'),
                },
              ),
          ]),
        ],
        if (canPurchase)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageMargin, AppSpacing.lg, AppSpacing.pageMargin, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (reached == null)
                  TextLink(
                    key: const ValueKey('plan_paywall'),
                    label: paywallLabel,
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
        if (paid && !canPurchase)
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

/// "Pessoas na equipe · 3 de 3" with the level under it: red dot and text at
/// the limit, amber dot near it.
class _UsageRow extends StatelessWidget {
  const _UsageRow({
    super.key,
    required this.usage,
    required this.title,
    required this.value,
    this.onTap,
  });

  final PlanUsage usage;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final level = usage.level;
    final status = switch (level) {
      PlanUsageLevel.atLimit => usage.resource == PlanResource.team
          ? l10n.planUsageAtLimitInvites
          : l10n.planUsageAtLimit,
      PlanUsageLevel.near => l10n.planUsageNearLimit,
      PlanUsageLevel.unlimited => l10n.planUsageUnlimited,
      PlanUsageLevel.ok => null,
    };
    if (status == null || level == PlanUsageLevel.unlimited) {
      return AppListRow(
        title: title,
        subtitle: status,
        trailing: value,
        titleStyle: AppTypography.body,
        onTap: onTap,
      );
    }
    final atLimit = level == PlanUsageLevel.atLimit;
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
