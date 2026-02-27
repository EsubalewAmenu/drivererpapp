import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth_platform_interface/src/pigeon/messages.pigeon.dart'
  as auth_pigeon;

class MockGoogleSignIn extends Mock implements GoogleSignIn {}
class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}
class MockGoogleSignInAuthentication extends Mock
  implements GoogleSignInAuthentication {}
class MockAuthClient extends Mock implements AuthClient {}

const _authHostApiPrefix =
    'dev.flutter.pigeon.firebase_auth_platform_interface.FirebaseAuthHostApi.';

final _authPigeonCodec = auth_pigeon.FirebaseAuthHostApi.pigeonChannelCodec;

auth_pigeon.PigeonUserCredential _fakePigeonUserCredential() {
  return auth_pigeon.PigeonUserCredential(
    user: auth_pigeon.PigeonUserDetails(
      userInfo: auth_pigeon.PigeonUserInfo(
        uid: 'uid-1',
        email: 'test@example.com',
        displayName: 'Test User',
        photoUrl: null,
        phoneNumber: null,
        isAnonymous: false,
        isEmailVerified: true,
        providerId: 'google.com',
        tenantId: null,
        refreshToken: 'refresh-token',
        creationTimestamp: 0,
        lastSignInTimestamp: 0,
      ),
      providerData: const [],
    ),
    additionalUserInfo: auth_pigeon.PigeonAdditionalUserInfo(
      isNewUser: false,
      providerId: 'google.com',
      username: null,
      authorizationCode: null,
      profile: const {},
    ),
    credential: auth_pigeon.PigeonAuthCredential(
      providerId: 'google.com',
      signInMethod: 'google.com',
      nativeId: 1,
      accessToken: 'test-access-token',
    ),
  );
}

void _setAuthChannelHandler(String method, Future<Object?> Function(Object?) cb) {
  final channel = BasicMessageChannel<Object?>(
    '$_authHostApiPrefix$method',
    _authPigeonCodec,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockDecodedMessageHandler<Object?>(channel, cb);
}

void _mockFirebaseAuthChannels() {
  _setAuthChannelHandler('registerIdTokenListener', (_) async => <Object?>['id-listener']);
  _setAuthChannelHandler('registerAuthStateListener', (_) async => <Object?>['auth-listener']);
  _setAuthChannelHandler('signInWithCredential', (_) async => <Object?>[_fakePigeonUserCredential()]);
  _setAuthChannelHandler('signOut', (_) async => <Object?>[null]);
}

void _clearFirebaseAuthChannels() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final method in <String>[
    'registerIdTokenListener',
    'registerAuthStateListener',
    'signInWithCredential',
    'signOut',
  ]) {
    final channel = BasicMessageChannel<Object?>(
      '$_authHostApiPrefix$method',
      _authPigeonCodec,
    );
    messenger.setMockDecodedMessageHandler<Object?>(channel, null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthService authService;
  late MockGoogleSignIn mockGoogleSignIn;
  late MockGoogleSignInAccount mockAccount;
  late MockGoogleSignInAuthentication mockAuthentication;
  late MockAuthClient mockAuthClient;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    _mockFirebaseAuthChannels();
  });

  tearDownAll(() {
    _clearFirebaseAuthChannels();
  });

  setUp(() {
    mockGoogleSignIn = MockGoogleSignIn();
    mockAccount = MockGoogleSignInAccount();
    mockAuthentication = MockGoogleSignInAuthentication();
    mockAuthClient = MockAuthClient();
    authService = AuthService(googleSignIn: mockGoogleSignIn);

    when(() => mockAuthentication.accessToken).thenReturn('test-access-token');
    when(() => mockAuthentication.idToken).thenReturn('test-id-token');
    when(() => mockAccount.authentication)
      .thenAnswer((_) async => mockAuthentication);
    
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

    test('signIn handles error', () async {
      when(() => mockGoogleSignIn.signIn()).thenThrow(Exception('Sign-in failed'));

      expect(() => authService.signIn(), throwsException);
    });

    test('signInSilently handles error gracefully', () async {
      when(() => mockGoogleSignIn.signInSilently()).thenThrow(Exception('Silent sign-in failed'));

      // Should not throw, just log in debug mode
      await authService.signInSilently();
      
      expect(authService.currentUser, isNull);
    });
  });
}
