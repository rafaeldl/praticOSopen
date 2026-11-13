import 'package:cloud_firestore/cloud_firestore.dart';

/// Days before [PaidPlansConfig.limitsStartAt] the Free companies are told.
const int kFreeLimitsNoticeDays = 15;

/// `config/paidPlans`, the one document that turns the plans on. The same
/// rule as the server (firebase/functions/src/services/paid-plans-config.ts)
/// and the web (firebase/webapp/src/lib/paid-plans-config.ts); shared cases in
/// docs/web-app/contract-cases/paid-plans-config.json.
///
/// - `enabled`: limits and features for every company.
/// - `companyIds`: the plans on for these companies only while `enabled` is
///   off (the demo account of the App Review). The id lives only in
///   Firestore: the repository is public.
/// - `limitsStartAt`: the day the limits start for the Free companies that
///   already exist. Notice in the 15 days before; in the month from it the
///   month before does not take the grace of the orders away.
class PaidPlansConfig {
  const PaidPlansConfig({
    this.enabled = false,
    this.companyIds = const [],
    this.limitsStartAt,
  });

  /// Missing or unreadable: nothing on.
  static const off = PaidPlansConfig();

  final bool enabled;
  final List<String> companyIds;
  final DateTime? limitsStartAt;

  factory PaidPlansConfig.fromJson(Map<String, dynamic>? json) {
    final ids = json?['companyIds'];
    return PaidPlansConfig(
      enabled: json?['enabled'] == true,
      companyIds: ids is List
          ? ids.whereType<String>().where((id) => id.isNotEmpty).toList()
          : const [],
      limitsStartAt: _dateOf(json?['limitsStartAt']),
    );
  }

  static DateTime? _dateOf(Object? value) {
    if (value is String) return DateTime.tryParse(value)?.toUtc();
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    return null;
  }

  /// The plans are on for [companyId]: on for everyone, or listed.
  bool onFor(String? companyId) =>
      enabled || (companyId != null && companyId.isNotEmpty && companyIds.contains(companyId));

  /// Whether the month before counts for the month of grace of the orders:
  /// not in the month from [limitsStartAt] (decision of 2026-11-13).
  bool lastMonthCounts(DateTime now) {
    final start = limitsStartAt;
    return start == null || !now.toUtc().isBefore(oneMonthAfter(start));
  }

  /// Notice to an existing Free company at [now], or null outside the 15
  /// days before [limitsStartAt] or when the plan in force is not Free.
  FreeLimitsNotice? freeLimitsNotice({required bool isFree, required DateTime now}) {
    final start = limitsStartAt;
    if (start == null || !isFree) return null;
    final leftMs = start.millisecondsSinceEpoch - now.millisecondsSinceEpoch;
    if (leftMs <= 0 || leftMs > kFreeLimitsNoticeDays * Duration.millisecondsPerDay) {
      return null;
    }
    return FreeLimitsNotice(start, (leftMs / Duration.millisecondsPerDay).ceil());
  }
}

/// The same instant one calendar month later (UTC; Jan 31 rolls over like
/// the server's Date.UTC).
DateTime oneMonthAfter(DateTime date) {
  final d = date.toUtc();
  return DateTime.utc(d.year, d.month + 1, d.day, d.hour, d.minute, d.second, d.millisecond);
}

/// Início, before the limits start for the Free companies that exist.
class FreeLimitsNotice {
  const FreeLimitsNotice(this.startsAt, this.daysLeft);

  final DateTime startsAt;
  final int daysLeft;

  /// "Agora não" hides it for this date; a new date shows it again.
  String get dismissKey => 'free_limits_dismissed_${startsAt.toIso8601String()}';
}
