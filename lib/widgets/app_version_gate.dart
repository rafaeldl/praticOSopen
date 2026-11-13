import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/update_required_screen.dart';
import 'package:praticos/services/app_version_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Loads the version config of a platform. Tests replace it.
typedef AppVersionConfigLoader = Future<AppVersionConfig> Function(
  TargetPlatform platform,
);

/// Opens a store page. Tests replace it.
typedef StoreOpener = Future<void> Function(String url);

Future<String> _installedVersion() async =>
    (await PackageInfo.fromPlatform()).version;

Future<void> _openStore(String url) async {
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// SharedPreferences key with the recommended version whose notice the user
/// closed, so it does not come back until a newer one is recommended.
const recommendedDismissedKey = 'appVersionRecommendedDismissed';

/// Checks `config/appVersion` when the app opens and every time it comes back
/// to the foreground.
///
/// Below the minimum version it replaces the whole app with
/// [UpdateRequiredScreen]. Below the recommended version it shows a dialog
/// the user can close (once per recommended version). Read errors never
/// block. Sits in `MaterialApp.builder`, above the navigator, so pushed
/// routes are covered too.
class AppVersionGate extends StatefulWidget {
  const AppVersionGate({
    super.key,
    required this.child,
    required this.navigatorKey,
    this.loadConfig = loadAppVersionConfig,
    this.installedVersion = _installedVersion,
    this.openStore = _openStore,
    this.platform,
  });

  final Widget child;

  /// Navigator under this gate, used to show the recommended-version dialog.
  final GlobalKey<NavigatorState> navigatorKey;

  final AppVersionConfigLoader loadConfig;
  final Future<String> Function() installedVersion;
  final StoreOpener openStore;

  /// Defaults to [defaultTargetPlatform]; web is never checked.
  final TargetPlatform? platform;

  @override
  State<AppVersionGate> createState() => _AppVersionGateState();
}

class _AppVersionGateState extends State<AppVersionGate>
    with WidgetsBindingObserver {
  AppVersionStatus _status = AppVersionStatus.upToDate;
  bool _checking = false;
  bool _dialogOpen = false;

  TargetPlatform get _platform => widget.platform ?? defaultTargetPlatform;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (kIsWeb || _checking) return;
    _checking = true;
    try {
      final results = await Future.wait([
        widget.loadConfig(_platform),
        widget.installedVersion(),
      ]);
      final config = results[0] as AppVersionConfig;
      final installed = results[1] as String;
      final status = evaluateAppVersion(installed, config);
      if (!mounted) return;
      setState(() => _status = status);
      if (status == AppVersionStatus.updateRecommended) {
        await _maybeShowRecommended(config.recommended!);
      }
    } catch (_) {
      // Never block on a failed check.
    } finally {
      _checking = false;
    }
  }

  Future<void> _maybeShowRecommended(String recommended) async {
    if (_dialogOpen) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(recommendedDismissedKey) == recommended) return;
    final navContext = widget.navigatorKey.currentContext;
    if (navContext == null || !navContext.mounted) return;
    _dialogOpen = true;
    final update = await showCupertinoDialog<bool>(
      context: navContext,
      builder: (context) => CupertinoAlertDialog(
        key: const ValueKey('app_update_recommended_dialog'),
        title: Text(context.l10n.appUpdateRecommendedTitle),
        content: Text(context.l10n.appUpdateRecommendedMessage),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.appUpdateNotNow),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.appUpdateButton),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (update == true) {
      await _launchStore();
    } else {
      await prefs.setString(recommendedDismissedKey, recommended);
    }
  }

  Future<void> _launchStore() async {
    final url = storeUrlFor(_platform);
    if (url == null) return;
    try {
      await widget.openStore(url);
    } catch (_) {
      // The store could not open; the screen stays so the user can retry.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_status == AppVersionStatus.updateRequired) {
      return UpdateRequiredScreen(onUpdate: _launchStore);
    }
    return widget.child;
  }
}
