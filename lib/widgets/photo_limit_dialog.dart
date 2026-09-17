import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/services/feature_gate_service.dart';
import 'package:praticos/services/subscription_service.dart';

/// Dialog shown when the monthly photo limit is reached.
///
/// On iOS there is no purchase UI (App Review guidelines 3.1.1 / 3.1.3(f)), so
/// the dialog carries no plan or upgrade wording and no call to action: only
/// the limit information and an OK button. See [SubscriptionService.purchaseUiEnabled].
void showPhotoLimitDialog(BuildContext ctx, FeatureGateResult result) {
  final purchaseUiEnabled = SubscriptionService.purchaseUiEnabled;

  showCupertinoDialog(
    context: ctx,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(ctx.l10n.featureGateLimitModalTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(result.message ?? ctx.l10n.photoLimitReachedMessage),
          if (purchaseUiEnabled) ...[
            const SizedBox(height: 12),
            Text(
              ctx.l10n.photoLimitUpgradeHint,
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
          isDefaultAction: !purchaseUiEnabled,
          child: Text(purchaseUiEnabled ? ctx.l10n.notNow : ctx.l10n.ok),
          onPressed: () => Navigator.pop(dialogContext),
        ),
        if (purchaseUiEnabled)
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(ctx.l10n.viewPlans),
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pushNamed(ctx, '/subscription/plans');
            },
          ),
      ],
    ),
  );
}
