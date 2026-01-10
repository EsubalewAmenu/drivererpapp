import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/settings_screen.dart';
import 'package:drivererpapp/providers/theme_provider.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';

class MockThemeProvider extends Mock implements ThemeProvider {}
class MockAuthService extends Mock implements AuthService {}
class MockWorkspaceProvider extends Mock implements WorkspaceProvider {}
class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

void main() {
  late MockThemeProvider mockThemeProvider;
  late MockAuthService mockAuthService;
  late MockWorkspaceProvider mockWorkspaceProvider;
  late MockGoogleSignInAccount mockAccount;

  setUp(() {
    mockThemeProvider = MockThemeProvider();
    mockAuthService = MockAuthService();
    mockWorkspaceProvider = MockWorkspaceProvider();
    mockAccount = MockGoogleSignInAccount();

    when(() => mockThemeProvider.themeMode).thenReturn(ThemeMode.light);
    when(() => mockThemeProvider.isDarkMode).thenReturn(false);
    when(() => mockWorkspaceProvider.isLoading).thenReturn(false);
    when(() => mockWorkspaceProvider.currentWorkspace).thenReturn(drive.File()..id = 'w1'..name = 'My Workspace');
    when(() => mockWorkspaceProvider.hasWorkspace).thenReturn(true);
    when(() => mockWorkspaceProvider.companies).thenReturn([]);
    
    when(() => mockAccount.displayName).thenReturn('Test User');
    when(() => mockAccount.email).thenReturn('test@example.com');
    when(() => mockAccount.photoUrl).thenReturn(null);
    when(() => mockAuthService.currentUser).thenReturn(mockAccount);
    
    when(() => mockWorkspaceProvider.currentWorkspace).thenReturn(drive.File()..name = 'Test Company');
  });

  Widget createSettingsScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: mockThemeProvider),
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
      ],
      child: const MaterialApp(
        home: SettingsScreen(),
        // Larger size to avoid off-screen issues
      ),
    );
  }

  testWidgets('SettingsScreen displays profile and company info', (WidgetTester tester) async {
    await tester.pumpWidget(createSettingsScreen());

    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('Test User'), findsAtLeastNWidgets(1));
    expect(find.text('test@example.com'), findsOneWidget);
    expect(find.text('Test Company'), findsAtLeastNWidgets(1));
  });

  testWidgets('SettingsScreen toggles dark mode', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    when(() => mockThemeProvider.toggleTheme()).thenAnswer((_) async {});
    
    await tester.pumpWidget(createSettingsScreen());

    final switchFinder = find.byType(Switch);
    await tester.ensureVisible(switchFinder);
    await tester.tap(switchFinder);
    await tester.pump();
    
    verify(() => mockThemeProvider.toggleTheme()).called(1);
  });
}
