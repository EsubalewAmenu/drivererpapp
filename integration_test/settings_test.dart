import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/theme/app_theme.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/providers/theme_provider.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:drivererpapp/models/company_model.dart';
import 'package:drivererpapp/screens/landing_screen.dart';
import 'package:drivererpapp/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_helpers.dart';

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthService mockAuthService;
  late MockDriveService mockDriveService;
  late MockGoogleSignInAccount mockUser;

  setUpAll(() {
    initTestEnvironment();
    registerFallbackValue(ModuleSchema(
      id: '', name: '', icon: '', primaryColor: '', version: '',
      settings: {}, dashboard: DashboardConfig(cards: []), tabs: []
    ));
  });

  setUp(() {
    final mocks = createTestMocks();
    mockAuthService = mocks.auth;
    mockDriveService = mocks.drive;
    mockUser = MockGoogleSignInAccount();

    when(() => mockUser.displayName).thenReturn('Integration User');
    when(() => mockUser.email).thenReturn('integration@example.com');
    when(() => mockUser.photoUrl).thenReturn(null);
    when(() => mockAuthService.currentUser).thenReturn(mockUser);
    when(() => mockAuthService.isAuthenticated).thenReturn(false);
    when(() => mockAuthService.signInSilently()).thenAnswer((_) async {});
    when(() => mockAuthService.signIn()).thenAnswer((_) async { when(() => mockAuthService.isAuthenticated).thenReturn(true); });

    when(() => mockDriveService.checkRootFolder()).thenAnswer((_) async => 'root123');
    when(() => mockDriveService.ensureCompanyRegistry(any())).thenAnswer((_) async => 'companies_sheet_id');
    when(() => mockDriveService.getCompanies(any())).thenAnswer((_) async => []);
    when(() => mockDriveService.listWorkspaces(any())).thenAnswer((_) async => []);
    when(() => mockDriveService.getFileModifiedTime(any())).thenAnswer((_) async => DateTime.now());
  });

  testWidgets('Settings Screen Flow', (tester) async {
    debugPrint('TEST: Starting settings_test flow');
    
    // Setup companies mock
    final companies = [
      Company(id: 'c1', name: 'Test Workspace', folderId: 'ws1', role: 'Owner')
    ];
    when(() => mockDriveService.getCompanies('root123')).thenAnswer((_) async => companies);
    final emptyRange = sheets.ValueRange(values: []);
    when(() => mockDriveService.sheetsApi.spreadsheets.values.get('ua1', 'modules!A1:Z'))
      .thenAnswer((_) async => emptyRange);

    final driveProvider = TestDriveProvider(mockDriveService);
    
    // Inject Mock DriveService into WorkspaceProvider via the real DriveProvider logic or just construct it with it if possible.
    // However, in the test createWidget:
    // ChangeNotifierProvider<WorkspaceProvider>(create: (_) => WorkspaceProvider()),
    // This WorkspaceProvider will be empty initially.
    // But WorkspaceProvider depends on DriveService? 
    // Wait, the main.dart uses ProxyProvider to inject DriveService into WorkspaceProvider.
    // In this test, we are using MultiProvider without ProxyProvider update logic for WorkspaceProvider.
    // WorkspaceProvider() constructor takes optional DriveService.
    
    // FIX: Pass driveService to WorkspaceProvider
    
    // Helper to safely wait
    Future<void> safePumpAndSettle() async {
      try {
        await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 2));
      } catch (e) {
        // Ignore timeouts
        await tester.pump();
      }
    }

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
          ChangeNotifierProvider<DriveProvider>.value(value: driveProvider),
          // ProxyProvider to inject DriveService into WorkspaceProvider
          ChangeNotifierProxyProvider<DriveProvider, WorkspaceProvider>(
            create: (_) => WorkspaceProvider(driveService: mockDriveService),
            update: (_, drive, workspace) => WorkspaceProvider(driveService: drive.driveService),
          ),
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<SchemaProvider>(create: (_) => SchemaProvider(driveService: mockDriveService)),
        ],
        child: const MaterialApp(
          home: LandingScreen(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );

    // 1. Log in
    await safePumpAndSettle();
    final continueButton = find.text('Continue with Google');
    expect(continueButton, findsOneWidget);
    await tester.tap(continueButton);
    
    // Wait for scanning
    await tester.pump(const Duration(seconds: 1)); // Transition
    await tester.pump(const Duration(seconds: 4)); // Scanning delay

    // 2. Select Workspace
    final workspaceFinder = find.text('Test Workspace');
    // Ensure found
    for(int i=0; i<10; i++) {
        if(workspaceFinder.evaluate().isNotEmpty) break;
        await tester.pump(const Duration(milliseconds: 500));
    }
    expect(workspaceFinder, findsOneWidget);
    await tester.tap(workspaceFinder);
    
    // Wait for Dashboard
    await tester.pump(const Duration(seconds: 2));
    await safePumpAndSettle();

    // 3. Navigate to Settings
    final settingsIcon = find.byIcon(Icons.settings_rounded);
    expect(settingsIcon, findsOneWidget);
    
    await tester.tap(settingsIcon);
    await safePumpAndSettle();

    // 4. Verify Settings Screen Content
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('SETTINGS'), findsOneWidget);

    // Verify Personal Profile (Dynamic Data)
    expect(find.text('PERSONAL PROFILE'), findsOneWidget);
    // Might be found multiple times (Avatar label + TextField)
    expect(find.text('Integration User'), findsAtLeastNWidgets(1));
    expect(find.text('integration@example.com'), findsOneWidget);

    // Verify Company Branding (Workspace Name)
    expect(find.text('COMPANY BRANDING'), findsOneWidget);
    // Might be found multiple times (Settings TextField + Dashboard underneath)
    expect(find.text('Test Workspace'), findsAtLeastNWidgets(1));

    // Verify Appearance
    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('Dark Mode'), findsOneWidget);

    // Toggle Dark Mode
    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    
    // We can check if theme changed by checking color, or just ensure no crash.
    // Since we provided ThemeProvider, it should work.

    // 5. Navigate Back
    await tester.pageBack();
    await safePumpAndSettle();
    
    // Verify we are back on Dashboard
    expect(find.text('CORE MODULES'), findsOneWidget);
  });
}
