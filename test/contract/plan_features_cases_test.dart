// Runs docs/web-app/contract-cases/plan-features.json against the real app
// code (FeatureGateService.checkFeatureKey over Subscription.fromJson). The
// server side is firebase/functions/src/__tests__/plan-features.cases.test.ts.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/subscription.dart';
import 'package:praticos/services/feature_gate_service.dart';

const _file = 'docs/web-app/contract-cases/plan-features.json';

Map<String, dynamic> _cast(Object? value) => (value as Map).cast<String, dynamic>();

void main() {
  final doc = _cast(jsonDecode(File(_file).readAsStringSync()));

  test('runs in dart', () => expect(doc['runsIn'], contains('dart')));

  for (final raw in doc['cases'] as List) {
    final c = _cast(raw);
    final given = _cast(c['given']);
    final expected = _cast(c['expect']);
    test(c['id'], () {
      if (given['kind'] == 'role') {
        expect({'feature': FeatureGateService.featureForRole(given['role'] as String?)?.name}, expected);
        return;
      }
      final now = DateTime.now();
      final json = given['subscription'];
      final days = given['expiresInDays'] as int?;
      final sub = json == null
          ? null
          : Subscription.fromJson({
              ..._cast(json),
              if (days != null) 'expiresAt': now.add(Duration(days: days)).toUtc().toIso8601String(),
            });
      final result = FeatureGateService.checkFeatureKey(
        sub,
        given['feature'] as String,
        now: now,
        enforced: given['paidPlansEnabled'] as bool,
      );
      expect({
        'allowed': result.isAllowed,
        'plan': result.currentPlan.name,
        'requiredPlan': result.requiredPlan?.name,
      }, expected);
    });
  }
}
