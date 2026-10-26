import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/collaborator_store.dart';
import 'package:praticos/models/collaborator_exception.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/membership.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/services/team_api_service.dart';

/// The store must change roles and remove members through the server
/// (/v1/app/team), never by writing users/{colleague} (issue #457).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CollaboratorStore store;
  late List<String> calls;

  setUpAll(() async {
    // CollaboratorStore holds a Firestore instance in a field.
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    Global.companyAggr = CompanyAggr()..id = 'c1';
    calls = [];
    store = CollaboratorStore.instance
      ..teamApi = TeamApiService.withClient(
        MockClient((request) async {
          calls.add('${request.method} ${request.url.path.split('/v1/app/').last}');
          return http.Response('{"success":true}', 200);
        }),
        tokenProvider: () async => 'fake-id-token',
      );
    store.collaborators
      ..clear()
      ..addAll([
        Membership(userId: 'a1', role: RolesType.admin),
        Membership(userId: 't1', role: RolesType.technician),
      ]);
  });

  tearDown(() {
    Global.companyAggr = null;
    store.teamApi = TeamApiService.instance;
  });

  test('updateCollaboratorRole chama PATCH /v1/app/team', () async {
    await store.updateCollaboratorRole('t1', RolesType.manager);
    expect(calls, ['PATCH team/members/t1']);
  });

  test('removeCollaborator chama DELETE /v1/app/team', () async {
    await store.removeCollaborator('t1');
    expect(calls, ['DELETE team/members/t1']);
  });

  test('não chama o servidor para rebaixar o único admin', () async {
    await expectLater(
      store.updateCollaboratorRole('a1', RolesType.manager),
      throwsA(isA<CollaboratorException>().having(
          (e) => e.code, 'code', CollaboratorErrorCode.cannotChangeOnlyAdminRole)),
    );
    expect(calls, isEmpty);
  });

  test('recusa do servidor chega como CollaboratorException', () async {
    store.teamApi = TeamApiService.withClient(
      MockClient((_) async => http.Response(
          '{"success":false,"error":{"code":"OWNER_PROTECTED"}}', 403)),
      tokenProvider: () async => 'fake-id-token',
    );
    await expectLater(
      store.removeCollaborator('t1'),
      throwsA(isA<CollaboratorException>().having(
          (e) => e.code, 'code', CollaboratorErrorCode.cannotChangeOwner)),
    );
  });
}
