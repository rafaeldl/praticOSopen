import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/services/analytics_service.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/subscription_service.dart';

/// Single entry point for buying, managing and restoring plans.
///
/// Uses the RevenueCat paywall and Customer Center. Only the company owner
/// or an admin can buy; everyone else is told to ask the admin.
class PaywallLauncher {
  PaywallLauncher._();

  /// Role of the signed-in user in the current company ('admin',
  /// 'technician', ...). Tests replace it to avoid Firebase.
  @visibleForTesting
  static String? Function() roleResolver = _currentRole;

  static String? _currentRole() =>
      AuthorizationService.instance.currentUserRole?.name;

  /// Whether [role] may buy or manage the company plan.
  static bool canPurchase(String? role) => role == 'owner' || role == 'admin';

  /// [canPurchase] for the signed-in user.
  static bool get currentUserCanPurchase => canPurchase(roleResolver());

  static bool get _sdkReady =>
      SubscriptionService.paidPlansEnabled &&
      SubscriptionService.instance.isInitialized;

  /// Opens the RevenueCat paywall (offering `default`).
  static Future<void> showPaywall(BuildContext context) async {
    if (!currentUserCanPurchase) return showAskAdmin(context);
    if (!_sdkReady) return _showUnavailable(context);

    AnalyticsService.instance.logPlansScreenViewed(source: 'paywall');
    try {
      await SubscriptionService.instance.presentPaywall();
      // The webhook updates companies/{id}.subscription; the
      // SubscriptionStore listener refreshes the UI.
    } catch (e) {
      debugPrint('PaywallLauncher: paywall error: $e');
      if (context.mounted) await _showUnavailable(context);
    }
  }

  /// Opens the RevenueCat Customer Center (manage, cancel, change plan).
  static Future<void> showCustomerCenter(BuildContext context) async {
    if (!currentUserCanPurchase) return showAskAdmin(context);
    if (!_sdkReady) return _showUnavailable(context);

    try {
      await SubscriptionService.instance.presentCustomerCenter();
    } catch (e) {
      debugPrint('PaywallLauncher: customer center error: $e');
      if (context.mounted) await _showUnavailable(context);
    }
  }

  /// Restores the store purchases into the current company and shows the
  /// real result. Returns true when a paid plan was found.
  static Future<bool> restore(BuildContext context) async {
    if (!currentUserCanPurchase) {
      await showAskAdmin(context);
      return false;
    }
    if (!_sdkReady) {
      await _showUnavailable(context);
      return false;
    }

    final l10n = context.l10n;
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CupertinoActivityIndicator(radius: 20)),
    );

    var restored = false;
    String title;
    String message;
    try {
      final service = SubscriptionService.instance;
      final info = await service.restorePurchases();
      restored = service.hasActivePlan(info);
      title = restored ? l10n.success : l10n.restorePurchases;
      message = restored ? l10n.restorePurchasesSuccess : l10n.restorePurchasesNothingFound;
    } catch (e) {
      debugPrint('PaywallLauncher: restore error: $e');
      title = l10n.error;
      message = l10n.restorePurchasesError;
    }

    if (!context.mounted) return restored;
    Navigator.of(context, rootNavigator: true).pop(); // loading
    await _showMessage(context, title: title, message: message);
    return restored;
  }

  /// "Ask your company admin to change the plan."
  static Future<void> showAskAdmin(BuildContext context) => _showMessage(
        context,
        title: context.l10n.askAdminToChangePlanTitle,
        message: context.l10n.askAdminToChangePlan,
      );

  static Future<void> _showUnavailable(BuildContext context) => _showMessage(
        context,
        title: context.l10n.subscription,
        message: context.l10n.subscriptionUnavailable,
      );

  static Future<void> _showMessage(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.ok),
          ),
        ],
      ),
    );
  }
}
