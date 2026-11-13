// Runs docs/web-app/contract-cases/plan-overview.json against planOverview
// (lib/services/plan_overview.dart). The web side is
// firebase/webapp/tests/contract-cases.test.ts.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/services/paid_plans_config.dart';
import 'package:praticos/models/subscription.dart';
import 'package:praticos/services/plan_overview.dart';

const _file = 'docs/web-app/contract-cases/plan-overview.json';

Map<String, dynamic> _cast(Object? value) => (value as Map).cast<String, dynamic>();

void main() {
  final doc = _cast(jsonDecode(File(_file).readAsStringSync()));

  test('runs in dart', () => expect(doc['runsIn'], contains('dart')));

  for (final raw in doc['cases'] as List) {
    final c = _cast(raw);
    final given = _cast(c['given']);
    test(c['id'], () {
      final now = DateTime.now();
      final days = given['expiresInDays'] as int?;
      final orders = _cast(given['orders']);
      final sub = Subscription.fromJson({
        ..._cast(given['subscription']),
        if (days != null) 'expiresAt': now.add(Duration(days: days)).toUtc().toIso8601String(),
        'usage': {
          'ordersMonth': orderMonthKey(now),
          'ordersThisMonth': orders['thisMonth'],
          'ordersLastMonth': orders['lastMonth'],
        },
      });
      final got = planOverview(
        sub,
        people: given['people'] as int,
        taxIds: given['taxIds'] as int,
        now: now,
        enforced: given['paidPlansEnabled'] as bool,
        config: given['limitsStartInDays'] == null
            ? PaidPlansConfig.off
            : PaidPlansConfig(limitsStartAt: now.toUtc().add(Duration(days: given['limitsStartInDays'] as int))),
      );
      expect({
        'plan': got.plan.name,
        'rows': [
          for (final r in got.rows) {'resource': r.resource.name, 'used': r.used, 'limit': r.limit, 'level': r.level.name},
        ],
        'notice': got.notice == null
            ? null
            : {'kind': got.notice!.name, 'resource': got.notice!.name.startsWith('orders') ? 'orders' : 'people'},
        'next': got.next == null
            ? null
            : {'plan': got.next!.plan.name, 'features': [for (final f in got.next!.features) f.name]},
      }, c['expect']);
    });
  }
}
