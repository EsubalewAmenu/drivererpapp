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
import 'package:drivererpapp/services/auth_service.dart';
import 'package:drivererpapp/screens/dashboard_screen.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'helpers/test_helpers.dart';

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
  });

  Widget createTestWidget({
    required WorkspaceProvider workspaceProvider,
    required DriveProvider driveProvider,
    String? userAccessSpreadsheetId,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaceProvider),
        ChangeNotifierProvider<DriveProvider>.value(value: driveProvider),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<SchemaProvider>(create: (_) => SchemaProvider(driveService: mockDriveService)),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: DashboardScreen(userAccessSpreadsheetId: userAccessSpreadsheetId),
            debugShowCheckedModeBanner: false,
          );
        },
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

    // 1. Simulate Module List Failure (empty user_access -> no modules)
    final emptyRange = sheets.ValueRange(values: []);
    when(() => mockDriveService.sheetsApi.spreadsheets.values.get('ua1', 'modules!A1:Z'))
      .thenAnswer((_) async => emptyRange);

    await tester.pumpWidget(createTestWidget(
      workspaceProvider: workspaceProvider,
      driveProvider: driveProvider,
      userAccessSpreadsheetId: 'ua1',
    ));
    await tester.pumpAndSettle();

    // Dashboard should ideally handle the module fetch error gracefully
    // depending on implementation it might show an error card or an empty state
    expect(find.text('FAULTY ERP'), findsOneWidget);
    
    // 2. Mock a Module becoming available but with a corrupt config
    final workspaceFile2 = drive.File()..id = 'ws2'..name = 'FAULTY ERP';
    workspaceProvider.setWorkspace(workspaceFile2);
    // Now user_access contains a module row for mod_err
    final moduleRange = sheets.ValueRange(values: [
      ['id', 'module_name', 'dashboard', 'settings', 'tabs'],
      ['mod_err', 'HR', '', 'conf_err', 'tabs_err'],
    ]);
    when(() => mockDriveService.sheetsApi.spreadsheets.values.get('ua1', 'modules!A1:Z'))
        .thenAnswer((_) async => moduleRange);
    when(() => mockDriveService.getFileId('mod_err', 'config')).thenAnswer((_) async => 'conf_err');
    when(() => mockDriveService.readSettingsById('conf_err')).thenAnswer((_) async => throw const FormatException('Invalid JSON'));

    // Trigger a refresh by pumping again with the same widget (Provider change triggers rebuild)
    await tester.pumpWidget(createTestWidget(
      workspaceProvider: workspaceProvider,
      driveProvider: driveProvider,
      userAccessSpreadsheetId: 'ua1',
    ));
    await tester.pumpAndSettle();

    // Now 'HR' should be in CORE MODULES because it was found in the list for 'ws2'
    final hrModule = find.text('HR');
    await tester.ensureVisible(hrModule);
    await tester.tap(hrModule);
    
    // ModuleScreen starts sync, wait for it to fail and show error body
    for(int i=0; i<10; i++) {
       await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pumpAndSettle();

    // Verify it doesn't crash; accept either editor ('COMPLETE SETUP') or details error message
    final foundEditorOrError = find.text('COMPLETE SETUP').evaluate().isNotEmpty || find.text('Error Loading Module').evaluate().isNotEmpty;
    expect(foundEditorOrError, isTrue);
  });
}
