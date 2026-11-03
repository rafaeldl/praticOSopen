// Runs docs/web-app/contract-cases/plan-limits.json against the real app
// code (FeatureGateService over Subscription.fromJson). The server side is
// firebase/functions/src/__tests__/plan-limits.cases.test.ts.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/subscription.dart';
import 'package:praticos/services/feature_gate_service.dart';

const _file = 'docs/web-app/contract-cases/plan-limits.json';
const _lang = 'dart';

Map<String, dynamic> _cast(Object? value) => (value as Map).cast<String, dynamic>();

Subscription? _subscription(Map<String, dynamic> given) {
  final json = given['subscription'];
  if (json == null) return null;
  final days = given['expiresInDays'] as int?;
  return Subscription.fromJson({
    ..._cast(json),
    if (days != null) 'expiresAt': DateTime.now().add(Duration(days: days)).toUtc().toIso8601String(),
  });
}

FeatureGateResult _check(Subscription? sub, String resource, int usage, int adding) {
  if (sub == null) {
    // A null subscription is the Free plan with no usage (Subscription()).
    expect(usage, 0, reason: 'a case without subscription has no usage in the app');
  } else {
    sub.usage
      ..photosThisMonth = usage
      ..formTemplatesActive = usage
      ..usersActive = usage;
  }
  switch (resource) {
    case 'photo':
      return adding == 1 ? FeatureGateService.canAddPhoto(sub) : FeatureGateService.canAddPhotos(sub, adding);
    case 'formTemplate':
      expect(adding, 1);
      return FeatureGateService.canCreateFormTemplate(sub);
    case 'collaborator':
      expect(adding, 1);
      return FeatureGateService.canAddCollaborator(sub);
  }
  throw ArgumentError('unknown resource $resource');
}

void main() {
  final doc = _cast(jsonDecode(File(_file).readAsStringSync()));

  tearDown(() => FeatureGateService.debugPlanLimitsEnforcedOverride = null);

  test('runs in dart', () => expect(doc['runsIn'], contains(_lang)));

  for (final c in (doc['cases'] as List).cast<Map<String, dynamic>>()) {
    test(c['id'], () {
      final want = {
        ..._cast(c['correct'] ?? c['expect']),
        ...?(c['divergesIn']?[_lang] as Map?)?.cast<String, dynamic>(),
      };
      final given = _cast(c['given']);
      FeatureGateService.debugPlanLimitsEnforcedOverride = given['paidPlansEnabled'] as bool;
      final sub = _subscription(given);
      if (given['kind'] == 'watermark') {
        expect({'watermark': FeatureGateService.shouldShowPdfWatermark(sub)}, want);
        return;
      }
      final result = _check(sub, given['resource'] as String, given['usage'] as int, given['adding'] as int);
      expect(
        {'allowed': result.isAllowed, 'limit': result.limit, 'plan': result.currentPlan.name},
        want,
      );
    });
  }
}
