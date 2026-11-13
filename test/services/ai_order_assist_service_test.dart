import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/services/ai_order_assist_service.dart';

void main() {
  group('parseAiStatusResponse', () {
    test('only 200 with data.enabled == true is on', () {
      expect(
        parseAiStatusResponse(
          200,
          jsonEncode({
            'success': true,
            'data': {
              'enabled': true,
              'usage': {'used': 3, 'limit': 150},
            },
          }),
        ),
        isTrue,
      );
      expect(
        parseAiStatusResponse(
          200,
          jsonEncode({
            'data': {'enabled': false},
          }),
        ),
        isFalse,
      );
      expect(
        parseAiStatusResponse(
          200,
          jsonEncode({
            'data': {'enabled': 'yes'},
          }),
        ),
        isFalse,
      );
      expect(parseAiStatusResponse(200, 'not json'), isFalse);
      expect(
        parseAiStatusResponse(
          403,
          jsonEncode({
            'data': {'enabled': true},
          }),
        ),
        isFalse,
      );
      expect(parseAiStatusResponse(404, ''), isFalse);
    });

    test('isEnabled never throws: no signed-in user means off', () async {
      AiOrderAssistService.clearStatusCache();
      expect(await AiOrderAssistService().isEnabled(), isFalse);
    });
  });

  group('parseAiOrderAssistResponse', () {
    test('reads the draft', () {
      final draft = parseAiOrderAssistResponse(
        200,
        jsonEncode({
          'success': true,
          'data': {
            'transcript': 'capô 500',
            'customer': {
              'match': null,
              'guess': {'name': 'Ana'},
              'alternatives': [],
            },
            'device': {
              'match': {'id': 'd1', 'name': 'Gol', 'serial': 'ABC1D23'},
              'guess': {'serial': 'ABC1D23'},
              'alternatives': [],
            },
            'items': [
              {
                'kind': 'service',
                'name': 'Pintura de capô',
                'description': ' Lado direito ',
                'value': 500,
                'quantity': 1,
                'catalogId': 's2',
                'alternatives': [
                  {'id': 's3', 'name': 'Pintura', 'value': 300},
                ],
              },
              {
                'kind': 'product',
                'name': 'Massa',
                'value': null,
                'quantity': 2,
                'catalogId': null,
              },
            ],
            'notes': null,
            'usage': {'used': 3, 'limit': 10},
          },
        }),
      );
      expect(draft.transcript, 'capô 500');
      expect(draft.customer, isNull);
      expect(draft.customerGuess, 'Ana');
      expect(draft.device!.id, 'd1');
      expect(draft.items.first.value, 500.0);
      expect(draft.items.first.description, 'Lado direito');
      expect(draft.items.last.description, isNull);
      expect(draft.items.first.alternatives.single.name, 'Pintura');
      expect(draft.items.last.isProduct, isTrue);
      expect(draft.items.last.value, isNull);
      expect(draft.items.last.quantity, 2);
      expect(draft.used, 3);
      expect(draft.limit, 10);
    });

    AiOrderAssistException errorOf(int status, Object body) {
      try {
        parseAiOrderAssistResponse(status, jsonEncode(body));
      } on AiOrderAssistException catch (e) {
        return e;
      }
      fail('expected an exception');
    }

    test('maps the error codes', () {
      expect(
        errorOf(403, {
          'success': false,
          'error': {'code': 'AI_DISABLED'},
        }).error,
        AiAssistError.disabled,
      );
      final quota = errorOf(429, {
        'success': false,
        'error': {
          'code': 'AI_QUOTA_EXCEEDED',
          'details': {'used': 10, 'limit': 10},
        },
      });
      expect(quota.error, AiAssistError.quotaExceeded);
      expect(quota.limit, 10);
      expect(quota.period, isNull);
      final daily = errorOf(429, {
        'success': false,
        'error': {
          'code': 'AI_QUOTA_EXCEEDED',
          'details': {'used': 200, 'limit': 200, 'period': 'day'},
        },
      });
      expect(daily.period, 'day');
      expect(daily.limit, 200);
      expect(
        errorOf(503, {
          'success': false,
          'error': {'code': 'AI_UNAVAILABLE'},
        }).error,
        AiAssistError.unavailable,
      );
      expect(errorOf(500, {'oops': true}).error, AiAssistError.other);
    });

    test('non-JSON body is "other"', () {
      expect(
        () => parseAiOrderAssistResponse(502, '<html>'),
        throwsA(
          isA<AiOrderAssistException>().having(
            (e) => e.error,
            'error',
            AiAssistError.other,
          ),
        ),
      );
    });
  });

  group('parseDueDate', () {
    test('date only is ready at 18:00; date and time keep the time', () {
      expect(parseDueDate('2026-10-16'), DateTime(2026, 10, 16, 18));
      expect(parseDueDate('2026-10-16T09:30'), DateTime(2026, 10, 16, 9, 30));
    });

    test('anything else is no date', () {
      expect(parseDueDate(null), isNull);
      expect(parseDueDate('sexta'), isNull);
      expect(parseDueDate(20261016), isNull);
    });
  });

  group('parseAiStatus', () {
    test('reads the use of the month', () {
      final status = parseAiStatus(
        200,
        '{"data":{"enabled":true,"usage":{"used":7,"limit":400}}}',
      );
      expect(status.enabled, isTrue);
      expect(status.used, 7);
      expect(status.limit, 400);
    });

    test('off without usage or on failure', () {
      expect(parseAiStatus(200, '{"data":{"enabled":false}}').enabled, isFalse);
      expect(parseAiStatus(500, '').enabled, isFalse);
      expect(parseAiStatus(200, 'nope').enabled, isFalse);
    });

    test('keeps working without the usage block', () {
      final status = parseAiStatus(200, '{"data":{"enabled":true}}');
      expect(status.enabled, isTrue);
      expect(status.used, isNull);
    });
  });

  group('actions', () {
    AiOrderDraft read(Object? actions, {String? nfse}) => AiOrderDraft.fromJson({
      'actions': actions,
      'nfseAutoIssue': ?nfse,
    });

    test('old server: no actions', () {
      expect(AiOrderDraft.fromJson(const {}).actions, isNull);
      expect(read(null).actions, isNull);
    });

    test('reads a payment with day and method', () {
      final draft = read({
        'payment': {
          'kind': 'value',
          'value': 500,
          'method': 'pix',
          'paidDate': '2026-11-01',
        },
      }, nfse: 'paid');
      final payment = draft.actions!.payment!;
      expect(payment.kind, 'value');
      expect(payment.value, 500);
      expect(payment.method, 'pix');
      expect(payment.paidDay, DateTime(2026, 11, 1));
      expect(draft.nfseAutoIssue, 'paid');
    });

    test('reads a discount and a status', () {
      final actions = read({
        'discount': {'kind': 'percent', 'value': 10},
        'status': 'done',
      }).actions!;
      expect(actions.discount!.isPercent, isTrue);
      expect(actions.discount!.value, 10);
      expect(actions.status, 'done');
    });

    test('ignores what it does not know', () {
      expect(read({'status': 'canceled'}).actions, isNull);
      expect(
        read({
          'payment': {'kind': 'someday'},
        }).actions,
        isNull,
      );
      expect(
        read({
          'payment': {'kind': 'full', 'method': 'bitcoin'},
        }).actions!.payment!.method,
        isNull,
      );
    });
  });
}
