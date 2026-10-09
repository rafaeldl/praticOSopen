import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:json_annotation/json_annotation.dart';

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
@JsonSerializable()
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
    this.photosPerMonth = 30,
    this.formTemplates = 1,
    this.users = 1,
    this.pdfWatermark = true,
  });

  /// Reads `users` and falls back to the legacy client key `collaborators`.
  factory SubscriptionLimits.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionLimitsFromJson(<String, dynamic>{
        ...json,
        'users': json['users'] ?? json['collaborators'],
      });

  Map<String, dynamic> toJson() => _$SubscriptionLimitsToJson(this);

  /// Default limits per plan (same values as the server).
  static const Map<SubscriptionPlan, SubscriptionLimits> defaults = {
    SubscriptionPlan.free: SubscriptionLimits(
      photosPerMonth: 30,
      formTemplates: 1,
      users: 1,
      pdfWatermark: true,
    ),
    SubscriptionPlan.starter: SubscriptionLimits(
      photosPerMonth: 200,
      formTemplates: 3,
      users: 3,
      pdfWatermark: false,
    ),
    SubscriptionPlan.pro: SubscriptionLimits(
      photosPerMonth: 500,
      formTemplates: 10,
      users: 5,
      pdfWatermark: false,
    ),
    SubscriptionPlan.business: SubscriptionLimits(
      photosPerMonth: -1,
      formTemplates: -1,
      users: -1,
      pdfWatermark: false,
    ),
  };

  static SubscriptionLimits forPlan(SubscriptionPlan plan) {
    return defaults[plan] ?? const SubscriptionLimits();
  }
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

  /// Limits in force at [now]: the stored limits (or the plan defaults) while
  /// the plan is in force, Free limits after it expires.
  SubscriptionLimits effectiveLimits(DateTime now) {
    final current = effectivePlan(now);
    if (current != plan) return SubscriptionLimits.forPlan(current);
    return limits ?? SubscriptionLimits.forPlan(plan);
  }
}
