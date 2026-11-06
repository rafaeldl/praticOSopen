import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:praticos/services/order_stage_api_service.dart';

OrderStageApiService _service(
  Future<http.Response> Function(http.Request) handler,
) => OrderStageApiService.withClient(
  MockClient(handler),
  tokenProvider: () async => 'fake-id-token',
);

void main() {
  test('PUT with the stage, token and company', () async {
    final service = _service((request) async {
      expect(request.method, 'PUT');
      expect(request.url.path, endsWith('/v1/app/orders/o1/stage'));
      expect(request.headers['Authorization'], 'Bearer fake-id-token');
      expect(request.headers['X-Company-Id'], 'c1');
      expect(jsonDecode(request.body), {'stageId': 'polish'});
      return http.Response('{"success":true,"data":{}}', 200);
    });
    await service.setStage('c1', 'o1', 'polish');
  });

  test('a refusal carries the status and the error code', () async {
    final service = _service(
      (request) async => http.Response(
        jsonEncode({
          'success': false,
          'error': {'code': 'STAGE_NOT_ALLOWED', 'message': 'x'},
        }),
        409,
      ),
    );
    await expectLater(
      service.setStage('c1', 'o1', 'polish'),
      throwsA(
        isA<OrderStageApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.code, 'code', 'STAGE_NOT_ALLOWED'),
      ),
    );
  });

  test('no signed-in user never calls the server', () async {
    var called = false;
    final service = OrderStageApiService.withClient(
      MockClient((_) async {
        called = true;
        return http.Response('', 200);
      }),
      tokenProvider: () async => null,
    );
    await expectLater(
      service.setStage('c1', 'o1', 'polish'),
      throwsA(isA<OrderStageApiException>()),
    );
    expect(called, isFalse);
  });
}
