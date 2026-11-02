import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/notification_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Agora não" this many times and the checklist offer stops: a workshop
/// that does not use it should not answer it on every order.
const kChecklistOfferLimit = 3;

const _declinedKey = 'checklist_offer_declined';

/// The check-in checklist only makes sense for a vehicle that came to the
/// shop, on an order that exists and that the user may add a checklist to.
bool shouldOfferChecklist({
  required Order order,
  required String? segmentId,
  required bool canManageForms,
  required int declined,
}) {
  return segmentId == 'automotive' &&
      order.id != null &&
      order.contract == null &&
      order.effectiveDevices.isNotEmpty &&
      canManageForms &&
      declined < kChecklistOfferLimit;
}

/// Asks "Fazer o checklist de entrada?". Resolves with `true` on yes.
Future<bool> askChecklist(BuildContext context, String device) async {
  final l10n = context.l10n;
  final yes = await showCupertinoModalPopup<bool>(
    context: context,
    builder: (popupContext) => CupertinoActionSheet(
      title: Text(l10n.checklistOfferTitle),
      message: Text(l10n.checklistOfferMessage(device)),
      actions: [
        CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(popupContext, true),
          child: Text(l10n.checklistOfferAction),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(popupContext, false),
        child: Text(l10n.notNow),
      ),
    ),
  );
  return yes == true;
}

/// Offers the checklist for the order just saved. Resolves with `true` when
/// it took the user to the order.
Future<bool> offerChecklist(BuildContext context, Order? order) async {
  if (order == null) return false;
  final prefs = await SharedPreferences.getInstance();
  final declined = prefs.getInt(_declinedKey) ?? 0;
  if (!context.mounted) return false;
  final segmentId = context.read<SegmentConfigProvider>().segmentId;
  final canManage = AuthorizationService.instance.canManageOrderForms(order);
  if (!shouldOfferChecklist(
    order: order,
    segmentId: segmentId,
    canManageForms: canManage,
    declined: declined,
  )) {
    return false;
  }
  final device = order.effectiveDevices.first.name ?? '';
  final yes = await askChecklist(context, device);
  if (!yes) {
    await prefs.setInt(_declinedKey, declined + 1);
    return false;
  }
  await prefs.remove(_declinedKey);
  if (!context.mounted) return false;
  unawaited(
    Navigator.of(context, rootNavigator: true).pushNamed(
      '/order',
      arguments: {'order': Order()..id = order.id, 'addChecklist': true},
    ),
  );
  return true;
}

/// Explains the notifications right before the iPhone's alert, once. One
/// button and no way out, as the HIG asks of a screen before an alert: the
/// choice belongs to the alert. Nothing shows when it was already answered.
Future<void> askNotificationsOnce(BuildContext context) async {
  NotificationStore store;
  try {
    store = Provider.of<NotificationStore>(context, listen: false);
  } catch (_) {
    return;
  }
  if (!store.permissionUndecided) return;
  final l10n = context.l10n;
  await showCupertinoDialog<void>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(l10n.notificationPromptTitle),
      content: Text(l10n.notificationPromptMessage),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.continueAction),
        ),
      ],
    ),
  );
  await store.requestPermissionAgain();
}

/// After "Nova OS" closes: the checklist, when it applies; then the
/// notifications, the first time. Taking the checklist leaves the
/// notifications for the next order: one interruption at a time.
Future<void> runNewOrderOffers(BuildContext context, Order? order) async {
  if (await offerChecklist(context, order)) return;
  if (context.mounted) await askNotificationsOnce(context);
}
