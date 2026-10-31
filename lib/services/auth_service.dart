import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'backend/backend_config.dart';
import 'backend/backend_session.dart';

class AuthService extends ChangeNotifier {
  final GoogleSignIn _googleSignIn;
  @visibleForTesting
  Future<http.Client?> Function(GoogleSignIn)? clientFactory;
  AuthService({GoogleSignIn? googleSignIn})
    : _googleSignIn =
          googleSignIn ??
          GoogleSignIn(
            scopes: ['email', 'profile'],
            clientId: defaultTargetPlatform == TargetPlatform.iOS
                ? '810073225620-28flcuta49lvm41bpk7img816snuumf8.apps.googleusercontent.com'
                : null,
            serverClientId: BackendConfig.googleClientId,
          );
  GoogleSignInAccount? _currentUser;
  http.Client? _authClient;
  GoogleSignInAccount? get currentUser => _currentUser;
  http.Client? get authClient => _authClient;
  bool get isAuthenticated => _currentUser != null && _authClient != null;

  Future<void> _connect(GoogleSignInAccount account) async {
    http.Client? client;
    if (clientFactory != null) {
      client = await clientFactory!(_googleSignIn);
    } else {
      final identity = await account.authentication;
      if (identity.idToken == null) {
        throw StateError(
          'Google did not return an ID token. Check the Google OAuth client configuration.',
        );
      }
      await BackendSession.login(identity.idToken!);
      client = http.Client();
    }
    if (client == null) {
      throw StateError('Backend connection could not be established');
    }
    _authClient?.close();
    _authClient = client;
    _currentUser = account;
    notifyListeners();
  }

  Future<void> signIn() async {
    final account = await _googleSignIn.signIn();
    if (account != null) await _connect(account);
  }

  Future<void> signOut() async {
    try {
      await BackendSession.logout();
    } catch (_) {
      /* Local logout works offline. */
    }
    try {
      await _googleSignIn.disconnect();
    } finally {
      _authClient?.close();
      _authClient = null;
      _currentUser = null;
      notifyListeners();
    }
  }

  Future<void> signInSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) await _connect(account);
    } catch (error) {
      debugPrint('Silent sign-in unavailable: $error');
    }
  }

  Future<bool> refreshSession() async {
    try {
      final account = await _googleSignIn.signInSilently(
        suppressErrors: false,
        reAuthenticate: true,
      );
      if (account == null) return false;
      await _connect(account);
      return true;
    } catch (_) {
      return false;
    }
  }
}
