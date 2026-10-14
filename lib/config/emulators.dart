import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Local Firebase emulators for testing on the simulator without touching
/// production. Build with `--dart-define=USE_FIREBASE_EMULATORS=true` and run
/// `firebase emulators:start` in `firebase/` (ports in `firebase.json`).
class FirebaseEmulators {
  static const enabled = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
  static const host = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );
  static const authPort = 9099;
  static const firestorePort = 8080;
  static const storagePort = 9199;

  /// Points Auth, Firestore and Storage at the emulators. No-op unless [enabled].
  static Future<void> connect() async {
    if (!enabled) return;
    final auth = FirebaseAuth.instance;
    await auth.useAuthEmulator(host, authPort);
    FirebaseFirestore.instance.useFirestoreEmulator(host, firestorePort);
    await FirebaseStorage.instance.useStorageEmulator(host, storagePort);
    // The keychain may still hold a real (production) session. The emulator
    // can't refresh it, so drop it and sign in with an emulator account.
    if (auth.currentUser != null && !await isEmulatorSession(auth)) {
      await auth.signOut();
    }
  }

  static Future<bool> isEmulatorSession(FirebaseAuth auth) async {
    try {
      await auth.currentUser?.getIdToken(true);
      return true;
    } catch (_) {
      return false;
    }
  }
}
