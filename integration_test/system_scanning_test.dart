import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/theme/app_theme.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/providers/theme_provider.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:drivererpapp/screens/system_scanning_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthService mockAuthService;
  late MockDriveService mockDriveService;

  setUpAll(() {
    initTestEnvironment();
  });

  setUp(() {
    final mocks = createTestMocks();
    mockAuthService = mocks.auth;
    mockDriveService = mocks.drive;
    when(() => mockAuthService.isAuthenticated).thenReturn(true);
    when(() => mockAuthService.currentUser).thenReturn(null);
  });

  Widget createTestWidget({
    required WorkspaceProvider workspaceProvider,
    required DriveProvider driveProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaceProvider),
        ChangeNotifierProvider<DriveProvider>.value(value: driveProvider),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<SchemaProvider>(create: (_) => SchemaProvider(driveService: mockDriveService)),
      ],
      child: const MaterialApp(
        home: SystemScanningScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }

  testWidgets('System Scanning Screen: Error and Retry Flow', (tester) async {
    final workspaceProvider = WorkspaceProvider();
    final driveProvider = TestDriveProvider(mockDriveService);

    // 1. Mock a failure during scanning
    when(() => mockDriveService.checkRootFolder()).thenThrow(Exception('No connection'));

    await tester.pumpWidget(createTestWidget(
      workspaceProvider: workspaceProvider,
      driveProvider: driveProvider,
    ));
    
    // Start scanning
    await tester.pump(); 
    
    // Wait for error to appear
    await tester.pumpAndSettle();

    expect(find.text('System Error: Exception: No connection'), findsOneWidget);
    expect(find.text('RETRY CONNECTION'), findsOneWidget);

    // 2. Mock success on retry
    when(() => mockDriveService.checkRootFolder()).thenAnswer((_) async => 'root_ok');
    when(() => mockDriveService.ensureCompanyRegistry('root_ok')).thenAnswer((_) async => 'reg_id');
    when(() => mockDriveService.getCompanies('root_ok')).thenAnswer((_) async => []);

    await tester.tap(find.text('RETRY CONNECTION'));
    
    // Scanning again...
    await tester.pump();
    await tester.pumpAndSettle();

    // Should now show the workspace selector or "No workspaces found"
    expect(find.text('AVAILABLE ENVIRONMENTS'), findsOneWidget);
  });
}
