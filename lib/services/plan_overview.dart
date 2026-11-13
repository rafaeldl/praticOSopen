// ignore_for_file: lines_longer_than_80_chars
import 'package:praticos/models/subscription.dart';
import 'package:praticos/services/feature_gate_service.dart';
import 'package:praticos/services/paid_plans_config.dart';

/// Rows of the Plan screen (#725).
enum PlanOverviewResource { orders, people, taxIds }

/// Where a row stands: -1 limit is unlimited; near from 80%.
enum PlanOverviewLevel { unlimited, ok, near, atLimit, over }

/// The one notice of the Plan screen, orders first.
enum PlanOverviewNotice {
  ordersNear,
  ordersAtLimit,
  ordersGrace,
  ordersBlocked,
  ordersContactUs,
  peopleAtLimit,
  peopleContactUs,
}

class PlanOverviewRow {
  const PlanOverviewRow(this.resource, this.used, this.limit, this.level);
  final PlanOverviewResource resource;
  final int used;
  final int limit;
  final PlanOverviewLevel level;
}

/// The next plan and what it gives on top of the current one.
class PlanOverviewNext {
  const PlanOverviewNext(this.plan, this.features);
  final SubscriptionPlan plan;
  final List<PlanFeature> features;
}

/// What the Plan screen shows, the same on the web
/// (firebase/webapp/src/lib/plan-overview.ts). Cases:
/// docs/web-app/contract-cases/plan-overview.json. No assistant counter.
class PlanOverview {
  const PlanOverview({required this.plan, required this.rows, this.notice, this.next});
  final SubscriptionPlan plan;
  final List<PlanOverviewRow> rows;
  final PlanOverviewNotice? notice;
  final PlanOverviewNext? next;

  PlanOverviewRow? row(PlanOverviewResource resource) {
    for (final r in rows) {
      if (r.resource == resource) return r;
    }
    return null;
  }
}

PlanOverviewLevel _level(int used, int limit) {
  if (limit < 0) return PlanOverviewLevel.unlimited;
  if (used > limit) return PlanOverviewLevel.over;
  if (used == limit) return PlanOverviewLevel.atLimit;
  return used >= limit * 0.8 ? PlanOverviewLevel.near : PlanOverviewLevel.ok;
}

/// [people] are members plus pending invites; [taxIds] the company's fiscal
/// emitters. [enforced] is the one switch (FeatureGateService.planLimitsEnforced);
/// [config] defaults to FeatureGateService.paidPlansConfig (limitsStartAt).
PlanOverview planOverview(
  Subscription? subscription, {
  required int people,
  required int taxIds,
  required DateTime now,
  bool? enforced,
  PaidPlansConfig? config,
}) {
  final sub = subscription ?? Subscription();
  final on = enforced ?? FeatureGateService.planLimitsEnforced;
  // In the month from config/paidPlans.limitsStartAt the month before does
  // not take the grace away (FeatureGateService._check, lastMonthCounts).
  final lastMonthCounts = (config ?? FeatureGateService.paidPlansConfig).lastMonthCounts(now);
  final plan = sub.effectivePlan(now);
  final limits = sub.effectiveLimits(now);
  final row = sub.planRowAt(now);
  final orders = sub.usage.ordersAt(now);
  int limit(int value) => on ? value : -1;

  final ordersLimit = limit(limits.ordersPerMonth);
  final peopleLimit = limit(limits.users);
  final taxIdsLimit = limit(row.nfseCnpjs);
  final peopleLevel = peopleLimit == 1 ? PlanOverviewLevel.ok : _level(people, peopleLimit);
  final rows = [
    PlanOverviewRow(PlanOverviewResource.orders, orders.thisMonth, ordersLimit, _level(orders.thisMonth, ordersLimit)),
    PlanOverviewRow(PlanOverviewResource.people, people, peopleLimit, peopleLevel),
    if (row.nfseCnpjs != 0)
      PlanOverviewRow(PlanOverviewResource.taxIds, taxIds, taxIdsLimit, _level(taxIds, taxIdsLimit)),
  ];

  PlanOverviewNotice? notice;
  if (on) {
    final level = rows.first.level;
    final overage = row.overageAllowed;
    if (level == PlanOverviewLevel.over && overage) {
      notice = PlanOverviewNotice.ordersContactUs;
    } else if ((level == PlanOverviewLevel.over || level == PlanOverviewLevel.atLimit) && lastMonthCounts && orders.lastMonth > ordersLimit) {
      notice = PlanOverviewNotice.ordersBlocked;
    } else if (level == PlanOverviewLevel.over) {
      notice = PlanOverviewNotice.ordersGrace;
    } else if (level == PlanOverviewLevel.atLimit) {
      notice = PlanOverviewNotice.ordersAtLimit;
    } else if (level == PlanOverviewLevel.near) {
      notice = PlanOverviewNotice.ordersNear;
    } else if (peopleLevel == PlanOverviewLevel.over && overage) {
      notice = PlanOverviewNotice.peopleContactUs;
    } else if (peopleLevel == PlanOverviewLevel.over || peopleLevel == PlanOverviewLevel.atLimit) {
      notice = PlanOverviewNotice.peopleAtLimit;
    }
  }

  PlanOverviewNext? next;
  final index = SubscriptionPlan.values.indexOf(plan);
  if (index + 1 < SubscriptionPlan.values.length) {
    final nextPlan = SubscriptionPlan.values[index + 1];
    final have = currentPlanRow(plan).features.toSet();
    final byName = {for (final f in PlanFeature.values) f.name: f};
    next = PlanOverviewNext(nextPlan, [
      for (final key in currentPlanRow(nextPlan).features)
        if (!have.contains(key) && byName[key] != null) byName[key]!,
    ]);
  }
  return PlanOverview(plan: plan, rows: rows, notice: notice, next: next);
}
