// What createContractOrder writes on the template, decided on the template
// read inside the transaction (contractAdvanceUpdate). The app reads the
// templates from its cache when it opens: a contract stopped or paused on the
// web since then must not get an order nor be turned back on.
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/utils/contract_generation.dart';

final _due = DateTime(2026, 11, 10);
final _now = DateTime(2026, 11, 12, 8);

/// The template document as Firestore has it.
Map<String, dynamic> _template({
  bool active = true,
  bool autoGenerate = true,
  bool isContract = true,
  DateTime? next,
  Object? pausedAt,
  int generatedCount = 3,
}) => {
  'isContract': isContract,
  'status': 'approved',
  'contract': {
    'frequency': 'monthly',
    'interval': 1,
    'startDate': '2026-01-10T00:00:00.000',
    'nextDueDate': (next ?? _due).toIso8601String(),
    'lastGeneratedDate': '2026-10-10T09:00:00.000',
    'generatedCount': generatedCount,
    'autoGenerate': autoGenerate,
    'active': active,
    'reminderDaysBefore': 3,
    'pausedAt': ?pausedAt,
  },
};

Map<String, dynamic>? _update(
  Map<String, dynamic>? template, {
  bool orderExists = false,
}) => contractAdvanceUpdate(
  template,
  due: _due,
  now: _now,
  orderExists: orderExists,
);

void main() {
  group('contractAdvanceUpdate', () {
    test('still due: writes only contract.* fields that move', () {
      final update = _update(_template())!;
      expect(update.keys, unorderedEquals([
        'contract.lastGeneratedDate',
        'contract.nextDueDate',
        'contract.generatedCount',
      ]));
      expect(update['contract.lastGeneratedDate'], _now.toIso8601String());
      expect(update['contract.nextDueDate'], '2026-12-10T00:00:00.000');
      expect(update['contract.generatedCount'], 4);
      // Never the whole map: reminderDaysBefore, pausedAt and what the web
      // changed stay as they are.
      expect(update.containsKey('contract'), isFalse);
    });

    test('stopped on the web since the cache: nothing', () {
      expect(_update(_template(active: false)), isNull);
    });

    test('paused on the web (pausedAt): nothing, even if active', () {
      expect(_update(_template(pausedAt: '2026-11-01T10:00:00.000')), isNull);
    });

    test('another phone or the server job already moved it: nothing', () {
      expect(_update(_template(next: DateTime(2026, 12, 10))), isNull);
    });

    test('creating orders turned off or no longer a contract: nothing', () {
      expect(_update(_template(autoGenerate: false)), isNull);
      expect(_update(_template(isContract: false)), isNull);
    });

    test('template gone: nothing', () {
      expect(_update(null), isNull);
    });

    test('the order of the date already exists: count kept', () {
      final update = _update(_template(), orderExists: true)!;
      expect(update['contract.generatedCount'], 3);
      expect(update['contract.nextDueDate'], '2026-12-10T00:00:00.000');
    });

    test('ends after this one: turns off, never writes active true', () {
      final template = _template();
      (template['contract'] as Map)['endDate'] = '2026-11-30T00:00:00.000';
      final update = _update(template)!;
      expect(update['contract.active'], isFalse);
      expect(_update(_template())!.containsKey('contract.active'), isFalse);
    });
  });

  group('pausedAt', () {
    OrderContract contract({Object? pausedAt}) => OrderContract.fromJson({
      'frequency': 'monthly',
      'interval': 1,
      'nextDueDate': _due.toIso8601String(),
      'autoGenerate': true,
      'active': true,
      'pausedAt': ?pausedAt,
    });

    test('a paused contract is not due and lists as ended', () {
      final paused = contract(pausedAt: '2026-11-01T10:00:00.000');
      expect(paused.pausedAt, DateTime(2026, 11, 1, 10));
      expect(paused.isDueAt(_now), isFalse);
      expect(paused.isRunning, isFalse);
      expect(contract().isRunning, isTrue);
      expect(contract().isDueAt(_now), isTrue);
    });

    test('kept when the app writes the contract back', () {
      final paused = contract(pausedAt: '2026-11-01T10:00:00.000');
      expect(paused.toJson()['pausedAt'], '2026-11-01T10:00:00.000');
      // A contract that was never paused does not get the field.
      expect(contract().toJson().containsKey('pausedAt'), isFalse);
    });
  });
}
