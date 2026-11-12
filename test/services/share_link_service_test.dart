import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:praticos/services/api_headers.dart';
import 'package:praticos/services/share_link_service.dart';

void main() {
  // Without X-Company-Id the server uses the user's first company, and an
  // order of any other company answers "Order not found".
  test('every share call sends the selected company', () async {
    final seen = <String, String?>{};
    final client = MockClient((request) async {
      seen['${request.method} ${request.url.path}'] =
          request.headers['X-Company-Id'];
      if (request.method == 'POST') {
        return http.Response(
          '{"success":true,"data":{"token":"ST_1","url":"https://praticos.app/q/ST_1","permissions":["view"]}}',
          201,
        );
      }
      return http.Response('{"success":true,"data":[]}', 200);
    });
    final service = ShareLinkService.forTesting(
      client: client,
      headers: () => appApiHeaders(
        companyId: 'c2',
        tokenProvider: () async => 'id-token',
      ),
    );

    await service.getShareTokens('o1');
    final result = await service.generateShareLink(orderId: 'o1');
    await service.revokeShareToken('o1', 'ST_1');

    expect(result.token, 'ST_1');
    expect(seen, {
      'GET /api/v1/app/orders/o1/share': 'c2',
      'POST /api/v1/app/orders/o1/share': 'c2',
      'DELETE /api/v1/app/orders/o1/share/ST_1': 'c2',
    });
  });

  test('without a signed-in user the call fails before the network', () async {
    var calls = 0;
    final service = ShareLinkService.forTesting(
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
      headers: () => appApiHeaders(tokenProvider: () async => null),
    );

    expect(
      () => service.generateShareLink(orderId: 'o1'),
      throwsA(isA<ShareLinkException>()),
    );
    expect(calls, 0);
  });

  test('the PDF message without a link does not promise one', () {
    final service = ShareLinkService.forTesting();
    expect(
      service.buildShareMessage(
        customerName: 'Ana',
        orderNumber: 183,
        withPdf: true,
        withLink: false,
      ),
      'Olá Ana! Segue a sua OS #183 em PDF.',
    );
  });
}
