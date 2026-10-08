import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:praticos/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

const appStoreSubscriptionsUrl = 'https://apps.apple.com/account/subscriptions';
const playStoreSubscriptionsUrl = 'https://play.google.com/store/account/subscriptions';

/// Text of the delete-account confirmation. With paid plans it also says
/// that deleting the account does not cancel the store subscription.
String deleteAccountDialogMessage(
  AppLocalizations l10n, {
  required bool paidPlansEnabled,
}) {
  if (!paidPlansEnabled) return l10n.deleteAccountWarning;
  return '${l10n.deleteAccountWarning}\n\n${l10n.deleteAccountStoreSubscriptionWarning}';
}

/// Store page where the user manages subscriptions, or null.
String? storeSubscriptionsUrl({required bool isIOS, required bool isAndroid}) {
  if (isIOS) return appStoreSubscriptionsUrl;
  if (isAndroid) return playStoreSubscriptionsUrl;
  return null;
}

/// Opens the store subscription settings of this device.
Future<void> openStoreSubscriptionSettings() async {
  if (kIsWeb) return;
  final url = storeSubscriptionsUrl(
    isIOS: Platform.isIOS,
    isAndroid: Platform.isAndroid,
  );
  if (url == null) return;
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
