import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:drivererpapp/providers/theme_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:drivererpapp/screens/dashboard_screen.dart';
import 'package:drivererpapp/screens/dynamic_form_screen.dart';
import 'package:drivererpapp/screens/module_screen.dart';
import 'package:drivererpapp/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_helpers.dart';

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthService mockAuthService;
  late MockDriveService mockDriveService;
  late MockGoogleSignInAccount mockAccount;

  setUpAll(() {
    initTestEnvironment();
  });

  setUp(() {
    final mocks = createTestMocks();
    mockAuthService = mocks.auth;
    mockDriveService = mocks.drive;
    mockAccount = MockGoogleSignInAccount();
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  testWidgets('End-to-End Form Submission Flow', (WidgetTester tester) async {
    debugPrint('TEST: Starting form_test flow');
    
    final workspace = drive.File()
      ..id = 'ws1'
      ..name = 'ERP Workspace';
    
    final moduleFolder = drive.File()
      ..id = 'mod1'
      ..name = 'Inventory';

    final moduleSchema = ModuleSchema(
      id: 'mod1',
      name: 'Inventory',
      icon: 'inventory',
      primaryColor: '#3B82F6',
      version: '1.0.0',
      settings: {
        'company': SettingItem(label: 'Company Name', type: 'text', value: 'My Corp'),
      },
      tabs: [
        TabConfig(
          id: 'stocks',
          label: 'Stocks',
          columns: [
            ColumnConfig(key: 'item', label: 'Item Name', type: 'text', isRequired: true),
            ColumnConfig(key: 'active', label: 'Is Active', type: 'boolean'),
            ColumnConfig(key: 'category', label: 'Category', type: 'select', options: ['Electronics', 'Furniture']),
            ColumnConfig(key: 'date', label: 'Acquisition Date', type: 'date'),
            ColumnConfig(key: 'tags', label: 'Tags', type: 'list'),
            ColumnConfig(key: 'qty', label: 'Quantity', type: 'number'),
            ColumnConfig(key: 'cost', label: 'Unit Cost', type: 'currency'),
            ColumnConfig(key: 'total', label: 'Total Value', type: 'formula', formula: 'qty * cost'),
            ColumnConfig(key: 'supplier', label: 'Supplier', type: 'relation', options: 'suppliers'),
            ColumnConfig(key: 'components', label: 'Components', type: 'table', columns: [
               ColumnConfig(key: 'comp_name', label: 'Component Name', type: 'text'),
            ]),
            ColumnConfig(key: 'photo', label: 'Photo', type: 'image'),
            ColumnConfig(key: 'barcode', label: 'Barcode', type: 'scanner'),
            ColumnConfig(key: 'sign', label: 'Signature', type: 'signature'),
          ],
        ),
        TabConfig(
          id: 'suppliers',
          label: 'Suppliers',
          columns: [
             ColumnConfig(key: 'name', label: 'Name', type: 'text'),
          ],
        ),
      ],
      dashboard: DashboardConfig(cards: []),
    );

    when(() => mockDriveService.listWorkspaces('root123')).thenAnswer((_) async => [workspace]);
    // user_access sheet maps installed modules for the workspace
    final uaRange = sheets.ValueRange(values: [
      ['id','module_name','dashboard','settings','tabs'],
      ['mod1','Inventory','','mod1_settings','mod1_tabs'],
    ]);
    when(() => mockDriveService.sheetsApi.spreadsheets.values.get('ua1', 'modules!A1:Z'))
        .thenAnswer((_) async => uaRange);
    // Per-user config parts (refactored): settings, dashboard, tabs
    when(() => mockDriveService.getFileId('mod1', 'settings')).thenAnswer((_) async => 'mod1_settings');
    when(() => mockDriveService.getFileModifiedTime('mod1_settings')).thenAnswer((_) async => DateTime.now());
    when(() => mockDriveService.readModuleConfig('mod1_settings')).thenAnswer((_) async => moduleSchema.toJson());
    when(() => mockDriveService.readSettingsById('mod1_settings')).thenAnswer((_) async => moduleSchema.toJson()['settings'] as Map<String, dynamic>);

    when(() => mockDriveService.getFileId('mod1', 'dashboard')).thenAnswer((_) async => 'mod1_dashboard');
    when(() => mockDriveService.getFileModifiedTime('mod1_dashboard')).thenAnswer((_) async => DateTime.now());
    when(() => mockDriveService.readModuleConfig('mod1_dashboard')).thenAnswer((_) async => moduleSchema.toJson());
    when(() => mockDriveService.readDashboardById('mod1_dashboard')).thenAnswer((_) async => moduleSchema.toJson()['dashboard'] as Map<String, dynamic>);

    when(() => mockDriveService.getFileId('mod1', 'tabs')).thenAnswer((_) async => 'mod1_tabs');
    when(() => mockDriveService.getFileModifiedTime('mod1_tabs')).thenAnswer((_) async => DateTime.now());
    when(() => mockDriveService.readModuleConfig('mod1_tabs')).thenAnswer((_) async => moduleSchema.toJson());
    when(() => mockDriveService.readTabsById('mod1_tabs')).thenAnswer((_) async => moduleSchema.toJson()['tabs'] as List<dynamic>);
    when(() => mockDriveService.getFileId('mod1', 'stocks')).thenAnswer((_) async => 'stocks_sheet');
    when(() => mockDriveService.fetchRecords(
      any(), 
      any(), 
      'stocks',
      offset: any(named: 'offset'),
      limit: any(named: 'limit'),
      fetchSubTables: any(named: 'fetchSubTables'),
      descending: any(named: 'descending'),
    )).thenAnswer((_) async => []);
    when(() => mockDriveService.fetchRecords(
      any(), 
      any(), 
      'suppliers',
      offset: any(named: 'offset'),
      limit: any(named: 'limit'),
      fetchSubTables: any(named: 'fetchSubTables'),
      descending: any(named: 'descending'),
    )).thenAnswer((_) async => [
       {'name': 'Apple Inc.', 'id': 's1'},
       {'name': 'Samsung', 'id': 's2'},
    ]);
    when(() => mockDriveService.saveRecord(any(), any(), any(), any())).thenAnswer((_) async => {});

    final driveProvider = TestDriveProvider(mockDriveService);

    Future<void> safePumpAndSettle({int iterations = 10}) async {
      for (int i = 0; i < iterations; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
          ChangeNotifierProvider<DriveProvider>.value(value: driveProvider),
          ChangeNotifierProvider<WorkspaceProvider>(create: (_) => WorkspaceProvider()),
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<SchemaProvider>(create: (_) => SchemaProvider(driveService: mockDriveService)),
        ],
        child: const MaterialApp(
          home: DashboardScreen(userAccessSpreadsheetId: 'ua1'),
        ),
      ),
    );

    await safePumpAndSettle();

    final workspaceProvider = tester.element(find.byType(DashboardScreen)).read<WorkspaceProvider>();
    workspaceProvider.setWorkspace(workspace);
    await safePumpAndSettle();
    
    final inventoryCard = find.text('Inventory');
    await tester.dragUntilVisible(inventoryCard, find.byType(CustomScrollView), const Offset(0, -300));
    // Instead of tapping the dashboard card (which doesn't include per-user sheet ids
    // in this test harness), directly open ModuleScreen with explicit per-user sheet ids
    // so ModuleScreen reads the mocked per-user configs.
    final dashboardContext = tester.element(find.byType(DashboardScreen));
    Navigator.of(dashboardContext).push(MaterialPageRoute(builder: (_) => ModuleScreen(
      module: ModuleSchema(id: moduleFolder.id ?? 'mod1', name: moduleFolder.name ?? 'Inventory', icon: 'inventory', primaryColor: '#3B82F6', version: '1.0', settings: {}, dashboard: DashboardConfig(cards: []), tabs: []),
      settingsSheetId: 'mod1_settings',
      dashboardSheetId: 'mod1_dashboard',
      tabsSheetId: 'mod1_tabs',
    )));
    await safePumpAndSettle();
    
    debugPrint('TEST: Waiting for Blueprint to load...');
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('STOCKS').evaluate().isNotEmpty) break;
    }

    final stocksTab = find.text('STOCKS');
    expect(stocksTab, findsOneWidget);
    await tester.tap(stocksTab);
    await safePumpAndSettle();

    // Use Icons.add as in ModuleTabScreen
    await tester.tap(find.byIcon(Icons.add));
    await safePumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Enter item name'), 'MacBook Pro M3');
    await tester.tap(find.byType(Switch));
    await safePumpAndSettle();

    await tester.tap(find.text('Select Category'));
    await safePumpAndSettle();
    await tester.tap(find.text('Electronics').last);
    await safePumpAndSettle();

    await tester.tap(find.text('Select Date'));
    await safePumpAndSettle();
    await tester.tap(find.text('OK'));
    await safePumpAndSettle();

    await tester.tap(find.widgetWithText(ActionChip, 'Add'));
    await safePumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'New');
    await tester.tap(find.widgetWithText(TextButton, 'Add'));
    await safePumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Enter quantity'), '10');
    await tester.enterText(find.widgetWithText(TextFormField, 'Enter unit cost'), '2500');
    
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text('25000.00').evaluate().isNotEmpty) break;
    }
    expect(find.text('25000.00'), findsOneWidget);

    await tester.dragUntilVisible(find.text('SUPPLIER'), find.byType(SingleChildScrollView).first, const Offset(0, -500));
    await tester.tap(find.text('Select Supplier').last);
    await safePumpAndSettle();

    // Wait for the search dialog to appear and locate its TextField by hint text
    final searchFieldFinder = find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == 'Type to search (min 2 chars)');
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (searchFieldFinder.evaluate().isNotEmpty) break;
    }

    expect(searchFieldFinder, findsOneWidget);

    // Type a short query (>=2 chars) and wait for results to populate
    await tester.enterText(searchFieldFinder, 'Ap');
    for (int i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Apple Inc.').evaluate().isNotEmpty) break;
    }
    expect(find.text('Apple Inc.'), findsOneWidget);
    await tester.tap(find.text('Apple Inc.'));
    await safePumpAndSettle();

    await tester.tap(find.text('Add Item'));
    await safePumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Enter component name'), 'Screen');
    await tester.tap(find.text('Save Item'));
    await safePumpAndSettle();

    // Verify Photo Field Interaction
    final photoLabel = find.text('PHOTO');
    await tester.dragUntilVisible(photoLabel, find.byType(SingleChildScrollView).first, const Offset(0, -300));
    await safePumpAndSettle();
    
    await tester.tap(find.text('Tap to pick or capture image'));
    await safePumpAndSettle();
    
    expect(find.text('Select Image Source'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    
    // Dismiss the bottom sheet by tapping the scrim (top-left)
    await tester.tapAt(const Offset(20, 20));
    await safePumpAndSettle();

    await tester.dragUntilVisible(find.text('BARCODE'), find.byType(SingleChildScrollView).first, const Offset(0, -300));
    await tester.enterText(find.widgetWithText(TextFormField, 'Scan or enter code'), 'SN123456');

    debugPrint('TEST: Saving form...');
    await tester.tap(find.text('SAVE'));
    
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    verify(() => mockDriveService.saveRecord(
      'mod1',
      'Inventory',
      'stocks',
      any(that: isA<Map<String, dynamic>>()
        .having((m) => m['item'], 'item', 'MacBook Pro M3')
        .having((m) => m['category'], 'category', 'Electronics')
        .having((m) => m['qty'].toString(), 'qty', '10')
        .having((m) => m['cost'].toString(), 'cost', '2500')
        .having((m) => m['supplier'], 'supplier', 's1')
        .having((m) => m['barcode'], 'barcode', 'SN123456')
      ),
    )).called(1);

    debugPrint('TEST: Success!');
  });
}
