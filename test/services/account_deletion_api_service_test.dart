import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:praticos/services/account_deletion_api_service.dart';

const _headers = {'Authorization': 'Bearer fake-id-token'};

AccountDeletionApiService _service(
  MockClientHandler handler, {
  Duration timeout = const Duration(seconds: 120),
}) =>
    AccountDeletionApiService.withClient(
      MockClient(handler),
      headersProvider: () async => Map.of(_headers),
      timeout: timeout,
      baseUrl: 'https://api.test',
    );

http.Response _error(String code, String message, int status) =>
    http.Response(
      jsonEncode({
        'success': false,
        'error': {'code': code, 'message': message},
      }),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  group('AccountDeletionApiService', () {
    test('faz DELETE em /v1/app/account com o token e conclui no 200',
        () async {
      late http.Request sent;
      final service = _service((request) async {
        sent = request;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'deletedCompanies': 1, 'leftCompanies': 0},
          }),
          200,
        );
      });

      await service.deleteAccount();

      expect(sent.method, 'DELETE');
      expect(sent.url.toString(), 'https://api.test/v1/app/account');
      expect(sent.headers['Authorization'], 'Bearer fake-id-token');
      expect(sent.body, isEmpty);
    });

    test('401 REQUIRES_RECENT_LOGIN vira Exception(REQUIRES_RECENT_LOGIN)',
        () async {
      final service = _service((_) async =>
          _error('REQUIRES_RECENT_LOGIN', 'Recent sign-in is required', 401));

      await expectLater(
        service.deleteAccount(),
        throwsA(predicate((e) =>
            e is Exception && e.toString().contains('REQUIRES_RECENT_LOGIN'))),
      );
    });

    test('409 COMPANY_HAS_MEMBERS traz a mensagem em português', () async {
      final service = _service((_) async => _error(
          'COMPANY_HAS_MEMBERS',
          AccountDeletionApiService.companyHasMembersMessage,
          409));

      await expectLater(
        service.deleteAccount(),
        throwsA(predicate((e) => e.toString().contains(
            'proprietário de uma empresa com outros membros'))),
      );
    });

    test('outro 401 (token inválido) não pede reautenticação', () async {
      final service =
          _service((_) async => _error('UNAUTHORIZED', 'Invalid token', 401));

      await expectLater(
        service.deleteAccount(),
        throwsA(isA<AccountDeletionApiException>()
            .having((e) => e.code, 'code', 'UNAUTHORIZED')
            .having((e) => e.toString(), 'text',
                isNot(contains('REQUIRES_RECENT_LOGIN')))),
      );
    });

    test('timeout vira ACCOUNT_DELETION_TIMEOUT (sem "network")', () async {
      final service = _service(
        (_) => Completer<http.Response>().future,
        timeout: const Duration(milliseconds: 10),
      );

      await expectLater(
        service.deleteAccount(),
        throwsA(isA<AccountDeletionApiException>()
            .having((e) => e.code, 'code', AccountDeletionApiService.timeoutCode)
            .having((e) => e.toString(), 'text', isNot(contains('network')))),
      );
    });

    test('falha de conexão vira erro de rede', () async {
      final service =
          _service((_) async => throw http.ClientException('offline'));

      await expectLater(
        service.deleteAccount(),
        throwsA(isA<AccountDeletionApiException>()
            .having((e) => e.code, 'code', 'NETWORK_ERROR')
            .having((e) => e.toString(), 'text', contains('network'))),
      );
    });

    test('409 OWNERSHIP_MISMATCH traz a mensagem do servidor (suporte)',
        () async {
      const msg = 'Não foi possível confirmar quem é o proprietário de uma das '
          'suas empresas. Fale com o suporte do PraticOS para excluir sua conta.';
      final service =
          _service((_) async => _error('OWNERSHIP_MISMATCH', msg, 409));

      await expectLater(
        service.deleteAccount(),
        throwsA(predicate((e) =>
            e.toString().contains('Fale com o suporte') &&
            !e.toString().contains('outros membros'))),
      );
    });

    test('sem usuário logado não chama a API', () async {
      var called = false;
      final service = AccountDeletionApiService.withClient(
        MockClient((_) async {
          called = true;
          return http.Response('{}', 200);
        }),
        headersProvider: () async => throw Exception('no user'),
      );

      await expectLater(
        service.deleteAccount(),
        throwsA(isA<AccountDeletionApiException>()
            .having((e) => e.code, 'code', 'UNAUTHENTICATED')),
      );
      expect(called, isFalse);
    });
  });

  group('AccountDeletionApiService.mapError', () {
    test('409 sem mensagem usa o texto padrão', () {
      final e = AccountDeletionApiService.mapError(409, 'not json');
      expect(e.toString(),
          contains(AccountDeletionApiService.companyHasMembersMessage));
    });

    test('500 vira AccountDeletionApiException com o código', () {
      final e = AccountDeletionApiService.mapError(
          500,
          jsonEncode({
            'success': false,
            'error': {'code': 'INTERNAL_ERROR', 'message': 'Unexpected error'},
          }));
      expect(e, isA<AccountDeletionApiException>());
      expect((e as AccountDeletionApiException).code, 'INTERNAL_ERROR');
    });
  });
}
