import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/collaborator_exception.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/services/team_api_service.dart';

http.Response _error(int status, String code) => http.Response(
      jsonEncode({
        'success': false,
        'error': {'code': code, 'message': code},
      }),
      status,
    );

TeamApiService _service(Future<http.Response> Function(http.Request) handler) =>
    TeamApiService.withClient(
      MockClient(handler),
      tokenProvider: () async => 'fake-id-token',
    );

Future<CollaboratorErrorCode> _codeOf(Future<void> call) async {
  try {
    await call;
  } on CollaboratorException catch (e) {
    return e.code;
  }
  fail('expected a CollaboratorException');
}

void main() {
  setUp(() => Global.companyAggr = CompanyAggr()..id = 'c1');
  tearDown(() => Global.companyAggr = null);

  group('TeamApiService', () {
    test('changeRole faz PATCH com o papel, token e empresa', () async {
      final service = _service((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, endsWith('/v1/app/team/members/u1'));
        expect(request.headers['Authorization'], 'Bearer fake-id-token');
        expect(request.headers['X-Company-Id'], 'c1');
        expect(jsonDecode(request.body), {'role': 'manager'});
        return http.Response(jsonEncode({'success': true}), 200);
      });

      await service.changeRole('u1', RolesType.manager);
    });

    test('removeMember faz DELETE no membro', () async {
      final service = _service((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, endsWith('/v1/app/team/members/u1'));
        return http.Response(jsonEncode({'success': true}), 200);
      });

      await service.removeMember('u1');
    });

    test('dono protegido vira cannotChangeOwner', () async {
      final service = _service((_) async => _error(403, 'OWNER_PROTECTED'));
      expect(await _codeOf(service.changeRole('u1', RolesType.technician)),
          CollaboratorErrorCode.cannotChangeOwner);
      expect(await _codeOf(service.removeMember('u1')),
          CollaboratorErrorCode.cannotChangeOwner);
    });

    test('último admin vira a mensagem da ação certa', () async {
      final service = _service((_) async => _error(409, 'LAST_ADMIN'));
      expect(await _codeOf(service.changeRole('u1', RolesType.manager)),
          CollaboratorErrorCode.cannotChangeOnlyAdminRole);
      expect(await _codeOf(service.removeMember('u1')),
          CollaboratorErrorCode.cannotRemoveOnlyAdmin);
    });

    test('membro inexistente, sem permissão e falha genérica', () async {
      expect(
          await _codeOf(_service((_) async => _error(404, 'MEMBER_NOT_FOUND'))
              .removeMember('u1')),
          CollaboratorErrorCode.userNotFound);
      expect(
          await _codeOf(
              _service((_) async => _error(403, 'INSUFFICIENT_PERMISSIONS'))
                  .removeMember('u1')),
          CollaboratorErrorCode.notAllowed);
      expect(
          await _codeOf(_service((_) async => http.Response('boom', 500))
              .removeMember('u1')),
          CollaboratorErrorCode.requestFailed);
    });

    test('sem usuário logado vira requestFailed sem chamar o servidor',
        () async {
      final service = TeamApiService.withClient(
        MockClient((_) async => fail('não deveria chamar o servidor')),
        tokenProvider: () async => null,
      );
      expect(await _codeOf(service.removeMember('u1')),
          CollaboratorErrorCode.requestFailed);
    });
  });
}
