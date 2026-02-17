import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'whatsapp_setup_banner_store.g.dart';

class WhatsAppSetupBannerStore = _WhatsAppSetupBannerStore
    with _$WhatsAppSetupBannerStore;

abstract class _WhatsAppSetupBannerStore with Store {
  static const String _dismissedAtKey = 'whatsapp_banner_dismissed_at';
  static const int _reappearDays = 7;

  @observable
  bool isVisible = false;

  @observable
  bool isWhatsAppLinked = false;

  /// Check if banner should be visible based on dismiss date and link status
  @action
  Future<void> checkVisibility() async {
    if (isWhatsAppLinked) {
      isVisible = false;
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final dismissedAtMs = prefs.getInt(_dismissedAtKey);

    if (dismissedAtMs == null) {
      // Never dismissed, show banner
      isVisible = true;
      return;
    }

    final dismissedAt = DateTime.fromMillisecondsSinceEpoch(dismissedAtMs);
    final daysSinceDismiss = DateTime.now().difference(dismissedAt).inDays;

    isVisible = daysSinceDismiss >= _reappearDays;
  }

  /// Dismiss the banner and persist the dismiss date
  @action
  Future<void> dismiss() async {
    isVisible = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        _dismissedAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Update link status from WhatsAppLinkStore
  @action
  void updateLinkStatus(bool linked) {
    isWhatsAppLinked = linked;
    if (linked) {
      isVisible = false;
    }
  }
}
