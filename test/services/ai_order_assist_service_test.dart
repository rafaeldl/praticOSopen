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
}
