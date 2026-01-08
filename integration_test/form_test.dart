import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;
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
import 'package:drivererpapp/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthService extends Mock implements AuthService {}
class MockDriveService extends Mock implements DriveService {}
class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class TestDriveProvider extends DriveProvider {
  final DriveService? _mockService;
  TestDriveProvider(this._mockService);
  
  @override
  DriveService? get driveService => _mockService;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthService mockAuthService;
  late MockDriveService mockDriveService;
  late MockGoogleSignInAccount mockAccount;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockAuthService = MockAuthService();
    mockDriveService = MockDriveService();
    mockAccount = MockGoogleSignInAccount();

    when(() => mockAuthService.currentUser).thenReturn(mockAccount);
    when(() => mockAccount.displayName).thenReturn('Test User');
    when(() => mockAccount.email).thenReturn('test@example.com');
    
    when(() => mockDriveService.getFileId(any(), any())).thenAnswer((_) async => null);
    when(() => mockDriveService.checkRootFolder()).thenAnswer((_) async => 'root123');
    
    AppTheme.useGoogleFonts = false;

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
    when(() => mockDriveService.listModules('ws1')).thenAnswer((_) async => [moduleFolder]);
    when(() => mockDriveService.getFileId('mod1', 'config')).thenAnswer((_) async => 'config_file');
    when(() => mockDriveService.getFileModifiedTime('config_file')).thenAnswer((_) async => DateTime.now());
    when(() => mockDriveService.readModuleConfig('config_file')).thenAnswer((_) async => moduleSchema.toJson());
    when(() => mockDriveService.getFileId('mod1', 'stocks')).thenAnswer((_) async => 'stocks_sheet');
    when(() => mockDriveService.fetchRecords(
      any(), 
      any(), 
      'stocks',
      offset: any(named: 'offset'),
      limit: any(named: 'limit'),
      fetchSubTables: any(named: 'fetchSubTables'),
    )).thenAnswer((_) async => []);
    when(() => mockDriveService.fetchRecords(
      any(), 
      any(), 
      'suppliers',
      offset: any(named: 'offset'),
      limit: any(named: 'limit'),
      fetchSubTables: any(named: 'fetchSubTables'),
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
          home: DashboardScreen(),
        ),
      ),
    );

    await safePumpAndSettle();

    final workspaceProvider = tester.element(find.byType(DashboardScreen)).read<WorkspaceProvider>();
    workspaceProvider.setWorkspace(workspace);
    await safePumpAndSettle();
    
    final inventoryCard = find.text('Inventory');
    await tester.dragUntilVisible(inventoryCard, find.byType(CustomScrollView), const Offset(0, -300));
    await tester.tap(inventoryCard);
    
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
    await tester.tap(find.text('Apple Inc.'));
    await safePumpAndSettle();

    await tester.tap(find.text('Add Item'));
    await safePumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Enter component name'), 'Screen');
    await tester.tap(find.text('Save Item'));
    await safePumpAndSettle();

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
        .having((m) => m['supplier'], 'supplier', 'Apple Inc.')
        .having((m) => m['barcode'], 'barcode', 'SN123456')
      ),
    )).called(1);

    debugPrint('TEST: Success!');
  });
}
