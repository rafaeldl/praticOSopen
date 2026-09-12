import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:praticos/services/integration_api_service.dart';

void main() {
  group('IntegrationApiService', () {
    test('parseia a lista de tokens', () {
      final body = jsonEncode({
        'success': true,
        'data': [
          {
            'id': 'tok1',
            'name': 'Meu ChatGPT',
            'createdAt': '2026-09-12T10:00:00.000Z',
            'lastUsedAt': null,
            'expiresAt': '2026-12-11T10:00:00.000Z',
          }
        ],
      });

      final tokens = IntegrationApiService.parseList(body);

      expect(tokens, hasLength(1));
      expect(tokens.first.name, 'Meu ChatGPT');
      expect(tokens.first.lastUsedAt, isNull);
    });

    test('parseia o token criado', () {
      final body = jsonEncode({
        'success': true,
        'data': {
          'id': 'tok1',
          'token': 'mcp_abc',
          'url': 'https://praticos.web.app/mcp/t/mcp_abc',
          'expiresAt': '2026-12-11T10:00:00.000Z',
        },
      });

      final created = IntegrationApiService.parseCreated(body);

      expect(created.url, 'https://praticos.web.app/mcp/t/mcp_abc');
    });

    test('lança exceção quando a API responde erro', () async {
      final service = IntegrationApiService.withClient(
        MockClient((_) async => http.Response(
              jsonEncode({
                'success': false,
                'error': {'code': 'FORBIDDEN', 'message': 'Sem permissão'}
              }),
              403,
            )),
        tokenProvider: () async => 'fake-id-token',
      );

      expect(
        () => service.create(name: 'X'),
        throwsA(isA<IntegrationApiException>()),
      );
    });
  });
}
