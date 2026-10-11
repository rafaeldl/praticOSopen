import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/subscription_store.dart';
import 'package:praticos/models/subscription.dart';
import 'package:praticos/screens/menu_navigation/more/more_page.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/paywall_launcher.dart';
import 'package:praticos/services/subscription_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// "Plano": current plan and its period, plus paywall, Customer Center and
/// restore purchases (owner/admin only, and only when the build has paid
/// plans). Others are told to ask the administrator.
class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  /// Renewal, end or courtesy date of the current plan; null on Free.
  String? _periodText(
      BuildContext context, Subscription subscription, DateTime now) {
    final expiresAt = subscription.expiresAt;
    final date =
        expiresAt == null ? null : FormatService().formatDate(expiresAt.toLocal());
    final l10n = context.l10n;
    switch (subscription.periodState(now)) {
      case SubscriptionPeriodState.free:
        return null;
      case SubscriptionPeriodState.paymentIssue:
        return l10n.planPaymentIssue;
      case SubscriptionPeriodState.courtesy:
        return date == null ? null : l10n.planCourtesyUntil(date);
      case SubscriptionPeriodState.renewsOn:
        return date == null ? null : l10n.planRenewsOn(date);
      case SubscriptionPeriodState.endsOn:
        return date == null ? null : l10n.planValidUntil(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subscription =
        context.watch<SubscriptionStore>().subscription ?? Subscription();
    final now = DateTime.now();
    final plan = subscription.effectivePlan(now);
    final canPurchase =
        SubscriptionService.paidPlansEnabled && PaywallLauncher.currentUserCanPurchase;
    final issue =
        subscription.periodState(now) == SubscriptionPeriodState.paymentIssue;

    return MorePage(
      title: l10n.planTitle,
      children: [
        MoreRows(rows: [
          AppListRow(
            key: const ValueKey('plan_current'),
            title: l10n.currentPlan,
            subtitle: _periodText(context, subscription, now),
            trailing: plan.displayName,
            titleStyle: AppTypography.body,
            // The payment issue is the only state that asks for action.
            trailingStyle: issue
                ? AppTypography.body
                    .copyWith(color: AppColors.danger.resolveFrom(context))
                : null,
          ),
          if (SubscriptionService.paidPlansEnabled && canPurchase) ...[
            AppListRow(
              key: const ValueKey('plan_paywall'),
              title: subscription.hasStoreSubscription(now)
                  ? l10n.changePlan
                  : l10n.viewPlans,
              onTap: () => PaywallLauncher.showPaywall(context),
            ),
            AppListRow(
              key: const ValueKey('plan_manage'),
              title: l10n.manageSubscription,
              onTap: () => PaywallLauncher.showCustomerCenter(context),
            ),
            AppListRow(
              key: const ValueKey('plan_restore'),
              title: l10n.restorePurchases,
              subtitle: l10n.restorePreviousPurchases,
              onTap: () => PaywallLauncher.restore(context),
            ),
          ],
        ]),
        if (SubscriptionService.paidPlansEnabled && !canPurchase)
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
