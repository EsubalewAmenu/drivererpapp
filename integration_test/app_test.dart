import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/main.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/screens/landing_screen.dart';
import 'package:drivererpapp/screens/system_scanning_screen.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class MockAuthService extends Mock implements AuthService {}
class MockWorkspaceProvider extends Mock implements WorkspaceProvider {}
class MockDriveProvider extends Mock implements DriveProvider {}
class MockDriveService extends Mock implements DriveService {}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthService mockAuthService;
  late MockWorkspaceProvider mockWorkspaceProvider;
  late MockDriveProvider mockDriveProvider;
  late MockDriveService mockDriveService;

  setUp(() {
    mockAuthService = MockAuthService();
    mockWorkspaceProvider = MockWorkspaceProvider();
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();

    when(() => mockAuthService.isAuthenticated).thenReturn(false);
    when(() => mockAuthService.signInSilently()).thenAnswer((_) async {});
    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockWorkspaceProvider.hasWorkspace).thenReturn(false);
  });

  Widget createTestApp() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
      ],
      child: const MaterialApp(
        home: LandingScreen(),
      ),
    );
  }

  testWidgets('Full flow: Landing -> Sign In -> System Scanning -> Workspace Selection', (tester) async {
    // 1. Landing Screen
    await tester.pumpWidget(createTestApp());
    expect(find.text('DRIVE ERP'), findsOneWidget);

    // 2. Sign In
    when(() => mockAuthService.signIn()).thenAnswer((_) async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
    });
    
    // Mock Drive Service for scanning
    when(() => mockDriveService.checkRootFolder()).thenAnswer((_) async => 'root123');
    when(() => mockDriveService.listWorkspaces(any())).thenAnswer((_) async => [
      drive.File()..name = 'Test Workspace'..id = 'ws123'
    ]);

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
