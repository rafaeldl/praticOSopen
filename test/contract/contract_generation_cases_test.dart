// Runs docs/web-app/contract-cases/contract-generation.json against the app's
// rule: OrderContract (isDueAt, advanceAfterGenerating), contractOrderId and
// buildContractOrder, the code generateOrderFromContract uses. The server
// side is firebase/functions/src/__tests__/contract-generation.cases.test.ts.
//
// Dates in the cases have no offset (wall-clock time, as the app writes
// them), so DateTime.parse gives the same wall time on any machine.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/utils/contract_generation.dart';

const _file = 'docs/web-app/contract-cases/contract-generation.json';
const _lang = 'dart';

Map<String, dynamic> _cast(Object? value) =>
    (value as Map).cast<String, dynamic>();

/// JSON as Firestore stores it (no Dart objects).
Object? _plain(Object? value) => jsonDecode(jsonEncode(value));

Map<String, dynamic> _pick(Map<String, dynamic> from, Map<String, dynamic> like) =>
    {for (final key in like.keys) key: from[key]};

void main() {
  final doc = _cast(jsonDecode(File(_file).readAsStringSync()));
  final templateId = doc['templateId'] as String;
  final company = CompanyAggr.fromJson(_cast(doc['company']));

  test('runs in dart', () => expect(doc['runsIn'], contains(_lang)));

  group('order id', () {
    for (final c in (doc['idCases'] as List).cast<Map<String, dynamic>>()) {
      test(c['id'], () {
        expect(
          contractOrderId(
            c['templateId'] as String,
            DateTime.parse(c['due'] as String),
          ),
          c['orderId'],
        );
      });
    }
  });

  for (final c in (doc['cases'] as List).cast<Map<String, dynamic>>()) {
    test(c['id'], () {
      final want = {
        ..._cast(c['correct'] ?? c['expect']),
        ...?(c['divergesIn']?[_lang] as Map?)?.cast<String, dynamic>(),
      };
      final given = _cast(c['given']);
      final contractJson = {
        ..._cast(doc['contract']),
        ...?(given['contract'] as Map?)?.cast<String, dynamic>(),
      };
      final template = Order.fromJson({
        ..._cast(doc['template']),
        ...?(given['template'] as Map?)?.cast<String, dynamic>(),
        'contract': contractJson,
        'id': templateId,
      });
      final now = DateTime.parse(given['now'] as String);
      final contract = template.contract!;

      expect(contract.isDueAt(now), want['due'], reason: 'due');
      final generates = contract.isDueAt(now) && contract.autoGenerate == true;
      expect(generates, want['generates'], reason: 'generates');
      if (!generates) return;

      final due = contract.nextDueDate!;
      if (want['orderId'] != null) {
        expect(contractOrderId(templateId, due), want['orderId']);
      }

      final order = buildContractOrder(template, now: now, company: company);
      final orderJson = _cast(_plain(order.toJson()));
      expect(orderJson['createdAt'], given['now']);
      expect(orderJson['updatedAt'], given['now']);
      if (want['order'] != null) {
        expect(_pick(orderJson, _cast(want['order'])), _plain(want['order']));
      }

      contract.advanceAfterGenerating(now);
      final after = _cast(_plain(contract.toJson()));
      expect(_pick(after, _cast(want['contract'])), _plain(want['contract']));

      // Generating again at the same moment finds nothing due: never one
      // order per opening of the app.
      expect(contract.isDueAt(now), isFalse);
    });
  }
}
