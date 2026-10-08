import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/utils/store_subscription.dart';

void main() {
  final l10n = AppLocalizationsPt();

  test('delete dialog warns about the store subscription when paid plans are on', () {
    final message = deleteAccountDialogMessage(l10n, paidPlansEnabled: true);

    expect(message, contains(l10n.deleteAccountWarning));
    expect(message, contains(l10n.deleteAccountStoreSubscriptionWarning));
  });

  test('delete dialog keeps the old text when paid plans are off', () {
    expect(
      deleteAccountDialogMessage(l10n, paidPlansEnabled: false),
      l10n.deleteAccountWarning,
    );
  });

  test('store subscription settings URL per platform', () {
    expect(storeSubscriptionsUrl(isIOS: true, isAndroid: false), appStoreSubscriptionsUrl);
    expect(storeSubscriptionsUrl(isIOS: false, isAndroid: true), playStoreSubscriptionsUrl);
    expect(storeSubscriptionsUrl(isIOS: false, isAndroid: false), isNull);
  });
}
