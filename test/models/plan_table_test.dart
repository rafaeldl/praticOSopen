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
      'tableVersion': '2',
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
    expect(v1.effectiveLimits(now).ordersPerMonth, kPlanTablesInForce['1']![SubscriptionPlan.starter]!.ordersPerMonth);
    final unknown = Subscription.fromJson({'plan': 'starter', 'tableVersion': '99'});
    expect(unknown.effectiveTableVersion, kPlanTableCurrentVersion);
  });

  test('an older version is in force as the more generous of it and the current one (#726)', () {
    int more(int a, int b) => a == -1 || b == -1 ? -1 : (a > b ? a : b);
    expect(kPlanTableLegacyVersion, table['legacyVersion']);
    for (final plan in SubscriptionPlan.values) {
      expect(kPlanTablesInForce[kPlanTableCurrentVersion]![plan]!.toJson(), kPlanTables[kPlanTableCurrentVersion]![plan]!.toJson());
    }
    for (final version in kPlanTables.keys.where((v) => v != kPlanTableCurrentVersion)) {
      for (final plan in SubscriptionPlan.values) {
        final old = kPlanTables[version]![plan]!;
        final now = currentPlanRow(plan);
        final row = kPlanTablesInForce[version]![plan]!;
        expect(row.ordersPerMonth, more(old.ordersPerMonth, now.ordersPerMonth));
        expect(row.users, more(old.users, now.users));
        expect(row.photosPerMonth, more(old.photosPerMonth, now.photosPerMonth));
        expect(row.formTemplates, more(old.formTemplates, now.formTemplates));
        expect(row.nfseCnpjs, more(old.nfseCnpjs, now.nfseCnpjs));
        expect(row.aiPerMonth, more(old.aiPerMonth, now.aiPerMonth));
        expect(row.aiPerDay, more(old.aiPerDay, now.aiPerDay));
        expect(row.ownChecklists, old.ownChecklists || now.ownChecklists);
        expect(row.overageAllowed, old.overageAllowed || now.overageAllowed);
        expect(row.pdfWatermark, old.pdfWatermark && now.pdfWatermark);
        // A version without a feature list allowed every feature: it keeps
        // none (no gate).
        expect(
          row.features.toSet(),
          old.features.isEmpty ? <String>{} : {...old.features, ...now.features},
        );
      }
    }
  });

  test('a paid subscription without tableVersion, the courtesy too, keeps its old table; Free follows the new one (#726)', () {
    final now = DateTime.utc(2026, 11, 20);
    final old = Subscription.fromJson({'plan': 'starter', 'source': 'store'});
    expect(old.effectiveTableVersion, kPlanTableLegacyVersion);
    expect(old.effectiveLimits(now).users, 3);
    expect(old.effectiveLimits(now).ordersPerMonth, -1);
    expect(old.planRowAt(now).aiPerDay, -1);
    final bought = Subscription.fromJson({'plan': 'starter', 'source': 'store', 'tableVersion': '2'});
    expect(bought.effectiveLimits(now).users, 2);
    final courtesy = Subscription.fromJson({'plan': 'pro', 'source': 'grace', 'expiresAt': '2026-12-07T12:00:00.000Z'});
    expect(courtesy.effectiveTableVersion, kPlanTableLegacyVersion);
    expect(courtesy.effectiveLimits(now).ordersPerMonth, -1);
    expect(courtesy.planInForce(now).row.features, isEmpty);
    expect(Subscription.fromJson({'plan': 'free'}).effectiveTableVersion, kPlanTableCurrentVersion);
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
