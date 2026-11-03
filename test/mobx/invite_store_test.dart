import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/mobx/invite_store.dart';
import 'package:praticos/models/invite.dart';

Invite _invite(String token, {DateTime? expiresAt}) => Invite()
  ..token = token
  ..expiresAt = expiresAt;

void main() {
  group('collectPendingInvites', () {
    test('junta e-mail e telefone sem repetir', () async {
      final invites = await collectPendingInvites(
        email: 'a@b.com',
        phone: '5511999999999',
        byEmail: (_) async => [_invite('1'), _invite('2')],
        byPhone: (_) async => [_invite('2'), _invite('3')],
      );
      expect(invites.map((i) => i.token), ['1', '2', '3']);
    });

    test('tira convites vencidos', () async {
      final invites = await collectPendingInvites(
        email: 'a@b.com',
        phone: null,
        byEmail: (_) async => [
          _invite('1'),
          _invite('2', expiresAt: DateTime(2020)),
        ],
        byPhone: (_) async => [],
      );
      expect(invites.map((i) => i.token), ['1']);
    });

    test('falha no telefone mantém os convites do e-mail', () async {
      final invites = await collectPendingInvites(
        email: 'a@b.com',
        phone: '5511999999999',
        byEmail: (_) async => [_invite('1')],
        byPhone: (_) async => throw Exception('permission-denied'),
      );
      expect(invites.map((i) => i.token), ['1']);
    });

    test('falha no e-mail é propagada', () async {
      await expectLater(
        collectPendingInvites(
          email: 'a@b.com',
          phone: null,
          byEmail: (_) async => throw Exception('permission-denied'),
          byPhone: (_) async => [],
        ),
        throwsException,
      );
    });
  });
}
