import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/repositories/auth_repository.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Android signs in with Apple through Firebase, not the web flow', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(AuthRepository.usesFirebaseAppleFlow, isTrue);
  });

  test('iPhone keeps the native Apple sheet', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(AuthRepository.usesFirebaseAppleFlow, isFalse);
  });

  test('Apple provider asks for e-mail and name', () {
    expect(AuthRepository.appleProvider().scopes, containsAll(['email', 'name']));
  });
}
