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
import 'package:drivererpapp/models/schema_models.dart';
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
          // Provide a userEmail so SchemaService.syncConfig performs user-specific lookup
          ChangeNotifierProvider<SchemaProvider>(create: (_) => SchemaProvider(driveService: mockDriveService, userEmail: 'user@example.com')),
      ],
      child: const MaterialApp(
        home: DashboardScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }

  testWidgets('Module Interaction: List -> Detail -> Edit -> Verify Refresh Flow', (tester) async {
    // Set screen size correctly for integration tests
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final workspaceFile = drive.File()
      ..id = 'ws1'
      ..name = 'ERP Lab';
    final workspaceProvider = WorkspaceProvider();
    workspaceProvider.setWorkspace(workspaceFile);
    
    final driveProvider = TestDriveProvider(mockDriveService);

    // 1. Mock Module List and Config via user_access sheet
    final mockSheetsApi = MockSheetsApi();
    final mockSpreadsheets = MockSpreadsheetsResource();
    final mockValues = MockValuesResource();
    when(() => mockSheetsApi.spreadsheets).thenReturn(mockSpreadsheets);
    when(() => mockSpreadsheets.values).thenReturn(mockValues);
    when(() => mockDriveService.sheetsApi).thenReturn(mockSheetsApi);
    final moduleFile = drive.File()..id = 'mod1'..name = 'Inventory';
    await workspaceProvider.saveUserAccessSpreadsheetId('ua_ws1');
    final header = ['id', 'module_name', 'dashboard', 'settings', 'tabs'];
    final rows = [ ['mod1', 'Inventory', 'dash_1', 'config_id', 'tabs_1'] ];
    when(() => mockValues.get('ua_ws1', 'modules!A1:Z')).thenAnswer((_) async => sheets.ValueRange(values: [header, ...rows]));
    when(() => mockDriveService.getOrCreateSubFolder('mod1', 'config')).thenAnswer((_) async => 'mod1');
    when(() => mockDriveService.getFileId('mod1', 'user@example.com_settings')).thenAnswer((_) async => 'config_id');
    
    final moduleConfig = {
      'id': 'mod1',
      'name': 'Inventory',
      'icon': 'inventory',
      'primaryColor': '#F59E0B',
      'version': '1.0.0',
      'tabs': [
        {
          'id': 'items', 
          'label': 'Items / SKUs', 
          'fileId': 'items_sheet_id',
          'columns': [
            {'key': 'name', 'label': 'Name', 'type': 'text'},
            {'key': 'qty', 'label': 'Quantity', 'type': 'number'}
          ]
        }
      ],
      'dashboard': <String, dynamic>{'cards': []},
      'settings': <String, dynamic>{}
    };
    when(() => mockDriveService.readSettingsById('config_id')).thenAnswer((_) async => moduleConfig['settings'] as Map<String, dynamic>);
    when(() => mockDriveService.readDashboardById('dash_1')).thenAnswer((_) async => moduleConfig['dashboard'] as Map<String, dynamic>);
    when(() => mockDriveService.readTabsById('tabs_1')).thenAnswer((_) async => moduleConfig['tabs'] as List<dynamic>);

    // 2. Mock Records
    final records = [
      {'record_id': 'r1', 'name': 'Widget A', 'qty': 10},
    ];
    when(() => mockDriveService.fetchRecords(
          any(), any(), any(), 
          offset: any(named: 'offset'), 
          limit: any(named: 'limit'), 
          fetchSubTables: any(named: 'fetchSubTables'), 
          descending: any(named: 'descending'),
          searchQuery: any(named: 'searchQuery'),
          quickFilter: any(named: 'quickFilter'),
        )).thenAnswer((_) async => List<Map<String, dynamic>>.from(records));

    // Also stub the spreadsheet-id based fetch path in case cached config provides a fileId
    when(() => mockDriveService.fetchRecordsBySpreadsheetId(
          any(), any(),
          offset: any(named: 'offset'),
          limit: any(named: 'limit'),
          fetchSubTables: any(named: 'fetchSubTables'),
          descending: any(named: 'descending'),
          searchQuery: any(named: 'searchQuery'),
          quickFilter: any(named: 'quickFilter'),
        )).thenAnswer((_) async => List<Map<String, dynamic>>.from(records));

    // 3. Start App
    await tester.pumpWidget(createTestWidget(
      workspaceProvider: workspaceProvider,
      driveProvider: driveProvider,
    ));
    await tester.pumpAndSettle();

    // 4. Open Inventory Module
    await tester.tap(find.text('Inventory'));
    // Wait for schema sync
    for(int i=0; i<8; i++) {
       await tester.pump(const Duration(milliseconds: 200));
    }

    // First tab is Dashboard, we need to switch to ITEMS tab
    // The tab bar has [DASHBOARD, Items]. Tap the tab by matching any Text containing 'Items'
    final itemsTabFinder = find.byWidgetPredicate((w) => w is Text && (w.data ?? '').toString().toUpperCase().contains('ITEMS'));
    await tester.tap(itemsTabFinder.first);
    await tester.pumpAndSettle();
    // Delay for records load
    for(int i=0; i<5; i++) {
       await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.text('Widget A'), findsAtLeast(1)); 

    // 5. Open Record Detail
    await tester.tap(find.text('Widget A').first);
    await tester.pumpAndSettle();

    expect(find.text('DETAILS'), findsOneWidget);
    expect(find.text('Widget A'), findsAtLeast(1));

    // 6. Open Edit Form
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    final editTitleFinder = find.byWidgetPredicate((w) => w is Text && (w.data ?? '').toString().toUpperCase().contains('EDIT') && (w.data ?? '').toString().toUpperCase().contains('ITEMS'));
    expect(editTitleFinder, findsOneWidget);

    // 7. Update Name field
    // Find text field with 'Widget A' and change it
    final nameField = find.widgetWithText(TextFormField, 'Widget A');
    await tester.enterText(nameField, 'Widget Updated');
    
    // Mock Save
    when(() => mockDriveService.saveRecord(any(), any(), any(), any())).thenAnswer((_) async => {});

    // Save
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    // 8. Detail view may not update in-place; we'll verify after returning to the list

    // 9. Go back and verify list is refreshed
    // Note: We need to mock fetchRecords again because the list will refresh
    final updatedRecords = [
      {'record_id': 'r1', 'name': 'Widget Updated', 'qty': 10},
    ];
    when(() => mockDriveService.fetchRecords(
          any(), any(), any(), 
          offset: any(named: 'offset'), 
          limit: any(named: 'limit'), 
          fetchSubTables: any(named: 'fetchSubTables'), 
          descending: any(named: 'descending'),
          searchQuery: any(named: 'searchQuery'),
          quickFilter: any(named: 'quickFilter'),
        )).thenAnswer((_) async => List<Map<String, dynamic>>.from(updatedRecords));
    // Also ensure spreadsheet-id based fetch returns updated records
    when(() => mockDriveService.fetchRecordsBySpreadsheetId(
          any(), any(),
          offset: any(named: 'offset'),
          limit: any(named: 'limit'),
          fetchSubTables: any(named: 'fetchSubTables'),
          descending: any(named: 'descending'),
          searchQuery: any(named: 'searchQuery'),
          quickFilter: any(named: 'quickFilter'),
        )).thenAnswer((_) async => List<Map<String, dynamic>>.from(updatedRecords));

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    // Wait for refresh delay
    for(int i=0; i<5; i++) {
       await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.text('Widget Updated'), findsOneWidget);
  });
}
