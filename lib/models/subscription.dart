import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:json_annotation/json_annotation.dart';

import 'plan_table.dart';

export 'plan_table.dart' show PlanRow, kPlanTables, kPlanTablesInForce, kPlanTableCurrentVersion, kPlanTableLegacyVersion;

part 'subscription.g.dart';

/// Plans available in PraticOS.
enum SubscriptionPlan {
  @JsonValue('free')
  free,
  @JsonValue('starter')
  starter,
  @JsonValue('pro')
  pro,
  @JsonValue('business')
  business,
}

/// Product names of the plans. They are brand names, not translated.
extension SubscriptionPlanName on SubscriptionPlan {
  String get displayName {
    switch (this) {
      case SubscriptionPlan.free:
        return 'Free';
      case SubscriptionPlan.starter:
        return 'Starter';
      case SubscriptionPlan.pro:
        return 'Pro';
      case SubscriptionPlan.business:
        return 'Business';
    }
  }
}

/// The current plan table row (docs/plans/plans.json) for [plan].
PlanRow currentPlanRow(SubscriptionPlan plan) =>
    kPlanTables[kPlanTableCurrentVersion]![plan]!;

/// Assistant requests per month by plan (docs/plans/plans.json, same as the server).
final Map<SubscriptionPlan, int> kAiRequestsPerMonth = {
  for (final plan in SubscriptionPlan.values) plan: currentPlanRow(plan).aiPerMonth,
};

/// Subscription status. Only the server (RevenueCat webhook) writes it.
enum SubscriptionStatus {
  @JsonValue('active')
  active,
  @JsonValue('cancelled')
  cancelled,
  @JsonValue('past_due')
  pastDue,
  @JsonValue('expired')
  expired,
}

/// Where the current plan comes from.
enum SubscriptionSource {
  @JsonValue('store')
  store,
  @JsonValue('grace')
  grace,
}

/// What the current plan row shows next to the plan name.
enum SubscriptionPeriodState {
  /// Free plan: no date.
  free,

  /// Launch grace period: "courtesy until {date}".
  courtesy,

  /// Store subscription with auto-renew on: "renews on {date}".
  renewsOn,

  /// Auto-renew off (or no store): "active until {date}".
  endsOn,

  /// Store reported a billing issue.
  paymentIssue,
}

/// Store that bills the subscription.
enum BillingStore {
  @JsonValue('app_store')
  appStore,
  @JsonValue('play_store')
  playStore,
}

/// Firestore paths of the usage counters. The app writes only these fields
/// of `subscription`; plan, status, limits and dates belong to the server.
class SubscriptionUsagePaths {
  SubscriptionUsagePaths._();

  static const collection = 'companies';
  static const photosThisMonth = 'subscription.usage.photosThisMonth';
  static const formTemplatesActive = 'subscription.usage.formTemplatesActive';
  static const usersActive = 'subscription.usage.usersActive';
}

/// Accepts ISO strings (server), Firestore Timestamps and epoch millis.
DateTime? _dateFromJson(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  return null;
}

String? _dateToJson(DateTime? value) => value?.toUtc().toIso8601String();

/// Month in São Paulo (UTC-3, no daylight saving since 2019), "YYYY-MM":
/// the month of the orders counter (same as the server).
String orderMonthKey(DateTime now) {
  final local = now.toUtc().subtract(const Duration(hours: 3));
  return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}';
}

/// The month before a "YYYY-MM" key.
String previousMonthKey(String key) {
  final parts = key.split('-').map(int.parse).toList();
  final year = parts[0], month = parts[1];
  return month == 1 ? '${year - 1}-12' : '$year-${(month - 1).toString().padLeft(2, '0')}';
}

/// The more generous of two limits (-1 is no limit).
int moreGenerousLimit(int a, int b) => a == -1 || b == -1 ? -1 : (a > b ? a : b);

/// Usage counters of the current period.
@JsonSerializable(includeIfNull: false)
class SubscriptionUsage {
  int photosThisMonth;
  int formTemplatesActive;
  int usersActive;

  @JsonKey(fromJson: _dateFromJson, toJson: _dateToJson)
  DateTime? usageResetAt;

  /// Orders created in [ordersMonth] (São Paulo calendar), sample orders
  /// left out. Only the server writes the three order fields.
  int? ordersThisMonth;

  /// Month of [ordersThisMonth], "YYYY-MM".
  String? ordersMonth;

  /// Orders of the month before [ordersMonth].
  int? ordersLastMonth;

  SubscriptionUsage({
    this.photosThisMonth = 0,
    this.formTemplatesActive = 0,
    this.usersActive = 0,
    this.usageResetAt,
    this.ordersThisMonth,
    this.ordersMonth,
    this.ordersLastMonth,
  });

