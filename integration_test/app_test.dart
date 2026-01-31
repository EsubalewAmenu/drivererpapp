import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:drivererpapp/screens/landing_screen.dart';
import 'package:drivererpapp/models/company_model.dart';

import 'helpers/test_helpers.dart';

class MockWorkspaceProvider extends Mock implements WorkspaceProvider {}
class MockDriveProvider extends Mock implements DriveProvider {}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthService mockAuthService;
  late MockWorkspaceProvider mockWorkspaceProvider;
  late MockDriveProvider mockDriveProvider;
  late MockDriveService mockDriveService;

  setUpAll(() {
    initTestEnvironment();
  });

  setUp(() {
    final mocks = createTestMocks();
    mockAuthService = mocks.auth;
    mockDriveService = mocks.drive;
    mockWorkspaceProvider = MockWorkspaceProvider();
    mockDriveProvider = MockDriveProvider();

    when(() => mockAuthService.isAuthenticated).thenReturn(false);
    when(() => mockAuthService.signInSilently()).thenAnswer((_) async {});
    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockDriveService.getFileModifiedTime(any())).thenAnswer((_) async => DateTime.now());

    // Workspace Provider stubs
    when(() => mockWorkspaceProvider.hasWorkspace).thenReturn(false);
    when(() => mockWorkspaceProvider.isLoading).thenReturn(false);
    when(() => mockWorkspaceProvider.companies).thenReturn([]);
    when(() => mockWorkspaceProvider.loadCompanies(any())).thenAnswer((_) async {});
  });

  Widget createTestApp() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ChangeNotifierProvider<SchemaProvider>(create: (_) => SchemaProvider(driveService: mockDriveService)),
      ],
      child: const MaterialApp(
        home: LandingScreen(),
      ),
    );
  }

  testWidgets('Full flow: Landing -> Sign In -> System Scanning -> Workspace Selection', (tester) async {
    debugPrint('TEST: Starting app_test flow');
    // 1. Landing Screen
    await tester.pumpWidget(createTestApp());
    // Allow silent sign-in check to complete and button to appear
    await tester.pumpAndSettle(); 
    
    expect(find.text('DRIVE ERP'), findsOneWidget);

    // 2. Sign In
    when(() => mockAuthService.signIn()).thenAnswer((_) async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
    });
    
    // Mock Drive Service for scanning
    when(() => mockDriveService.checkRootFolder()).thenAnswer((_) async => 'root123');
    // Note: listWorkspaces is no longer called by SystemScanningScreen, but we mock companies for Selector
    
    final companies = [
      Company(id: 'c1', name: 'Test Workspace', folderId: 'ws123', role: 'Owner')
    ];
    when(() => mockWorkspaceProvider.companies).thenReturn(companies);

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    // 3. System Scanning (should happen automatically after sign in)
    // We expect to see SystemScanningScreen or it might move quickly to WorkspaceSelector
    
    // Wait for the scanning sequence to complete
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 4. Workspace Selection
    expect(find.text('SELECT WORKSPACE'), findsOneWidget);
    expect(find.text('Test Workspace'), findsOneWidget);
  });
}
