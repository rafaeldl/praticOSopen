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
        'photosPerMonth': row['photosPerMonth'],
        'formTemplates': row['formTemplates'],
        'users': row['users'],
        'pdfWatermark': row['pdfWatermark'],
      });
      expect(kAiRequestsPerMonth[plan], row['aiPerMonth']);
    });
  }

  test('a stored limit missing a field takes the Free default', () {
    final free = SubscriptionLimits.forPlan(SubscriptionPlan.free);
    final limits = SubscriptionLimits.fromJson({'photosPerMonth': 999});
    expect(limits.photosPerMonth, 999);
    expect(limits.formTemplates, free.formTemplates);
    expect(limits.users, free.users);
    expect(limits.pdfWatermark, free.pdfWatermark);
  });
}
