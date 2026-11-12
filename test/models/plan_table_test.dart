// The plan table (docs/plans/plans.json, #722) is the only place with the
// numbers. lib/models/plan_table.dart is generated from it, and what the app
// derives (SubscriptionLimits.defaults, kAiRequestsPerMonth) must come from
// it. The server and the web run the same comparison
// (firebase/functions/src/__tests__/plan-table.test.ts,
// firebase/webapp/tests/plan-table.test.ts).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/subscription.dart';

void main() {
  final table = (jsonDecode(File('docs/plans/plans.json').readAsStringSync()) as Map).cast<String, dynamic>();
  final versions = (table['versions'] as Map).cast<String, dynamic>();
  final current = ((versions[table['currentVersion']] as Map)['plans'] as Map).cast<String, dynamic>();

  test('the generated file is the JSON (run node scripts/plan-table.mjs)', () {
    expect(kPlanTableCurrentVersion, table['currentVersion']);
    expect(SubscriptionPlan.values.map((p) => p.name).toList(), table['plans']);
    final generated = {
      for (final entry in kPlanTables.entries)
        entry.key: {for (final row in entry.value.entries) row.key.name: row.value.toJson()},
    };
    final json = {
      for (final entry in versions.entries) entry.key: (entry.value as Map)['plans'],
    };
    expect(generated, json);
  });

  for (final plan in SubscriptionPlan.values) {
    test('${plan.name}: limits and AI come from the table', () {
      final row = (current[plan.name] as Map).cast<String, dynamic>();
      expect(SubscriptionLimits.forPlan(plan).toJson(), {
        'ordersPerMonth': row['ordersPerMonth'],
        'photosPerMonth': row['photosPerMonth'],
        'formTemplates': row['formTemplates'],
        'users': row['users'],
        'pdfWatermark': row['pdfWatermark'],
      });
      expect(kAiRequestsPerMonth[plan], row['aiPerMonth']);
    });
  }

  test('stored limits meet the table: the more generous number wins, a missing one is the table\'s', () {
    final now = DateTime.utc(2026, 11, 20);
    final starter = Subscription.fromJson({
      'plan': 'starter',
      'limits': {'users': 3, 'photosPerMonth': 200},
    });
    final limits = starter.effectiveLimits(now);
    final row = currentPlanRow(SubscriptionPlan.starter);
    expect(limits.users, 3); // stored 3 > table 2: kept
    expect(limits.photosPerMonth, -1); // table has no limit: wins
    expect(limits.ordersPerMonth, row.ordersPerMonth); // missing: the table's
  });

  test('tableVersion picks the version of the table; unknown is the current one', () {
    final now = DateTime.utc(2026, 11, 20);
    final v1 = Subscription.fromJson({'plan': 'starter', 'tableVersion': '1'});
    expect(v1.effectiveLimits(now).ordersPerMonth, kPlanTables['1']![SubscriptionPlan.starter]!.ordersPerMonth);
    final unknown = Subscription.fromJson({'plan': 'starter', 'tableVersion': '99'});
    expect(unknown.effectiveTableVersion, kPlanTableCurrentVersion);
  });

  test('orders of the month turn by themselves (São Paulo calendar)', () {
    final usage = SubscriptionUsage(ordersMonth: '2026-11', ordersThisMonth: 12, ordersLastMonth: 4);
    expect(orderMonthKey(DateTime.utc(2026, 12, 1, 2, 59)), '2026-11');
    expect(orderMonthKey(DateTime.utc(2026, 12, 1, 3)), '2026-12');
    expect(previousMonthKey('2027-01'), '2026-12');
    expect(usage.ordersAt(DateTime.utc(2026, 11, 20)), (thisMonth: 12, lastMonth: 4));
    expect(usage.ordersAt(DateTime.utc(2026, 12, 5)), (thisMonth: 0, lastMonth: 12));
    expect(usage.ordersAt(DateTime.utc(2027, 1, 5)), (thisMonth: 0, lastMonth: 0));
  });
}
