import 'package:drivererpapp/providers/theme_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/screens/settings_screen.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:drivererpapp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    SharedPreferences.setMockInitialValues({
      'module_config_1': 'data',
      'module_meta_1': 'meta',
      'other_key': 'value'
    });

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
        scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
      ),
    );
  }

  group('SettingsScreen', () {
    testWidgets('displays personal profile data', (WidgetTester tester) async {
      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      expect(find.text('PERSONAL PROFILE'), findsOneWidget);
      expect(find.text('Test User'), findsAtLeastNWidgets(1)); 
      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('displays company branding data', (WidgetTester tester) async {
      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      expect(find.text('COMPANY BRANDING'), findsOneWidget);
    });

    testWidgets('displays dark mode toggle', (WidgetTester tester) async {
      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      expect(find.text('APPEARANCE'), findsOneWidget);
    });

    testWidgets('displays storage settings and clears cache', (WidgetTester tester) async {
      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      // Scroll to find Storage section
      final storageHeader = find.text('STORAGE');
      await tester.ensureVisible(storageHeader);
      expect(storageHeader, findsOneWidget);
      expect(find.text('MANAGE CACHE'), findsOneWidget);

      // Verify cache count logic in dialog text requires clicking
      final deleteIcon = find.byIcon(Icons.delete_outline_rounded);
      await tester.ensureVisible(deleteIcon);
      await tester.tap(deleteIcon);
      await tester.pumpAndSettle();

      expect(find.text('Clear Cache?'), findsOneWidget);
      expect(find.textContaining('1 modules'), findsOneWidget);

      // Tap Clear
      await tester.tap(find.text('CLEAR'));
      await tester.pumpAndSettle();

      // Verify SnackBar
      expect(find.text('Cache cleared successfully.'), findsOneWidget);
    });

    testWidgets('displays session info', (WidgetTester tester) async {
      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      // Scroll to bottom
      final sessionHeader = find.text('SESSION INFO');
      await tester.ensureVisible(sessionHeader);
      
      expect(sessionHeader, findsOneWidget);
      expect(find.text('Owner / Admin'), findsOneWidget);
      expect(find.textContaining('sess_'), findsOneWidget);
    });
  });
}
