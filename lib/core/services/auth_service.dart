import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/googleapis_auth.dart' as gauth;

class AuthResult {
  final GoogleSignInAccount? user;
  final String? error;
  AuthResult({this.user, this.error});
  bool get isSuccess => user != null;
}

class AuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      'https://www.googleapis.com/auth/drive.file',
      'https://www.googleapis.com/auth/drive.appdata',
    ],
  );

  static GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  static Future<GoogleSignInAccount?> signInSilently() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (e) {
      debugPrint('Silent Google Sign In error: $e');
      return null;
    }
  }

  static Future<AuthResult> signIn() async {
    try {
      final user = await _googleSignIn.signIn();
      if (user == null) {
        return AuthResult(error: 'Sign-in was cancelled.');
      }
      return AuthResult(user: user);
    } on Exception catch (e) {
      final msg = e.toString();
      debugPrint('Google Sign In error: $msg');

      if (msg.contains('ApiException: 12500') || msg.contains('sign_in_failed')) {
        return AuthResult(
          error: 'Google Sign-In is not configured.\n\n'
              'To enable it:\n'
              '1. Create a project at console.cloud.google.com\n'
              '2. Enable Google Sign-In API\n'
              '3. Create an OAuth client ID for Android\n'
              '4. Add the SHA-1 of your debug keystore\n'
              '5. Download google-services.json to android/app/',
        );
      }
      if (msg.contains('network_error') || msg.contains('ApiException: 7')) {
        return AuthResult(error: 'Network error. Check your internet connection.');
      }
      return AuthResult(error: 'Sign-in failed: $msg');
    }
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Google Sign Out error: $e');
    }
  }

  static Future<http.Client?> getAuthClient() async {
    var user = _googleSignIn.currentUser;
    if (user == null) return null;

    var auth = await user.authentication;
    var accessToken = auth.accessToken;

    // Best-effort refresh: if the access token is stale/null, re-authenticate
    // silently once and re-fetch. google_sign_in manages token refresh at the
    // native layer, so signInSilently returns a fresh account/token.
    if (accessToken == null) {
      final refreshed = await signInSilently();
      if (refreshed == null) return null;
      user = refreshed;
      auth = await user.authentication;
      accessToken = auth.accessToken;
    }
    if (accessToken == null) return null;

    // The 1-hour expiry is fabricated; google_sign_in manages the actual
    // refresh at the native layer, so this value is only a hint for the client.
    final credentials = gauth.AccessCredentials(
      gauth.AccessToken('Bearer', accessToken, DateTime.now().toUtc().add(const Duration(hours: 1))),
      null,
      _googleSignIn.scopes,
    );

    return gauth.authenticatedClient(http.Client(), credentials);
  }
}
