import 'package:praticos/models/subscription.dart';

/// Days before the end of the courtesy on which the warning starts, and
/// when it comes back after "Agora não".
const int kCourtesyNoticeDays = 15;
const int kCourtesyLastNoticeDays = 3;

/// End of the launch courtesy, as Início warns about it. The date is the
/// subscription's `expiresAt`, so moving it on the server needs no release.
class CourtesyNotice {
  const CourtesyNotice(this.daysLeft, this.endsAt);

  final int daysLeft;
  final DateTime endsAt;

  bool get isLast => daysLeft <= kCourtesyLastNoticeDays;

  /// Identifies this warning: a new date, or the last days, show it again.
  String get dismissKey =>
      'courtesy_dismissed_${endsAt.toUtc().toIso8601String()}_${isLast ? 'last' : 'first'}';

  /// The warning due at [now], or null outside the window.
  static CourtesyNotice? of(Subscription? subscription, DateTime now) {
    final endsAt = subscription?.expiresAt;
    if (endsAt == null || subscription?.source != SubscriptionSource.grace) {
      return null;
    }
    if (!endsAt.isAfter(now)) return null;
    final daysLeft = (endsAt.difference(now).inMinutes / (24 * 60)).ceil();
    if (daysLeft > kCourtesyNoticeDays) return null;
    return CourtesyNotice(daysLeft < 1 ? 1 : daysLeft, endsAt);
  }
}

/// Smallest paid plan that covers what the company uses this month, or null
/// when Free already does.
SubscriptionPlan? recommendedPlan(SubscriptionUsage usage, int aiUsed) {
  bool fits(int used, int limit) => limit == -1 || used <= limit;
  bool covers(SubscriptionPlan plan) {
    final limits = SubscriptionLimits.forPlan(plan);
    return fits(usage.usersActive, limits.users) &&
        fits(usage.photosThisMonth, limits.photosPerMonth) &&
        fits(usage.formTemplatesActive, limits.formTemplates) &&
        fits(aiUsed, kAiRequestsPerMonth[plan] ?? 0);
  }

  if (covers(SubscriptionPlan.free)) return null;
  for (final plan in const [SubscriptionPlan.starter, SubscriptionPlan.pro]) {
    if (covers(plan)) return plan;
  }
  return SubscriptionPlan.business;
}
