import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/settings_screen.dart';
import 'package:drivererpapp/providers/theme_provider.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:drivererpapp/models/company_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockThemeProvider extends Mock implements ThemeProvider {}
class MockAuthService extends Mock implements AuthService {}
class MockWorkspaceProvider extends Mock implements WorkspaceProvider {}
class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}
class MockDriveProvider extends Mock implements DriveProvider {}
class MockDriveService extends Mock implements DriveService {}

void main() {
  late MockThemeProvider mockThemeProvider;
  late MockAuthService mockAuthService;
  late MockWorkspaceProvider mockWorkspaceProvider;
  late MockGoogleSignInAccount mockAccount;
  late MockDriveProvider mockDriveProvider;
  late MockDriveService mockDriveService;

  setUp(() {
    mockThemeProvider = MockThemeProvider();
    mockAuthService = MockAuthService();
    mockWorkspaceProvider = MockWorkspaceProvider();
    mockAccount = MockGoogleSignInAccount();
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();

    when(() => mockThemeProvider.themeMode).thenReturn(ThemeMode.light);
    when(() => mockThemeProvider.isDarkMode).thenReturn(false);
    when(() => mockWorkspaceProvider.isLoading).thenReturn(false);
    when(() => mockWorkspaceProvider.currentWorkspace).thenReturn(drive.File()..id = 'w1'..name = 'My Workspace');
    when(() => mockWorkspaceProvider.hasWorkspace).thenReturn(true);
    when(() => mockWorkspaceProvider.companies).thenReturn([]);
    when(() => mockWorkspaceProvider.rootFolderId).thenReturn('root_id');
    
    when(() => mockAccount.displayName).thenReturn('Test User');
    when(() => mockAccount.email).thenReturn('test@example.com');
    when(() => mockAccount.photoUrl).thenReturn(null);
    when(() => mockAuthService.currentUser).thenReturn(mockAccount);
    
    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockDriveService.checkRootFolder()).thenAnswer((_) async => 'root_id');
    when(() => mockWorkspaceProvider.loadCompanies(any())).thenAnswer((_) async {});
  });

  Widget createSettingsScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: mockThemeProvider),
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
      ],
      child: const MaterialApp(
        home: SettingsScreen(),
      ),
    );
  }

  testWidgets('SettingsScreen displays profile and company info', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createSettingsScreen());
    await tester.pumpAndSettle();

    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('Test User'), findsAtLeastNWidgets(1));
    expect(find.text('test@example.com'), findsOneWidget);
    expect(find.text('My Workspace'), findsAtLeastNWidgets(1));
  });

  testWidgets('SettingsScreen toggles dark mode', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    when(() => mockThemeProvider.toggleTheme()).thenAnswer((_) async {});
    
    await tester.pumpWidget(createSettingsScreen());
    await tester.pumpAndSettle();

    final switchFinder = find.byType(Switch);
    await tester.ensureVisible(switchFinder);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    
    verify(() => mockThemeProvider.toggleTheme()).called(1);
  });

  testWidgets('SettingsScreen updates company name', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    when(() => mockWorkspaceProvider.updateCompanyName(any())).thenAnswer((_) async {});
    
    await tester.pumpWidget(createSettingsScreen());
    await tester.pumpAndSettle();

    final nameField = find.widgetWithText(TextField, 'Company Name (Workspace)');
    await tester.ensureVisible(nameField);
    await tester.enterText(nameField, 'New Company Name');
    
    final saveButton = find.text('SAVE CHANGES');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    verify(() => mockWorkspaceProvider.updateCompanyName('New Company Name')).called(1);
  });

  testWidgets('SettingsScreen clears cache', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({'module_config_1': '{}'});

    await tester.pumpWidget(createSettingsScreen());
    await tester.pumpAndSettle();

    final clearButton = find.byIcon(Icons.delete_outline_rounded);
    await tester.ensureVisible(clearButton);
    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    expect(find.text('Clear Cache?'), findsOneWidget);
    await tester.tap(find.text('CLEAR'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('module_config_1'), isFalse);
  });

  testWidgets('SettingsScreen handles company deactivation', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final company = Company(id: 'c1', name: 'M1', folderId: 'w1', logoUrl: null);
    when(() => mockWorkspaceProvider.companies).thenReturn([company]);
    when(() => mockDriveService.setCompanyStatus(any(), any(), any())).thenAnswer((_) async {});
    when(() => mockWorkspaceProvider.clearWorkspace()).thenReturn(null);

    await tester.pumpWidget(createSettingsScreen());
    await tester.pumpAndSettle();

    final deactivateBtn = find.text('DEACTIVATE COMPANY');
    await tester.ensureVisible(deactivateBtn);
    await tester.tap(deactivateBtn);
    await tester.pumpAndSettle();

    expect(find.text('Deactivate Company'), findsOneWidget);
    await tester.tap(find.text('DEACTIVATE'));
    await tester.pumpAndSettle();

    verify(() => mockDriveService.setCompanyStatus('root_id', 'w1', 'deactivated')).called(1);
    verify(() => mockWorkspaceProvider.clearWorkspace()).called(1);
  });
}