  /// This month's and last month's orders at [now], turning the month when
  /// [ordersMonth] is behind (same as the server's ordersUsage).
  ({int thisMonth, int lastMonth}) ordersAt(DateTime now) {
    final key = orderMonthKey(now);
    int count(int? value) => value != null && value > 0 ? value : 0;
    if (ordersMonth == key) return (thisMonth: count(ordersThisMonth), lastMonth: count(ordersLastMonth));
    if (ordersMonth == previousMonthKey(key)) return (thisMonth: 0, lastMonth: count(ordersThisMonth));
    return (thisMonth: 0, lastMonth: 0);
  }

  /// Reads the server keys and falls back to the legacy client keys
  /// (`formTemplates`, `collaborators`).
  factory SubscriptionUsage.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionUsageFromJson(<String, dynamic>{
        ...json,
        'formTemplatesActive': json['formTemplatesActive'] ?? json['formTemplates'],
        'usersActive': json['usersActive'] ?? json['collaborators'],
      });

  Map<String, dynamic> toJson() => _$SubscriptionUsageToJson(this);
}

/// Plan limits. -1 means unlimited.
@JsonSerializable(createFactory: false)
class SubscriptionLimits {
  /// Orders created per month (soft limit, see FeatureGateService.canCreateOrder).
  final int ordersPerMonth;

  /// Photos per month.
  final int photosPerMonth;

  /// Own active form templates (copies of the segment's do not count).
  final int formTemplates;

  /// Users in the company (members + pending invites).
  final int users;

  /// Show the watermark on the work order PDF.
  final bool pdfWatermark;

  const SubscriptionLimits({
    required this.ordersPerMonth,
    required this.photosPerMonth,
    required this.formTemplates,
    required this.users,
    required this.pdfWatermark,
  });

  /// The limits of a row of the plan table.
  factory SubscriptionLimits.ofRow(PlanRow row) => SubscriptionLimits(
        ordersPerMonth: row.ordersPerMonth,
        photosPerMonth: row.photosPerMonth,
        formTemplates: row.formTemplates,
        users: row.users,
        pdfWatermark: row.pdfWatermark,
      );

  /// Stored limits as written; a missing field takes the Free default (see
  /// [mergedOver] for how they meet the table). Reads `users` and falls back
  /// to the legacy client key `collaborators`.
  factory SubscriptionLimits.fromJson(Map<String, dynamic> json) {
    final free = forPlan(SubscriptionPlan.free);
    int intOr(Object? value, int fallback) => value is num ? value.toInt() : fallback;
    final watermark = json['pdfWatermark'];
    return SubscriptionLimits(
      ordersPerMonth: intOr(json['ordersPerMonth'], free.ordersPerMonth),
      photosPerMonth: intOr(json['photosPerMonth'], free.photosPerMonth),
      formTemplates: intOr(json['formTemplates'], free.formTemplates),
      users: intOr(json['users'] ?? json['collaborators'], free.users),
      pdfWatermark: watermark is bool ? watermark : free.pdfWatermark,
    );
  }

  /// Stored limits ([json]) over a table [row]: each number takes the more
  /// generous of the two, so a stricter table never takes anything from a
  /// subscriber; a missing field is the table's. No watermark wins.
  static SubscriptionLimits mergedOver(SubscriptionLimits row, Map<String, dynamic> json) {
    int pick(Object? stored, int table) => stored is num ? moreGenerousLimit(stored.toInt(), table) : table;
    return SubscriptionLimits(
      ordersPerMonth: pick(json['ordersPerMonth'], row.ordersPerMonth),
      photosPerMonth: pick(json['photosPerMonth'], row.photosPerMonth),
      formTemplates: pick(json['formTemplates'], row.formTemplates),
      users: pick(json['users'] ?? json['collaborators'], row.users),
      pdfWatermark: row.pdfWatermark && json['pdfWatermark'] != false,
    );
  }

  Map<String, dynamic> toJson() => _$SubscriptionLimitsToJson(this);

  /// Default limits per plan, from the current plan table (same as the server).
  static final Map<SubscriptionPlan, SubscriptionLimits> defaults = {
    for (final plan in SubscriptionPlan.values) plan: SubscriptionLimits.ofRow(currentPlanRow(plan)),
  };

  static SubscriptionLimits forPlan(SubscriptionPlan plan) => defaults[plan]!;
}

/// `companies/{companyId}.subscription`. Written by the server; the app only
/// increments the counters in [SubscriptionUsagePaths].
@JsonSerializable(explicitToJson: true)
class Subscription {
  @JsonKey(unknownEnumValue: SubscriptionPlan.free)
  SubscriptionPlan plan;

