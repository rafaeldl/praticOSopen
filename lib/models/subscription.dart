import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:json_annotation/json_annotation.dart';

import 'plan_table.dart';

export 'plan_table.dart' show PlanRow, kPlanTables, kPlanTableCurrentVersion;

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

/// Store that bills the subscription. Same values as `SubscriptionStore` in
/// firebase/functions/src/models/types.ts.
enum BillingStore {
  @JsonValue('app_store')
  appStore,
  @JsonValue('play_store')
  playStore,

  /// Bought on the web (Asaas), docs/WEB_CHECKOUT.md. The app never offers a
  /// purchase to these companies and never mentions the website.
  @JsonValue('web')
  web,
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

/// Usage counters of the current period.
@JsonSerializable()
class SubscriptionUsage {
  int photosThisMonth;
  int formTemplatesActive;
  int usersActive;

  @JsonKey(fromJson: _dateFromJson, toJson: _dateToJson)
  DateTime? usageResetAt;

  SubscriptionUsage({
    this.photosThisMonth = 0,
    this.formTemplatesActive = 0,
    this.usersActive = 0,
    this.usageResetAt,
  });

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
  /// Photos per month.
  final int photosPerMonth;

  /// Active form templates.
  final int formTemplates;

  /// Users in the company (members + pending invites).
  final int users;

  /// Show the watermark on the work order PDF.
  final bool pdfWatermark;

  const SubscriptionLimits({
    required this.photosPerMonth,
    required this.formTemplates,
    required this.users,
    required this.pdfWatermark,
  });

  /// The limits a subscription stores, from a row of the plan table.
  factory SubscriptionLimits.ofRow(PlanRow row) => SubscriptionLimits(
        photosPerMonth: row.photosPerMonth,
        formTemplates: row.formTemplates,
        users: row.users,
        pdfWatermark: row.pdfWatermark,
      );

  /// A missing field takes the Free default; reads `users` and falls back to
  /// the legacy client key `collaborators`.
  factory SubscriptionLimits.fromJson(Map<String, dynamic> json) {
    final free = forPlan(SubscriptionPlan.free);
    int intOr(Object? value, int fallback) => value is num ? value.toInt() : fallback;
    final watermark = json['pdfWatermark'];
    return SubscriptionLimits(
      photosPerMonth: intOr(json['photosPerMonth'], free.photosPerMonth),
      formTemplates: intOr(json['formTemplates'], free.formTemplates),
      users: intOr(json['users'] ?? json['collaborators'], free.users),
      pdfWatermark: watermark is bool ? watermark : free.pdfWatermark,
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

  @JsonKey(fromJson: _dateFromJson, toJson: _dateToJson)
  DateTime? updatedAt;

  Subscription({
    this.plan = SubscriptionPlan.free,
    this.status = SubscriptionStatus.active,
    this.source,
    this.store,
    this.expiresAt,
    this.limits,
    SubscriptionUsage? usage,
    this.rcSubscriberId,
    this.updatedAt,
  }) : usage = usage ?? SubscriptionUsage();

  factory Subscription.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionFromJson(json);

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

  /// True when the plan in force was bought on the web: the app shows only
  /// the active plan, with no purchase, restore or "manage" (docs/WEB_CHECKOUT.md).
  bool hasWebSubscription(DateTime now) =>
      hasStoreSubscription(now) && store == BillingStore.web;

  /// Limits in force at [now]: the stored limits (or the plan defaults) while
  /// the plan is in force, Free limits after it expires.
  SubscriptionLimits effectiveLimits(DateTime now) {
    final current = effectivePlan(now);
    if (current != plan) return SubscriptionLimits.forPlan(current);
    return limits ?? SubscriptionLimits.forPlan(plan);
  }
}
