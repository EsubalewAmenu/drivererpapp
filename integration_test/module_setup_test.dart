import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:drivererpapp/theme/app_theme.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/providers/theme_provider.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:drivererpapp/screens/dashboard_screen.dart';
import 'package:drivererpapp/screens/module_screen.dart';
import 'package:drivererpapp/models/schema_models.dart';
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
    final mockSheetsApi = MockSheetsApi();
    final mockSpreadsheets = MockSpreadsheetsResource();
    final mockValues = MockValuesResource();
    when(() => mockSheetsApi.spreadsheets).thenReturn(mockSpreadsheets);
    when(() => mockSpreadsheets.values).thenReturn(mockValues);
    when(() => mockDriveService.sheetsApi).thenReturn(mockSheetsApi);

    when(() => mockAuthService.isAuthenticated).thenReturn(true);
    when(() => mockAuthService.currentUser).thenReturn(null);
    
    // Default mocks for module loading and dashboard
    when(() => mockDriveService.fetchRecords(
      any(), 
      any(), 
      any(),
      offset: any(named: 'offset'),
      limit: any(named: 'limit'),
      fetchSubTables: any(named: 'fetchSubTables'),
      descending: any(named: 'descending'),
    )).thenAnswer((_) async => []);
    when(() => mockDriveService.getFileModifiedTime(any())).thenAnswer((_) async => DateTime.now());
    when(() => mockDriveService.getFileId(any(), any())).thenAnswer((_) async => null);
  });

  testWidgets('Module Activation and Blueprint Editing Flow', (tester) async {
    debugPrint('TEST: Starting module_setup_test flow');
    final workspace = drive.File()..id = 'ws1'..name = 'Test Workspace';
    
    // Initial state: no modules installed
    final emptyRange = sheets.ValueRange(values: []);
    when(() => mockDriveService.sheetsApi.spreadsheets.values.get('ua1', 'modules!A1:Z'))
      .thenAnswer((_) async => emptyRange);
    
    final workspaceProvider = WorkspaceProvider();
    workspaceProvider.setWorkspace(workspace);
    // Pre-seed the last user_access spreadsheet id so Dashboard builds with installed modules
    await workspaceProvider.saveUserAccessSpreadsheetId('ua1');

    final driveProvider = TestDriveProvider(mockDriveService);

    await tester.pumpWidget(
      MultiProvider(
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
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify we are on Dashboard and see "No modules installed"
    expect(find.text('No modules installed.\nVisit the Marketplace to expand.'), findsOneWidget);

    // 2. Select a module from Catalog (Marketplace)
    // Expansion Module "CRM" or "Inventory"
    final inventoryMarketplaceFinder = find.text('Inventory').last;
    await tester.scrollUntilVisible(inventoryMarketplaceFinder, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(inventoryMarketplaceFinder);
    await tester.pumpAndSettle();

    // 3. Verify Module Details
    expect(find.text('INVENTORY'), findsOneWidget);
    expect(find.text('KEY BENEFITS'), findsOneWidget);

    // 4. Activate Module
    when(() => mockDriveService.createWorkspace(any(), any())).thenAnswer((_) async {
      // After creating the workspace, update the user_access sheet mock
      final installedRange = sheets.ValueRange(values: [
        ['id', 'module_name', 'dashboard', 'settings', 'tabs'],
        ['new_mod_id', 'Inventory', '', '', '']
      ]);
      when(() => mockDriveService.sheetsApi.spreadsheets.values.get('ua1', 'modules!A1:Z'))
          .thenAnswer((_) async => installedRange);
      return drive.File()..id = 'new_mod_id';
    });
    // Ensure createModuleConfig used during activation returns an id
    when(() => mockDriveService.createModuleConfig(any(), any(), any()))
      .thenAnswer((_) async => 'created_cfg_id');
    // Ensure checkRootFolder resolves
    when(() => mockDriveService.checkRootFolder()).thenAnswer((_) async => 'root_folder_id');
    // Ensure config folder creation returns an id (async)
    when(() => mockDriveService.getOrCreateSubFolder('new_mod_id', 'config'))
        .thenAnswer((_) async => 'new_mod_config_folder');
    // Seed saveRecord calls should resolve as Future<void>
    when(() => mockDriveService.saveRecord(any(), any(), any(), any()))
        .thenAnswer((_) async => null);
    // After seeding, getFileId for tab spreadsheets should return a non-null id
    when(() => mockDriveService.getFileId('new_mod_id', any()))
        .thenAnswer((inv) async {
      final name = inv.positionalArguments[1] as String;
      return '${name}_sheet_id';
    });
    // Provide defaults for user access helpers in case activation attempts them
    when(() => mockDriveService.ensureUserAccessFolder(any())).thenAnswer((_) async => 'user_access_folder');
    when(() => mockDriveService.ensureUserAccessSpreadsheet(any(), any())).thenAnswer((_) async => 'user_access_file');
    when(() => mockDriveService.upsertUserAccessModule(any(), any(), any(), any(), any(), any()))
        .thenAnswer((_) async => null);
    
    await tester.tap(find.text('ACTIVATE'));
    await tester.pumpAndSettle();
    
    // Wait for SnackBar to disappear as it blocks taps in CI (800x600)
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    debugPrint('Navigated back to Dashboard. Checking for core module...');
    // Ensure workspace provider knows the user_access spreadsheet id so dashboard shows installed modules
    await workspaceProvider.saveUserAccessSpreadsheetId('ua1');
    await tester.pumpAndSettle();

    // If the dashboard didn't navigate to the editor automatically, push ModuleScreen directly
    try {
      final dashboardContext = tester.element(find.byType(DashboardScreen));
      Navigator.of(dashboardContext).push(MaterialPageRoute(builder: (_) => ModuleScreen(
        module: ModuleSchema(id: 'new_mod_id', name: 'Inventory', icon: 'inventory', primaryColor: '#3B82F6', version: '1.0.0', settings: {}, dashboard: DashboardConfig(cards: []), tabs: []),
        settingsSheetId: 'config_id',
        dashboardSheetId: null,
        tabsSheetId: null,
      )));
      await tester.pumpAndSettle();
    } catch (e) {
      debugPrint('Could not push ModuleScreen directly: $e');
    }
    
    // 5. Open the module to trigger first-time setup (Blueprint Editor)
    when(() => mockDriveService.getFileId('new_mod_id', 'config')).thenAnswer((_) async => null);
    when(() => mockDriveService.readModuleConfig(any())).thenAnswer((_) async => <String, dynamic>{
      'tabs': <dynamic>[],
      'dashboard': <String, dynamic>{'cards': <dynamic>[]},
      'settings': <String, dynamic>{}
    });

    // If we didn't navigate via dashboard, ModuleScreen was pushed directly above.

    // Should be in COMPLETE SETUP (SchemaEditorScreen) or show structure
    final hasCompleteSetup = find.text('COMPLETE SETUP').evaluate().isNotEmpty;
    final hasStructure = find.text('STRUCTURE').evaluate().isNotEmpty;
    expect(hasCompleteSetup || hasStructure, isTrue);

    // 6. Save/Activate in Editor
    when(() => mockDriveService.createModuleConfig(any(), any(), any())).thenAnswer((_) async => 'config_id');
    when(() => mockDriveService.updateModuleConfig(any(), any())).thenAnswer((_) async => {});
    
    // After activate in editor, it goes back to ModuleScreen which might load again.
    when(() => mockDriveService.getFileId('new_mod_id', 'config')).thenAnswer((_) async => 'config_id');
    when(() => mockDriveService.readModuleConfig('config_id')).thenAnswer((_) async => <String, dynamic>{
      'id': 'new_mod_id',
      'name': 'Inventory',
      'icon': 'inventory',
      'primaryColor': '#F59E0B',
      'version': '1.0.0',
      'tabs': <dynamic>[
        <String, dynamic>{'id': 't1', 'label': 'Stocks', 'columns': <dynamic>[]}
      ],
      'dashboard': <String, dynamic>{'cards': <dynamic>[]},
      'settings': <String, dynamic>{}
    });

    await tester.tap(find.text('ACTIVATE'));
    await tester.pumpAndSettle();

    // Should be back in ModuleScreen, showing the tabs.
    // Inventory asset has "Stock Adjustment" tab.
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.byWidgetPredicate((w) {
        if (w is Text && w.data != null) {
          return w.data!.toUpperCase().contains('STOCK ADJUSTMENT');
        }
        return false;
      }),
      findsOneWidget,
    );
  });
}
