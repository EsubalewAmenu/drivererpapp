import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/landing_screen.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';

class MockAuthService extends Mock implements AuthService {}
class MockWorkspaceProvider extends Mock implements WorkspaceProvider {}

void main() {
  late MockAuthService mockAuthService;
  late MockWorkspaceProvider mockWorkspaceProvider;

  setUp(() {
    mockAuthService = MockAuthService();
    mockWorkspaceProvider = MockWorkspaceProvider();

    // Default behaviors
    when(() => mockAuthService.isAuthenticated).thenReturn(false);
    when(() => mockAuthService.signInSilently()).thenAnswer((_) async {});
  });

  Widget createLandingScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
      ],
      child: const MaterialApp(
        home: LandingScreen(),
      ),
    );
  }

  testWidgets('LandingScreen should show branding and sign-in button', (WidgetTester tester) async {
    await tester.pumpWidget(createLandingScreen());

    // Check for branding text
    expect(find.text('DRIVE ERP'), findsOneWidget);
    expect(find.text('Your Business. Your Drive. Your Data.'), findsOneWidget);

    // Check for sign-in button
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byIcon(Icons.login_rounded), findsOneWidget);
  });

  testWidgets('LandingScreen should call signIn on button press', (WidgetTester tester) async {
    when(() => mockAuthService.signIn()).thenAnswer((_) async {});

    await tester.pumpWidget(createLandingScreen());

    final signInButton = find.text('Continue with Google');
    await tester.tap(signInButton);
    await tester.pump();

    verify(() => mockAuthService.signIn()).called(1);
  });

  testWidgets('LandingScreen should show trust indicators', (WidgetTester tester) async {
    await tester.pumpWidget(createLandingScreen());

    expect(find.text('No External Database'), findsOneWidget);
    expect(find.text('Sovereign Ownership'), findsOneWidget);
  });
}
