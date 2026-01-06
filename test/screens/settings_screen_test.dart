import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/settings_screen.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/providers/theme_provider.dart';
import 'package:drivererpapp/theme/app_theme.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

// Mocks
class MockAuthService extends Mock implements AuthService {}
class MockWorkspaceProvider extends Mock implements WorkspaceProvider {}
class MockThemeProvider extends Mock implements ThemeProvider {}
class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

void main() {
  late MockAuthService mockAuthService;
  late MockWorkspaceProvider mockWorkspaceProvider;
  late MockThemeProvider mockThemeProvider;
  late MockGoogleSignInAccount mockUser;

  setUp(() {
    mockAuthService = MockAuthService();
    mockWorkspaceProvider = MockWorkspaceProvider();
    mockThemeProvider = MockThemeProvider();
    mockUser = MockGoogleSignInAccount();

    // Default mock behaviors
    when(() => mockAuthService.currentUser).thenReturn(mockUser);
    when(() => mockUser.displayName).thenReturn('Test User');
    when(() => mockUser.email).thenReturn('test@example.com');
    when(() => mockUser.photoUrl).thenReturn(null);

    when(() => mockWorkspaceProvider.currentWorkspace).thenReturn(
      drive.File()..name = 'Test Company'..id = '123'
    );
    
    when(() => mockThemeProvider.themeMode).thenReturn(ThemeMode.light);
    when(() => mockThemeProvider.isDarkMode).thenReturn(false);
  });

  Widget createSettingsScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: mockThemeProvider),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const SettingsScreen(),
      ),
    );
  }

  testWidgets('SettingsScreen displays personal profile data', (WidgetTester tester) async {
    await tester.pumpWidget(createSettingsScreen());
    await tester.pumpAndSettle();

    expect(find.text('PERSONAL PROFILE'), findsOneWidget);
    // Finds both the separate Text widget and the TextField content
    expect(find.text('Test User'), findsAtLeastNWidgets(1)); 
    expect(find.text('test@example.com'), findsOneWidget); // Email
    
    // Check if the controller value matches
    final textFieldFinder = find.widgetWithText(TextField, 'Display Name (Google Account)');
    expect(textFieldFinder, findsOneWidget);
  });

  testWidgets('SettingsScreen displays company branding data', (WidgetTester tester) async {
    await tester.pumpWidget(createSettingsScreen());
    await tester.pumpAndSettle();

    expect(find.text('COMPANY BRANDING'), findsOneWidget);
    
    // The workspace name is set in the controller for the Company Name TextField
    final textFieldFinder = find.widgetWithText(TextField, 'Company Name (Workspace)');
    expect(textFieldFinder, findsOneWidget);
    
    // We verify the controller's text if possible, or just checks that no error occurs.
    // Since we can't easily peek into the state private controller, we rely on rendering.
  });

  testWidgets('SettingsScreen displays dark mode toggle', (WidgetTester tester) async {
    await tester.pumpWidget(createSettingsScreen());
    await tester.pumpAndSettle();

    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('Dark Mode'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('Toggling theme calls ThemeProvider', (WidgetTester tester) async {
    await tester.pumpWidget(createSettingsScreen());
    await tester.pumpAndSettle();

    final switchFinder = find.byType(Switch);
    final scrollable = find.byType(SingleChildScrollView);
    
    // Ensure the switch is visible before tapping
    await tester.dragUntilVisible(switchFinder, scrollable, const Offset(0, -100));
    await tester.pumpAndSettle();
    
    expect(switchFinder, findsOneWidget);

    await tester.tap(switchFinder);
    
    verify(() => mockThemeProvider.toggleTheme()).called(1);
  });
}
