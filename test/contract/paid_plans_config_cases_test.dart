// Runs docs/web-app/contract-cases/paid-plans-config.json against
// PaidPlansConfig. The server side is
// firebase/functions/src/__tests__/paid-plans-config.cases.test.ts.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/services/paid_plans_config.dart';

const _file = 'docs/web-app/contract-cases/paid-plans-config.json';
const _lang = 'dart';

Map<String, dynamic>? _castOrNull(Object? value) => (value as Map?)?.cast<String, dynamic>();

void main() {
  final doc = _castOrNull(jsonDecode(File(_file).readAsStringSync()))!;

  test('runs in dart', () => expect(doc['runsIn'], contains(_lang)));

  for (final c in (doc['cases'] as List).cast<Map<String, dynamic>>()) {
    test(c['id'], () {
      final want = {
        ..._castOrNull(c['correct'] ?? c['expect'])!,
        ...?(c['divergesIn']?[_lang] as Map?)?.cast<String, dynamic>(),
      };
      final given = _castOrNull(c['given'])!;
      final config = PaidPlansConfig.fromJson(_castOrNull(given['config']));
      switch (given['kind']) {
        case 'switch':
          expect({'on': config.onFor(given['companyId'] as String?)}, want);
        case 'notice':
          final notice = config.freeLimitsNotice(
            isFree: given['isFree'] as bool,
            now: DateTime.parse(given['now'] as String),
          );
          expect(notice == null ? {'due': false} : {'due': true, 'daysLeft': notice.daysLeft}, want);
        default:
          expect({'counts': config.lastMonthCounts(DateTime.parse(given['now'] as String))}, want);
      }
    });
  }
}