  @JsonKey(unknownEnumValue: SubscriptionStatus.active)
  SubscriptionStatus status;

  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  SubscriptionSource? source;

  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  BillingStore? store;

  @JsonKey(fromJson: _dateFromJson, toJson: _dateToJson)
  DateTime? expiresAt;

  SubscriptionLimits? limits;

  SubscriptionUsage usage;

  String? rcSubscriberId;

  /// Version of docs/plans/plans.json this subscription follows; null = the
  /// current one. Extension point for the current subscribers (#726).
  String? tableVersion;

  @JsonKey(fromJson: _dateFromJson, toJson: _dateToJson)
  DateTime? updatedAt;

  /// `limits` as stored (only the fields it has), for [effectiveLimits].
  Map<String, dynamic>? _storedLimits;

  Subscription({
    this.plan = SubscriptionPlan.free,
    this.status = SubscriptionStatus.active,
    this.source,
    this.store,
    this.expiresAt,
    this.limits,
    SubscriptionUsage? usage,
    this.rcSubscriberId,
    this.tableVersion,
    this.updatedAt,
  }) : usage = usage ?? SubscriptionUsage();

  factory Subscription.fromJson(Map<String, dynamic> json) {
    final subscription = _$SubscriptionFromJson(json);
    final stored = json['limits'];
    subscription._storedLimits = stored is Map ? stored.cast<String, dynamic>() : null;
    return subscription;
  }

  Map<String, dynamic> toJson() => _$SubscriptionToJson(this);

  /// Plan in force at [now]: [plan] while [expiresAt] is null or in the
  /// future, Free afterwards. The app does not wait for the daily job.
  SubscriptionPlan effectivePlan(DateTime now) {
    final expires = expiresAt;
    if (expires == null || expires.isAfter(now)) return plan;
    return SubscriptionPlan.free;
  }

  /// How the current plan's period is shown to the user at [now].
  SubscriptionPeriodState periodState(DateTime now) {
    if (effectivePlan(now) == SubscriptionPlan.free) return SubscriptionPeriodState.free;
    if (source == SubscriptionSource.grace) return SubscriptionPeriodState.courtesy;
    switch (status) {
      case SubscriptionStatus.pastDue:
        return SubscriptionPeriodState.paymentIssue;
      case SubscriptionStatus.cancelled:
        return SubscriptionPeriodState.endsOn;
      case SubscriptionStatus.active:
        return source == SubscriptionSource.store ? SubscriptionPeriodState.renewsOn : SubscriptionPeriodState.endsOn;
      case SubscriptionStatus.expired:
        return SubscriptionPeriodState.free;
    }
  }

  /// True when the plan is paid through a store subscription still in force.
  bool hasStoreSubscription(DateTime now) =>
      source == SubscriptionSource.store && effectivePlan(now) != SubscriptionPlan.free;

  /// Version of the plan table in force (#726): [tableVersion] when the table
  /// has it; else, for a paid plan bought before the current table (no
  /// [tableVersion]; the courtesy too, which keeps the old Pro), the legacy
  /// version; else the current one (also for a version this code does not
  /// know).
  String get effectiveTableVersion {
    final version = tableVersion;
    if (version != null) {
      return kPlanTablesInForce.containsKey(version) ? version : kPlanTableCurrentVersion;
    }
    final paid = plan != SubscriptionPlan.free;
    return paid ? kPlanTableLegacyVersion : kPlanTableCurrentVersion;
  }

  /// Row of the plan table in force at [now] (Free of the current table once
  /// the plan expires).
  PlanRow planRowAt(DateTime now) => planInForce(now).row;

  /// The plan in force at [now], the version of the table it follows and
  /// its row: the same answer as `planInForce` on the server and the web.
  /// While the plan is in force, [effectiveTableVersion]; after it expires,
  /// Free of the current table. Limits, features and AI ceilings read it.
  ({SubscriptionPlan plan, String version, PlanRow row}) planInForce(DateTime now) {
    final current = effectivePlan(now);
    final version = current == plan ? effectiveTableVersion : kPlanTableCurrentVersion;
    return (plan: current, version: version, row: kPlanTablesInForce[version]![current]!);
  }

  /// Limits in force at [now]: while the plan is in force, the row of its
  /// table version with each stored limit kept when more generous; after it
  /// expires, Free of the current table.
  SubscriptionLimits effectiveLimits(DateTime now) {
    final current = effectivePlan(now);
    if (current != plan) return SubscriptionLimits.forPlan(current);
    final row = SubscriptionLimits.ofRow(planRowAt(now));
    final stored = _storedLimits ?? limits?.toJson();
    return stored == null ? row : SubscriptionLimits.mergedOver(row, stored);
  }
}
