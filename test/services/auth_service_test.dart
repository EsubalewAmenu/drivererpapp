import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:drivererpapp/services/auth_service.dart';

class MockGoogleSignIn extends Mock implements GoogleSignIn {}
class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}
class MockAuthClient extends Mock implements AuthClient {}

void main() {
  late AuthService authService;
  late MockGoogleSignIn mockGoogleSignIn;
  late MockGoogleSignInAccount mockAccount;

  setUp(() {
    mockGoogleSignIn = MockGoogleSignIn();
    mockAccount = MockGoogleSignInAccount();
    authService = AuthService(googleSignIn: mockGoogleSignIn);
  });

  test('Initial state is unauthenticated', () {
    expect(authService.isAuthenticated, false);
    expect(authService.currentUser, null);
    expect(authService.authClient, null);
  });

  test('signIn success sets user', () async {
    when(() => mockGoogleSignIn.signIn()).thenAnswer((_) async => mockAccount);
    
    // Use factory to return a mock client
    authService.clientFactory = (gs) async => MockAuthClient();
    
    await authService.signIn();
    
    verify(() => mockGoogleSignIn.signIn()).called(1);
    expect(authService.currentUser, mockAccount);
    expect(authService.authClient, isNotNull);
  });

  test('signInSilently success sets user', () async {
    when(() => mockGoogleSignIn.signInSilently()).thenAnswer((_) async => mockAccount);
    
    authService.clientFactory = (gs) async => MockAuthClient();
    
    await authService.signInSilently();
    
    verify(() => mockGoogleSignIn.signInSilently()).called(1);
    expect(authService.currentUser, mockAccount);
    expect(authService.authClient, isNotNull);
    
  });

  
  test('signOut clears user', () async {
    when(() => mockGoogleSignIn.disconnect()).thenAnswer((_) async => mockAccount);
    
    await authService.signOut();
    
    expect(authService.currentUser, null);
    expect(authService.authClient, null);
    verify(() => mockGoogleSignIn.disconnect()).called(1);
  });
}
