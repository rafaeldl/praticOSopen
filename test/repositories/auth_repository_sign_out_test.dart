import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/repositories/auth_repository.dart';

void main() {
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
