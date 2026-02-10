import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis_auth/googleapis_auth.dart';

class AuthService extends ChangeNotifier {
  final GoogleSignIn _googleSignIn;
  
  // Test helper to allow mocking client creation
  @visibleForTesting
  Future<AuthClient?> Function(GoogleSignIn)? clientFactory;

  AuthService({GoogleSignIn? googleSignIn}) 
      : _googleSignIn = googleSignIn ?? GoogleSignIn(
          scopes: [
            'email',
            'https://www.googleapis.com/auth/drive.readonly',
            'https://www.googleapis.com/auth/drive.file',
          ],
        );

  GoogleSignInAccount? _currentUser;
  AuthClient? _authClient;

  GoogleSignInAccount? get currentUser => _currentUser;
  AuthClient? get authClient => _authClient;
  bool get isAuthenticated => _currentUser != null;

  Future<void> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        _currentUser = account;
        if (clientFactory != null) {
          _authClient = await clientFactory!(_googleSignIn);
        } else {
          _authClient = await _googleSignIn.authenticatedClient();
        }
        notifyListeners();
      }
    } catch (error) {
      if (kDebugMode) {
        print('Google Sign-In Error: $error');
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.disconnect();
    _currentUser = null;
    _authClient = null;
    notifyListeners();
  }

  Future<void> signInSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        _currentUser = account;
        if (clientFactory != null) {
          _authClient = await clientFactory!(_googleSignIn);
        } else {
          _authClient = await _googleSignIn.authenticatedClient();
        }
        notifyListeners();
      }
    } catch (error) {
      if (kDebugMode) {
        print('Silent Sign-In Error: $error');
      }
    }
  }
}
