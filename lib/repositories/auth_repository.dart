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
    print('🔑 signInWithGoogle() called');

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
      // currentUser must carry the name before the user document is filled.
      await user.reload();
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

  /// Signs out of Google and Firebase. Firebase sign-out runs even if the
  /// Google one fails (e.g. the user never used Google).
  Future<void> signOutGoogle() async {
    await signOutAll(
      google: () => _googleSignIn.signOut(),
      firebase: () => _auth.signOut(),
    );
    currentUser = null;

    print("User Sign Out");
  }

  /// Runs [google] then [firebase]; a [google] failure is ignored, a
  /// [firebase] failure propagates.
  static Future<void> signOutAll({
    required Future<void> Function() google,
    required Future<void> Function() firebase,
  }) async {
    try {
      await google();
    } catch (e) {
      print('Google sign-out failed: $e');
    }
    await firebase();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// First provider of [providerIds] the app can re-authenticate with. Linked
  /// providers like `phone` are skipped; null when none is supported.
  static String? reauthProviderId(Iterable<String> providerIds) {
    const supported = {'google.com', 'apple.com', 'password'};
    return providerIds.where(supported.contains).firstOrNull;
  }

  bool get reauthNeedsPassword {
    final providerData = _auth.currentUser?.providerData ?? const [];
    return reauthProviderId(providerData.map((p) => p.providerId)) ==
        'password';
  }

  /// Re-authenticates the current user with the password of their account.
  Future<void> reauthenticateWithPassword(String password) async {
    final User? user = _auth.currentUser;
    final String? email = user?.email;
    if (user == null || email == null) {
      throw Exception('No authenticated user to reauthenticate');
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
  }

  /// Re-authenticates the current user with their provider (Google or Apple)
  /// This is required before sensitive operations like account deletion.
  /// Password accounts use [reauthenticateWithPassword].
  Future<void> reauthenticate() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user to reauthenticate');
    }

    // Check which provider the user used to sign in
    final providerData = user.providerData;
    if (providerData.isEmpty) {
      throw Exception('No provider data found for user');
    }

    final providerId =
        reauthProviderId(providerData.map((p) => p.providerId));

    try {
      if (providerId == 'google.com') {
        // Re-authenticate with Google
        final GoogleSignInAccount? googleSignInAccount = await _googleSignIn.signIn();
        if (googleSignInAccount == null) {
          throw Exception('Login cancelado pelo usuário');
        }

        final GoogleSignInAuthentication googleSignInAuthentication =
            await googleSignInAccount.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleSignInAuthentication.accessToken,
          idToken: googleSignInAuthentication.idToken,
        );

        await user.reauthenticateWithCredential(credential);
        print('✅ Re-authentication with Google successful');
      } else if (providerId == 'apple.com') {
        // Re-authenticate with Apple
        final rawNonce = _generateNonce();
        final nonce = _sha256ofString(rawNonce);

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

        final OAuthCredential credential = OAuthProvider("apple.com").credential(
          idToken: appleIdCredential.identityToken,
          accessToken: appleIdCredential.authorizationCode,
          rawNonce: rawNonce,
        );

        await user.reauthenticateWithCredential(credential);
        print('✅ Re-authentication with Apple successful');
      } else {
        throw Exception('Unsupported provider: $providerId');
      }
    } catch (e) {
      print('❌ Re-authentication failed: $e');
      rethrow;
    }
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
