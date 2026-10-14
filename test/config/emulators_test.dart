import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/config/emulators.dart';

void main() {
  test('emulators stay off unless the build asks for them', () async {
    // Normal builds and tests never pass USE_FIREBASE_EMULATORS.
    expect(FirebaseEmulators.enabled, isFalse);
    expect(FirebaseEmulators.host, '127.0.0.1');
    expect(FirebaseEmulators.authPort, 9099);
    expect(FirebaseEmulators.firestorePort, 8080);
    expect(FirebaseEmulators.storagePort, 9199);
    // connect() is a no-op when off (no Firebase app needed).
    await FirebaseEmulators.connect();
  });
}
