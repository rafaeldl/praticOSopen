import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/repositories/auth_repository.dart';

void main() {
  group('AuthRepository.reauthProviderId', () {
    test('pula o telefone vinculado', () {
      expect(
        AuthRepository.reauthProviderId(['phone', 'google.com']),
        'google.com',
      );
    });

    test('conta de e-mail usa a senha', () {
      expect(AuthRepository.reauthProviderId(['password']), 'password');
    });

    test('nenhum provedor suportado', () {
      expect(AuthRepository.reauthProviderId(['phone']), isNull);
    });
  });

  group('AuthRepository.signOutAll', () {
    test('faz sign-out do Google e depois do Firebase', () async {
      final calls = <String>[];
      await AuthRepository.signOutAll(
        google: () async => calls.add('google'),
        firebase: () async => calls.add('firebase'),
      );
      expect(calls, ['google', 'firebase']);
    });

    test('Firebase sai mesmo se o Google falhar', () async {
      final calls = <String>[];
      await AuthRepository.signOutAll(
        google: () async => throw Exception('google down'),
        firebase: () async => calls.add('firebase'),
      );
      expect(calls, ['firebase']);
    });

    test('falha do Firebase é propagada', () async {
      await expectLater(
        AuthRepository.signOutAll(
          google: () async {},
          firebase: () async => throw Exception('firebase down'),
        ),
        throwsException,
      );
    });
  });
}
