import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Firestore document with the minimum and recommended app versions.
///
/// See `docs/APP_MINIMUM_VERSION.md`. Every field is optional; an empty or
/// missing field turns that check off.
const appVersionConfigPath = 'config/appVersion';

/// Store pages of the app, opened by the update screen.
const appStoreUrl = 'https://apps.apple.com/app/id1534604555';
const playStoreUrl =
    'https://play.google.com/store/apps/details?id=br.com.rafsoft.praticos';

/// What the app must do with the installed version.
enum AppVersionStatus {
  /// Nothing to do.
  upToDate,

  /// Below the recommended version: a notice the user can close.
  updateRecommended,

  /// Below the minimum version: the app is blocked until updated.
  updateRequired,
}

/// Versions read from [appVersionConfigPath] for one platform.
@immutable
class AppVersionConfig {
  const AppVersionConfig({this.minimum, this.recommended});

  /// No check at all (missing document, unsupported platform, read error).
  static const disabled = AppVersionConfig();

  final String? minimum;
  final String? recommended;

  /// Picks the fields of [platform] from the document [data]:
  /// `iosMinimum`/`iosRecommended` or `androidMinimum`/`androidRecommended`.
  factory AppVersionConfig.fromMap(
    Map<String, dynamic>? data,
    TargetPlatform platform,
  ) {
    if (data == null) return disabled;
    final prefix = switch (platform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      _ => null,
    };
    if (prefix == null) return disabled;
    String? read(String key) {
      final value = data[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    return AppVersionConfig(
      minimum: read('${prefix}Minimum'),
      recommended: read('${prefix}Recommended'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppVersionConfig &&
      other.minimum == minimum &&
      other.recommended == recommended;

  @override
  int get hashCode => Object.hash(minimum, recommended);
}

/// Parses "1.109.0" (or "1.109.0+204", "1.109") into numbers, or null when it
/// is not a version.
List<int>? parseAppVersion(String? version) {
  if (version == null) return null;
  final core = version.trim().split('+').first.split('-').first;
  if (core.isEmpty) return null;
  final parts = core.split('.');
  final numbers = <int>[];
  for (final part in parts) {
    final number = int.tryParse(part);
    if (number == null || number < 0) return null;
    numbers.add(number);
  }
  return numbers;
}

/// Negative when [a] is older than [b], zero when equal, positive when newer.
/// Missing parts count as zero ("1.2" == "1.2.0").
int compareAppVersions(List<int> a, List<int> b) {
  final length = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < length; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x - y;
  }
  return 0;
}

/// Decides what to do with [installed] under [config]. An unreadable version
/// on either side never blocks: the check stays off rather than locking
/// people out by mistake.
AppVersionStatus evaluateAppVersion(String installed, AppVersionConfig config) {
  final current = parseAppVersion(installed);
  if (current == null) return AppVersionStatus.upToDate;

  bool below(String? target) {
    final parsed = parseAppVersion(target);
    if (parsed == null) return false;
    return compareAppVersions(current, parsed) < 0;
  }

  if (below(config.minimum)) return AppVersionStatus.updateRequired;
  if (below(config.recommended)) return AppVersionStatus.updateRecommended;
  return AppVersionStatus.upToDate;
}

/// Store page for [platform], or null where the app is not in a store.
String? storeUrlFor(TargetPlatform platform) => switch (platform) {
      TargetPlatform.iOS => appStoreUrl,
      TargetPlatform.android => playStoreUrl,
      _ => null,
    };

/// Reads [appVersionConfigPath]. Any failure (offline, rules) returns
/// [AppVersionConfig.disabled] so the app never blocks on a read error.
Future<AppVersionConfig> loadAppVersionConfig(TargetPlatform platform) async {
  try {
    final snapshot =
        await FirebaseFirestore.instance.doc(appVersionConfigPath).get();
    return AppVersionConfig.fromMap(snapshot.data(), platform);
  } catch (_) {
    return AppVersionConfig.disabled;
  }
}
