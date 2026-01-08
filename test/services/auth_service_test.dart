import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:googleapis_auth/googleapis_auth.dart';

class MockGoogleSignIn extends Mock implements GoogleSignIn {}
class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}
class MockAuthClient extends Mock implements AuthClient {}

void main() {
  late AuthService authService;
  late MockGoogleSignIn mockGoogleSignIn;
  late MockGoogleSignInAccount mockAccount;
  late MockAuthClient mockAuthClient;

  setUp(() {
    mockGoogleSignIn = MockGoogleSignIn();
    mockAccount = MockGoogleSignInAccount();
    mockAuthClient = MockAuthClient();
    authService = AuthService(googleSignIn: mockGoogleSignIn);
    
    // Use the test helper to inject mock client
    authService.clientFactory = (signIn) async => mockAuthClient;
  });

  group('AuthService', () {
    test('initial state', () {
      expect(authService.currentUser, isNull);
      expect(authService.isAuthenticated, isFalse);
    });

    test('signIn success', () async {
      when(() => mockGoogleSignIn.signIn()).thenAnswer((_) async => mockAccount);
      
      await authService.signIn();

      expect(authService.currentUser, mockAccount);
      expect(authService.isAuthenticated, isTrue);
      expect(authService.authClient, mockAuthClient);
    });

    test('signOut success', () async {
      when(() => mockGoogleSignIn.signIn()).thenAnswer((_) async => mockAccount);
      when(() => mockGoogleSignIn.disconnect()).thenAnswer((_) async => null);

      await authService.signIn();
      await authService.signOut();

      expect(authService.currentUser, isNull);
      expect(authService.isAuthenticated, isFalse);
      expect(authService.authClient, isNull);
    });

    test('signInSilently success', () async {
      when(() => mockGoogleSignIn.signInSilently()).thenAnswer((_) async => mockAccount);

      await authService.signInSilently();

      expect(authService.currentUser, mockAccount);
      expect(authService.authClient, mockAuthClient);
    });
  });
}
