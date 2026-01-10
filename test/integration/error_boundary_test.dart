import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/theme/app_theme.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/providers/theme_provider.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:drivererpapp/screens/dashboard_screen.dart';
import 'package:drivererpapp/models/company_model.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthService extends Mock implements AuthService {}
class MockDriveService extends Mock implements DriveService {}

class TestDriveProvider extends DriveProvider {
  final DriveService? mockService;
  TestDriveProvider(this.mockService);
  @override
  DriveService? get driveService => mockService;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthService mockAuthService;
  late MockDriveService mockDriveService;

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    AppTheme.useGoogleFonts = false;
  });

  setUp(() {
    mockAuthService = MockAuthService();
    mockDriveService = MockDriveService();

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
        home: DashboardScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }

  testWidgets('Comprehensive Error Handling: Dashboard and Module Loading Failures', (tester) async {
    final workspaceFile = drive.File()
      ..id = 'ws1'
      ..name = 'Faulty ERP';
    final workspaceProvider = WorkspaceProvider();
    workspaceProvider.setWorkspace(workspaceFile);
    
    final driveProvider = TestDriveProvider(mockDriveService);

    // 1. Simulate Module List Failure
    when(() => mockDriveService.listModules('ws1')).thenAnswer((_) async => throw Exception('API quota exceeded'));

    await tester.pumpWidget(createTestWidget(
      workspaceProvider: workspaceProvider,
      driveProvider: driveProvider,
    ));
    await tester.pumpAndSettle();

    // Dashboard should ideally handle the module fetch error gracefully
    // depending on implementation it might show an error card or an empty state
    expect(find.text('FAULTY ERP'), findsOneWidget);
    
    // 2. Mock a Module becoming available but with a corrupt config
    final workspaceFile2 = drive.File()..id = 'ws2'..name = 'FAULTY ERP';
    workspaceProvider.setWorkspace(workspaceFile2);
    
    final moduleFile = drive.File()..id = 'mod_err'..name = 'HR';
    when(() => mockDriveService.listModules('ws2')).thenAnswer((_) async => [moduleFile]);
    when(() => mockDriveService.getFileId('mod_err', 'config')).thenAnswer((_) async => 'conf_err');
    when(() => mockDriveService.readModuleConfig('conf_err')).thenAnswer((_) async => throw const FormatException('Invalid JSON'));

    // Trigger a refresh by pumping again with the same widget (Provider change triggers rebuild)
    await tester.pumpWidget(createTestWidget(
      workspaceProvider: workspaceProvider,
      driveProvider: driveProvider,
    ));
    await tester.pumpAndSettle();

    // Now 'HR' should be in CORE MODULES
    final hrModule = find.text('HR');
    await tester.ensureVisible(hrModule);
    await tester.tap(hrModule);
    
    // ModuleScreen starts sync, wait for it to fail and show fallback
    for(int i=0; i<10; i++) {
       await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pumpAndSettle();

    // Verify it doesn't crash but navigates to setup because of missing config/asset
    expect(find.text('COMPLETE SETUP'), findsOneWidget);
  });
}
