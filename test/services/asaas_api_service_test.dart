import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:praticos/models/order_charge.dart';
import 'package:praticos/services/asaas_api_service.dart';

const _headers = {
  'Authorization': 'Bearer fake-id-token',
  'X-Company-Id': 'company1',
};

AsaasApiService _service(MockClientHandler handler) =>
    AsaasApiService.withClient(
      MockClient(handler),
      headersProvider: () async => Map.of(_headers),
    );

Map<String, dynamic> _chargeJson({String status = 'pending'}) => {
      'id': 'ch1',
      'asaasPaymentId': 'pay_1',
      'mode': 'single',
      'value': 300,
      'dueDate': '2026-10-07',
      'status': status,
      'invoiceUrl': 'https://sandbox.asaas.com/i/abc',
      'paidAsaasPaymentIds': <String>[],
      'createdAt': '2026-10-04T12:00:00.000Z',
    };

http.Response _ok(Object data, [int status = 200]) =>
    http.Response(jsonEncode({'success': true, 'data': data}), status);

http.Response _error(String code, int status) => http.Response(
      jsonEncode({
        'success': false,
        'error': {'code': code, 'message': 'raw backend text'},
      }),
      status,
    );

void main() {
  group('AsaasApiService', () {
    test('connect() faz POST com a chave e devolve PaymentSettings', () async {
      final service = _service((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, endsWith('/v1/app/payments/asaas/connect'));
        expect(request.headers['Authorization'], 'Bearer fake-id-token');
        expect(request.headers['X-Company-Id'], 'company1');
        expect(request.headers['Content-Type'], startsWith('application/json'));
        expect(jsonDecode(request.body), {'apiKey': '\$aact_hmlg_000'});
        return _ok({
          'asaasEnabled': true,
          'asaasConnected': true,
          'asaasAccountName': 'Rafsoft',
          'asaasEnvironment': 'sandbox',
        });
      });

      final settings = await service.connect('\$aact_hmlg_000');

      expect(settings.asaasConnected, isTrue);
      expect(settings.asaasAccountName, 'Rafsoft');
      expect(settings.isSandbox, isTrue);
    });

    test('connect() com chave inválida lança ASAAS_INVALID_API_KEY', () async {
      final service =
          _service((_) async => _error('ASAAS_INVALID_API_KEY', 400));

      expect(
        () => service.connect('\$aact_hmlg_bad'),
        throwsA(isA<AsaasApiException>()
            .having((e) => e.code, 'code', 'ASAAS_INVALID_API_KEY')),
      );
    });

    test('disconnect() faz DELETE', () async {
      var called = false;
      final service = _service((request) async {
        called = true;
        expect(request.method, 'DELETE');
        expect(request.url.path, endsWith('/v1/app/payments/asaas/connect'));
        return http.Response(jsonEncode({'success': true}), 200);
      });

      await service.disconnect();

      expect(called, isTrue);
    });

    test('createCharge() à vista envia valor, modo e vencimento', () async {
      final service = _service((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, endsWith('/v1/app/orders/o1/charges'));
        expect(jsonDecode(request.body), {
          'value': 300,
          'mode': 'single',
          'dueDate': '2026-10-07',
        });
        return _ok(_chargeJson(), 201);
      });

      final charge = await service.createCharge(
        'o1',
        value: 300,
        mode: ChargeMode.single,
        installmentCount: 5,
        dueDate: DateTime(2026, 10, 7),
      );

      expect(charge.id, 'ch1');
      expect(charge.status, ChargeStatus.pending);
      expect(charge.invoiceUrl, 'https://sandbox.asaas.com/i/abc');
    });

    test('createCharge() parcelado envia parcelas e CPF', () async {
      final service = _service((request) async {
        expect(jsonDecode(request.body), {
          'value': 700,
          'mode': 'cardInstallments',
          'installmentCount': 3,
          'dueDate': '2026-10-07',
          'customerTaxId': '52998224725',
        });
        return _ok(_chargeJson(), 201);
      });

      await service.createCharge(
        'o1',
        value: 700,
        mode: ChargeMode.cardInstallments,
        installmentCount: 3,
        dueDate: DateTime(2026, 10, 7),
        customerTaxId: '52998224725',
      );
    });

    test('buildChargeBody arredonda para centavos', () {
      final body = AsaasApiService.buildChargeBody(
        value: 333.333,
        mode: ChargeMode.single,
      );

      expect(body, {'value': 333.33, 'mode': 'single'});
    });

    test('parseCharge aceita chargeId no lugar de id', () {
      final charge = AsaasApiService.parseCharge(jsonEncode({
        'success': true,
        'data': {
          'chargeId': 'ch9',
          'invoiceUrl': 'https://sandbox.asaas.com/i/xyz',
          'status': 'pending',
        },
      }));

      expect(charge.id, 'ch9');
      expect(charge.invoiceUrl, 'https://sandbox.asaas.com/i/xyz');
    });

    test('cancelCharge() faz DELETE na cobrança', () async {
      final service = _service((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, endsWith('/v1/app/orders/o1/charges/ch1'));
        return _ok(_chargeJson(status: 'canceled'));
      });

      final charge = await service.cancelCharge('o1', 'ch1');

      expect(charge.status, ChargeStatus.canceled);
    });

    test('sem Authorization lança UNAUTHENTICATED sem chamar a rede', () async {
      var calls = 0;
      final service = AsaasApiService.withClient(
        MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
        headersProvider: () async => {'X-Company-Id': 'company1'},
      );

      await expectLater(
        service.disconnect(),
        throwsA(isA<AsaasApiException>()
            .having((e) => e.code, 'code', 'UNAUTHENTICATED')),
      );
      expect(calls, 0);
    });

    test('headersProvider que lança vira UNAUTHENTICATED', () async {
      final service = AsaasApiService.withClient(
        MockClient((_) async => http.Response('{}', 200)),
        headersProvider: () async => throw StateError('no user'),
      );

      expect(
        () => service.disconnect(),
        throwsA(isA<AsaasApiException>()
            .having((e) => e.code, 'code', 'UNAUTHENTICATED')),
      );
    });

    test('falha de rede vira NETWORK_ERROR', () async {
      final service =
          _service((_) async => throw http.ClientException('offline'));

      expect(
        () => service.disconnect(),
        throwsA(isA<AsaasApiException>()
            .having((e) => e.code, 'code', 'NETWORK_ERROR')),
      );
    });

    test('corpo HTML com 502 lança code null', () async {
      final service = _service(
          (_) async => http.Response('<html>Bad Gateway</html>', 502));

      expect(
        () => service.disconnect(),
        throwsA(isA<AsaasApiException>()
            .having((e) => e.code, 'code', isNull)
            .having((e) => e.message, 'message', 'Request failed (502)')),
      );
    });

    test('sem envelope: 401/403/429 recebem código pelo status', () async {
      for (final entry in {401: 'UNAUTHENTICATED', 403: 'FORBIDDEN', 429: 'RATE_LIMIT_EXCEEDED'}.entries) {
        final service = _service((_) async => http.Response('', entry.key));
        await expectLater(
          service.disconnect(),
          throwsA(isA<AsaasApiException>().having((e) => e.code, 'code', entry.value)),
        );
      }
    });
  });
}
