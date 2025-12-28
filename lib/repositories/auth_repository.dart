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
        // TODO: Update with your Service ID from Apple Developer Portal
        clientId: 'br.com.rafsoft.praticos.app',
        // TODO: Update with your Callback URL from Firebase Console
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

  void signOutGoogle() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    currentUser = null;

    print("User Sign Out");
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
