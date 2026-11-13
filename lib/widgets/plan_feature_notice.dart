import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/mobx/subscription_store.dart';
import 'package:praticos/models/subscription.dart';
import 'package:praticos/services/feature_gate_service.dart';
import 'package:praticos/services/paywall_launcher.dart';
import 'package:provider/provider.dart';

/// Name of a plan feature, the same words the web and the Plan screen use.
String planFeatureName(AppLocalizations l10n, PlanFeature feature) => switch (feature) {
      PlanFeature.nfse => l10n.planFeatureNfse,
      PlanFeature.brandedPdf => l10n.planFeatureBrandedPdf,
      PlanFeature.ownChecklists => l10n.planFeatureOwnChecklists,
      PlanFeature.charges => l10n.planFeatureCharges,
      PlanFeature.teamRoles => l10n.planFeatureTeamRoles,
      PlanFeature.perPersonAgenda => l10n.planFeaturePerPersonAgenda,
      PlanFeature.workStages => l10n.planFeatureWorkStages,
      PlanFeature.tvMode => l10n.planFeatureTvMode,
      PlanFeature.contracts => l10n.planFeatureContracts,
      PlanFeature.aiFinance => l10n.planFeatureAiFinance,
      PlanFeature.spreadsheetExport => l10n.planFeatureSpreadsheetExport,
      PlanFeature.bulkActions => l10n.planFeatureBulkActions,
      PlanFeature.mcp => l10n.planFeatureMcp,
      PlanFeature.api => l10n.planFeatureApi,
    };

/// Subscription of the current company, or null (Free) outside the app shell.
Subscription? _subscriptionOf(BuildContext context) {
  try {
    return Provider.of<SubscriptionStore>(context, listen: false).subscription;
  } on ProviderNotFoundException {
    return null;
  }
}

/// [FeatureGateService.checkFeature] for the current company.
PlanFeatureResult planFeatureOf(BuildContext context, PlanFeature feature) =>
    FeatureGateService.checkFeature(_subscriptionOf(context), feature);

/// Whether the current company's plan has [feature]; shows
/// [showPlanFeatureNotice] and returns false when it does not. Allowed while
/// the switch (config/paidPlans) is off.
bool ensurePlanFeature(BuildContext context, PlanFeature feature) {
  final result = planFeatureOf(context, feature);
  if (result.isAllowed) return true;
  showPlanFeatureNotice(context, feature, requiredPlan: result.requiredPlan);
  return false;
}

/// "Recurso do plano Pro": the feature is in a bigger plan. Owner and admin
/// get "Ver planos" (the paywall); everyone else is told to ask the owner.
/// The web shows the same words (PlanFeatureNotice.vue). Also the answer to
/// a 402 PLAN_FEATURE from the server.
Future<void> showPlanFeatureNotice(
  BuildContext context,
  PlanFeature feature, {
  SubscriptionPlan? requiredPlan,
}) {
  final l10n = context.l10n;
  final plan = (requiredPlan ?? FeatureGateService.requiredPlanFor(feature.name) ?? SubscriptionPlan.business)
      .displayName;
  final canPurchase = PaywallLauncher.currentUserCanPurchase;
  return showCupertinoDialog<void>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      key: const ValueKey('plan_feature_notice'),
      title: Text(l10n.planFeatureTitle(plan)),
      content: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '${planFeatureName(l10n, feature)}. '
          '${canPurchase ? l10n.planFeatureBody(plan) : l10n.planFeatureAskOwner(plan)}',
        ),
      ),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: !canPurchase,
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(canPurchase ? l10n.notNow : l10n.ok),
        ),
        if (canPurchase)
          CupertinoDialogAction(
            key: const ValueKey('plan_feature_view_plans'),
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(dialogContext);
              PaywallLauncher.showPaywall(context);
            },
            child: Text(l10n.viewPlans),
          ),
      ],
    ),
  );
}
