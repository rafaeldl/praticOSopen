import 'dart:async';

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  static User? currentUser;

  Stream<User?> onAuthStateChanged() {
    return _auth.authStateChanges();
  }

  Future<User> signInWithGoogle() async {
    // Desconecta sessão anterior para permitir escolher outra conta
    // Isso é especialmente útil no simulador iOS
    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      // Ignora erro se não havia sessão anterior
    }

    final GoogleSignInAccount? googleSignInAccount =
        await (_googleSignIn.signIn());

    if (googleSignInAccount == null) {
      throw Exception('Login cancelado pelo usuário');
    }

    final GoogleSignInAuthentication googleSignInAuthentication =
        await googleSignInAccount.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleSignInAuthentication.accessToken,
      idToken: googleSignInAuthentication.idToken,
    );
    final UserCredential authResult =
        await _auth.signInWithCredential(credential);
    final User user = authResult.user!;
    // Checking if email and name is null
    assert(user.email != null);
    assert(user.displayName != null);
    assert(!user.isAnonymous);

    final User firebaseUser = _auth.currentUser!;
    assert(user.uid == firebaseUser.uid);

    currentUser = firebaseUser;

    print('signInWithGoogle succeeded: $user');

    return firebaseUser;
  }

  Future<User> signInWithApple() async {
    // Generate a nonce for the request
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    // Perform the Sign In request
    final appleIdCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
      webAuthenticationOptions: WebAuthenticationOptions(
        clientId: 'br.com.rafsoft.praticos.app',
        redirectUri: Uri.parse(
          'https://praticos.firebaseapp.com/__/auth/handler',
        ),
      ),
    );

    // Create an OAuth Credential for Firebase
    final OAuthCredential credential = OAuthProvider("apple.com").credential(
      idToken: appleIdCredential.identityToken,
      accessToken: appleIdCredential.authorizationCode,
      rawNonce: rawNonce,
    );

    // Sign in to Firebase
    final UserCredential authResult =
        await _auth.signInWithCredential(credential);
    final User user = authResult.user!;

    // Apple doesn't always return the name/email on subsequent logins,
    // so we might want to update the profile if available from the Apple credential
    if (appleIdCredential.givenName != null) {
      await user.updateDisplayName(
          "${appleIdCredential.givenName} ${appleIdCredential.familyName ?? ''}"
              .trim());
    }

    final User firebaseUser = _auth.currentUser!;
    currentUser = firebaseUser;

    print('signInWithApple succeeded: $user');

    return firebaseUser;
  }

  Future<User> signInWithEmailPassword(String email, String password) async {
    final UserCredential authResult = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final User user = authResult.user!;

    final User firebaseUser = _auth.currentUser!;
    currentUser = firebaseUser;

    print('signInWithEmailPassword succeeded: $user');

    return firebaseUser;
  }

  void signOutGoogle() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    currentUser = null;

    print("User Sign Out");
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Deletes the current user's account from Firebase Auth.
  /// Note: Firestore data cleanup should be handled separately via Cloud Functions
  /// or before calling this method, as this only deletes the authentication account.
  Future<void> deleteAccount() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user to delete');
    }

    // Delete the Firebase Auth account
    await user.delete();

    // Sign out from Google if applicable
    await _googleSignIn.signOut();

    currentUser = null;
    print("User account deleted");
  }

  String _generateNonce([int length = 32]) {
    final charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
