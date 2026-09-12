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

    test('list() faz GET com autorização', () async {
      final service = IntegrationApiService.withClient(
        MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, contains('/v1/app/integrations/tokens'));
          expect(request.headers['Authorization'], 'Bearer fake-id-token');
          return http.Response(
            jsonEncode({
              'success': true,
              'data': [
                {
                  'id': 'tok1',
                  'name': 'ChatGPT',
                  'createdAt': '2026-09-12T10:00:00.000Z',
                  'lastUsedAt': null,
                  'expiresAt': '2026-12-11T10:00:00.000Z',
                }
              ],
            }),
            200,
          );
        }),
        tokenProvider: () async => 'fake-id-token',
      );

      final tokens = await service.list();

      expect(tokens, hasLength(1));
      expect(tokens.first.name, 'ChatGPT');
      expect(tokens.first.lastUsedAt, isNull);
    });

    test('create() faz POST com 201 e retorna url', () async {
      final service = IntegrationApiService.withClient(
        MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, contains('/v1/app/integrations/tokens'));
          expect(request.headers['Authorization'], 'Bearer fake-id-token');
          expect(request.body, jsonEncode({'name': 'Meu ChatGPT'}));
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 'tok1',
                'url': 'https://praticos.web.app/mcp/t/mcp_abc',
                'expiresAt': '2026-12-11T10:00:00.000Z',
              },
            }),
            201,
          );
        }),
        tokenProvider: () async => 'fake-id-token',
      );

      final created = await service.create(name: 'Meu ChatGPT');

      expect(created.url, 'https://praticos.web.app/mcp/t/mcp_abc');
    });

    test('revoke() faz DELETE', () async {
      final service = IntegrationApiService.withClient(
        MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(request.url.path, contains('/v1/app/integrations/tokens/tok1'));
          expect(request.headers['Authorization'], 'Bearer fake-id-token');
          return http.Response(
            jsonEncode({'success': true}),
            200,
          );
        }),
        tokenProvider: () async => 'fake-id-token',
      );

      await service.revoke('tok1');
      // Test passes if no exception is thrown
    });

    test('revoke() com 404 lança exceção com code NOT_FOUND', () async {
      final service = IntegrationApiService.withClient(
        MockClient((_) async => http.Response(
          jsonEncode({
            'success': false,
            'error': {
              'code': 'NOT_FOUND',
              'message': 'Token not found',
            }
          }),
          404,
        )),
        tokenProvider: () async => 'fake-id-token',
      );

      expect(
        () => service.revoke('nonexistent'),
        throwsA(
          isA<IntegrationApiException>()
              .having((e) => e.code, 'code', 'NOT_FOUND'),
        ),
      );
    });

    test('403 lança exceção com code FORBIDDEN', () async {
      final service = IntegrationApiService.withClient(
        MockClient((_) async => http.Response(
          jsonEncode({
            'success': false,
            'error': {
              'code': 'FORBIDDEN',
              'message': 'Sem permissão',
            }
          }),
          403,
        )),
        tokenProvider: () async => 'fake-id-token',
      );

      expect(
        () => service.create(name: 'X'),
        throwsA(
          isA<IntegrationApiException>()
              .having((e) => e.code, 'code', 'FORBIDDEN'),
        ),
      );
    });

    test('corpo HTML não JSON com 502 lança exceção com code null', () async {
      final service = IntegrationApiService.withClient(
        MockClient((_) async => http.Response(
          '<html><body>Bad Gateway</body></html>',
          502,
        )),
        tokenProvider: () async => 'fake-id-token',
      );

      expect(
        () => service.list(),
        throwsA(
          isA<IntegrationApiException>()
              .having((e) => e.code, 'code', isNull)
              .having((e) => e.message, 'message', 'Request failed (502)'),
        ),
      );
    });

    test('corpo vazio com 502 lança exceção com code null', () async {
      final service = IntegrationApiService.withClient(
        MockClient((_) async => http.Response('', 502)),
        tokenProvider: () async => 'fake-id-token',
      );

      expect(
        () => service.list(),
        throwsA(
          isA<IntegrationApiException>()
              .having((e) => e.code, 'code', isNull),
        ),
      );
    });

    test('tokenProvider null lança com code UNAUTHENTICATED', () async {
      final service = IntegrationApiService.withClient(
        MockClient((_) async => throw 'Should not make HTTP request'),
        tokenProvider: () async => null,
      );

      expect(
        () => service.list(),
        throwsA(
          isA<IntegrationApiException>()
              .having((e) => e.code, 'code', 'UNAUTHENTICATED'),
        ),
      );
    });
  });
}
