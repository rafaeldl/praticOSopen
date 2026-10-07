import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/services/feature_gate_service.dart';
import 'package:praticos/services/paywall_launcher.dart';
import 'package:praticos/services/subscription_service.dart';

/// Dialog shown when the monthly photo limit is reached.
void showPhotoLimitDialog(BuildContext ctx, FeatureGateResult result) =>
    showFeatureLimitDialog(ctx, result);

/// Dialog shown when a plan limit (photos, form templates, users) is reached.
///
/// - Paid plans disabled ([SubscriptionService.paidPlansEnabled] false): only
///   the limit and an OK button, no plan wording.
/// - Owner/admin: "View plans" opens the paywall via [PaywallLauncher].
/// - Other members: "ask your company admin" and an OK button.
void showFeatureLimitDialog(BuildContext ctx, FeatureGateResult result) {
  final l10n = ctx.l10n;
  final paidPlans = SubscriptionService.paidPlansEnabled;
  final canPurchase = paidPlans && PaywallLauncher.currentUserCanPurchase;

  final String message;
  switch (result.featureType) {
    case FeatureType.photo:
      message = result.message ?? l10n.photoLimitReachedMessage;
    case FeatureType.formTemplate:
      message = l10n.featureLimitReached(l10n.formTemplates);
    case FeatureType.collaborator:
      message = l10n.featureLimitReached(l10n.collaborators);
  }

  final String? hint;
  if (!paidPlans) {
    hint = null;
  } else if (!canPurchase) {
    hint = l10n.askAdminToChangePlan;
  } else if (result.featureType == FeatureType.photo) {
    hint = l10n.photoLimitUpgradeHint;
  } else {
    hint = l10n.planLimitUpgradeHint;
  }

  showCupertinoDialog<void>(
    context: ctx,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(l10n.featureGateLimitModalTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          if (hint != null) ...[
            const SizedBox(height: 12),
            Text(
              hint,
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(ctx),
              ),
            ),
          ],
        ],
      ),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: !canPurchase,
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(canPurchase ? l10n.notNow : l10n.ok),
        ),
        if (canPurchase)
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(dialogContext);
              PaywallLauncher.showPaywall(ctx);
            },
            child: Text(l10n.viewPlans),
          ),
      ],
    ),
  );
}
