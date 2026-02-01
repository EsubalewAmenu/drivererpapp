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
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthService extends Mock implements AuthService {}
class MockDriveService extends Mock implements DriveService {}
class MockSheetsApi extends Mock implements sheets.SheetsApi {}
class MockSpreadsheetsResource extends Mock implements sheets.SpreadsheetsResource {}
class MockValuesResource extends Mock implements sheets.SpreadsheetsValuesResource {}

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
    when(() => mockDriveService.getFileModifiedTime(any())).thenAnswer((_) async => DateTime.now());
    when(() => mockDriveService.readSettingsById(any())).thenAnswer((_) async => {'settings': {}});
    when(() => mockDriveService.readDashboardById(any())).thenAnswer((_) async => {'cards': []});
    when(() => mockDriveService.readTabsById(any())).thenAnswer((_) async => []);
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

    // 1. Simulate Module List Failure via empty user_access sheet (return empty rows so Dashboard doesn't throw)
    final mockSheetsApi1 = MockSheetsApi();
    final mockSpreadsheets1 = MockSpreadsheetsResource();
    final mockValues1 = MockValuesResource();
    when(() => mockSheetsApi1.spreadsheets).thenReturn(mockSpreadsheets1);
    when(() => mockSpreadsheets1.values).thenReturn(mockValues1);
    when(() => mockDriveService.sheetsApi).thenReturn(mockSheetsApi1);
    // Persist the per-workspace user_access spreadsheet id so Dashboard will query it
    await workspaceProvider.saveUserAccessSpreadsheetId('ua_ws1');
    when(() => mockValues1.get('ua_ws1', 'modules!A1:Z')).thenAnswer((_) async => sheets.ValueRange(values: []));

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
    
    // Provide a user_access sheet that contains the module row for ws2
    final mockSheetsApi2 = MockSheetsApi();
    final mockSpreadsheets2 = MockSpreadsheetsResource();
    final mockValues2 = MockValuesResource();
    when(() => mockSheetsApi2.spreadsheets).thenReturn(mockSpreadsheets2);
    when(() => mockSpreadsheets2.values).thenReturn(mockValues2);
    when(() => mockDriveService.sheetsApi).thenReturn(mockSheetsApi2);
    await workspaceProvider.saveUserAccessSpreadsheetId('ua_ws2');
    final header = ['id', 'module_name', 'dashboard', 'settings', 'tabs'];
    final rows = [ ['mod_err', 'HR', 'dash_x', 'conf_err', 'tabs_x'] ];
    when(() => mockValues2.get('ua_ws2', 'modules!A1:Z')).thenAnswer((_) async => sheets.ValueRange(values: [header, ...rows]));
    when(() => mockDriveService.getFileId('mod_err', 'config')).thenAnswer((_) async => 'conf_err');
    
    // Force all granular reads to fail so sync returns null
    when(() => mockDriveService.readSettingsById('conf_err')).thenThrow(const FormatException('Invalid JSON'));
    when(() => mockDriveService.readDashboardById('dash_x')).thenThrow(const FormatException('Invalid JSON'));
    when(() => mockDriveService.readTabsById('tabs_x')).thenThrow(const FormatException('Invalid JSON'));

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

    // Verify it doesn't crash but shows an error message since fallback was removed
    expect(find.text('Unable to load module data. Please check your connection.'), findsOneWidget);
  });
}
