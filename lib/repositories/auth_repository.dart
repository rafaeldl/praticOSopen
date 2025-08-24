import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  static User? currentUser;

  Stream<User?> onAuthStateChanged() {
    return _auth.authStateChanges();
  }

  Future<User> signInWithGoogle() async {
    final GoogleSignInAccount? googleSignInAccount =
        await (_googleSignIn.signIn());
    final GoogleSignInAuthentication? googleSignInAuthentication =
        await googleSignInAccount?.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleSignInAuthentication?.accessToken,
      idToken: googleSignInAuthentication?.idToken,
    );
    final UserCredential authResult =
        await _auth.signInWithCredential(credential);
    final User user = authResult.user!;
    // Checking if email and name is null
    assert(user.email != null);
    assert(user.displayName != null);
    assert(user.photoURL != null);
    assert(!user.isAnonymous);

    final User firebaseUser = _auth.currentUser!;
    assert(user.uid == firebaseUser.uid);

    currentUser = firebaseUser;

    print('signInWithGoogle succeeded: $user');

    return firebaseUser;
  }

  void signOutGoogle() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    currentUser = null;

    print("User Sign Out");
  }
}
