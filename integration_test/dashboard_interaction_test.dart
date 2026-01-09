import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:drivererpapp/theme/app_theme.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/providers/theme_provider.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:drivererpapp/screens/dashboard_screen.dart';
import 'package:drivererpapp/screens/workspace_selector_screen.dart';
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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthService mockAuthService;
  late MockDriveService mockDriveService;

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    AppTheme.useGoogleFonts = false;
    registerFallbackValue(drive.File());
  });

  setUp(() {
    mockAuthService = MockAuthService();
    mockDriveService = MockDriveService();

    when(() => mockAuthService.isAuthenticated).thenReturn(true);
    when(() => mockAuthService.currentUser).thenReturn(null);
    when(() => mockDriveService.getFileModifiedTime(any())).thenAnswer((_) async => DateTime.now());
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

  testWidgets('Dashboard: Period Switching and Module Navigation', (tester) async {
    debugPrint('TEST: Starting dashboard_interaction_test (Period & Navigation)');
    
    final workspace = drive.File()..id = 'ws1'..name = 'Growth Corp';
    final moduleFile = drive.File()..id = 'mod1'..name = 'Sales';
    
    when(() => mockDriveService.listModules('ws1')).thenAnswer((_) async => [moduleFile]);
    when(() => mockDriveService.fetchRecords(any(), any(), any(), 
      offset: any(named: 'offset'), limit: any(named: 'limit'), fetchSubTables: any(named: 'fetchSubTables'), descending: any(named: 'descending')))
      .thenAnswer((_) async => []);

    final workspaceProvider = WorkspaceProvider();
    workspaceProvider.setWorkspace(workspace);
    final driveProvider = TestDriveProvider(mockDriveService);

    await tester.pumpWidget(createTestWidget(
      workspaceProvider: workspaceProvider,
      driveProvider: driveProvider,
    ));

    await tester.pumpAndSettle();

    // 1. Verify Default KPI (Today)
    expect(find.text('GROWTH CORP'), findsOneWidget);
    expect(find.text(r'$800.00'), findsOneWidget); // Default hardcoded Today Profit

    // 2. Switch to Moonth
    await tester.tap(find.text('TODAY'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MONTH').last);
    await tester.pumpAndSettle();
    
    expect(find.text(r'-$7000.00'), findsOneWidget); // Default hardcoded Month Profit (35k - 42k)

    // 3. Navigate to Module
    await tester.tap(find.text('Sales'));
    await tester.pumpAndSettle();

    expect(find.text('SALES'), findsOneWidget);
    expect(find.text('DASHBOARD'), findsOneWidget);
  });

  testWidgets('Dashboard: Workspace Switching via Drawer', (tester) async {
    debugPrint('TEST: Starting dashboard_interaction_test (Workspace Switch)');
    
    final ws1 = drive.File()..id = 'ws1'..name = 'Company A';
    final ws2 = drive.File()..id = 'ws2'..name = 'Company B';
    
    when(() => mockDriveService.listModules(any())).thenAnswer((_) async => []);
    when(() => mockDriveService.checkRootFolder()).thenAnswer((_) async => 'root_id');
    when(() => mockDriveService.getCompanies(any())).thenAnswer((_) async => []);
    when(() => mockDriveService.ensureCompanyRegistry(any())).thenAnswer((_) async => 'reg_id');

    final workspaceProvider = WorkspaceProvider();
    workspaceProvider.setWorkspace(ws1);
    final driveProvider = TestDriveProvider(mockDriveService);

    await tester.pumpWidget(createTestWidget(
      workspaceProvider: workspaceProvider,
      driveProvider: driveProvider,
    ));

    await tester.pumpAndSettle();
    expect(find.text('COMPANY A'), findsOneWidget);

    // 1. Open Drawer
    // Using tooltip for drawer button as icon might vary by platform/theme
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    // 2. Click "Switch Workspace"
    await tester.tap(find.text('Switch Workspace'));
    await tester.pumpAndSettle();

    expect(find.byType(WorkspaceSelectorScreen), findsOneWidget);

    // 3. Mock workspace selection (since they are listed in real app)
    // In this test environment, we just manually call setWorkspace to simulate selection
    workspaceProvider.setWorkspace(ws2);
    await tester.pumpAndSettle();

    expect(find.text('COMPANY B'), findsOneWidget);
  });
}
