import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/theme/app_theme.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/providers/sync_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:drivererpapp/screens/landing_screen.dart';
import 'package:drivererpapp/screens/dynamic_form_screen.dart';

class MockAuthService extends Mock implements AuthService {}
class MockDriveService extends Mock implements DriveService {}
class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class TestDriveProvider extends DriveProvider {
  final DriveService? mockService;
  TestDriveProvider(this.mockService);
  
  @override
  DriveService? get driveService => mockService;
  @override
  void updateClient(http.Client? client) {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthService mockAuthService;
  late MockDriveService mockDriveService;
  late MockGoogleSignInAccount mockUser;

  setUpAll(() {
    AppTheme.useGoogleFonts = false;
    registerFallbackValue(drive.File());
    registerFallbackValue(ModuleSchema(
      id: '', name: '', icon: '', primaryColor: '', version: '',
      settings: {}, dashboard: DashboardConfig(kpiCards: []), tabs: []
    ));
  });

  setUp(() {
    mockAuthService = MockAuthService();
    mockDriveService = MockDriveService();
    mockUser = MockGoogleSignInAccount();

    when(() => mockUser.displayName).thenReturn('Test User');
    when(() => mockUser.email).thenReturn('test@example.com');
    when(() => mockAuthService.currentUser).thenReturn(mockUser);
    when(() => mockAuthService.isAuthenticated).thenReturn(false);
    when(() => mockAuthService.signInSilently()).thenAnswer((_) async {});
    
    when(() => mockAuthService.signIn()).thenAnswer((_) async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
    });

    when(() => mockDriveService.checkRootFolder()).thenAnswer((_) async => 'root123');
    when(() => mockDriveService.listWorkspaces(any())).thenAnswer((_) async => []);
  });

  testWidgets('End-to-End Form Submission Flow', (tester) async {
    final workspace = drive.File()..id = 'ws1'..name = 'ERP Workspace';
    final moduleFolder = drive.File()..id = 'mod1'..name = 'Inventory';
    
    final moduleSchema = ModuleSchema(
      id: 'mod1',
      name: 'Inventory',
      icon: 'inventory',
      primaryColor: '#F59E0B',
      version: '1.0.0',
      settings: {},
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
      dashboard: DashboardConfig(kpiCards: []),
    );

    when(() => mockDriveService.listWorkspaces('root123')).thenAnswer((_) async => [workspace]);
    when(() => mockDriveService.listModules('ws1')).thenAnswer((_) async => [moduleFolder]);
    when(() => mockDriveService.getFileId('mod1', 'config')).thenAnswer((_) async => 'config_file');
    when(() => mockDriveService.readModuleConfig('config_file')).thenAnswer((_) async => moduleSchema.toJson());
    when(() => mockDriveService.getFileId('mod1', 'stocks')).thenAnswer((_) async => 'stocks_sheet');
    when(() => mockDriveService.fetchRecords(any(), any(), 'stocks')).thenAnswer((_) async => []);
    when(() => mockDriveService.fetchRecords(any(), any(), 'suppliers')).thenAnswer((_) async => [
       {'name': 'Apple Inc.', 'id': 's1'},
       {'name': 'Samsung', 'id': 's2'},
    ]);
    when(() => mockDriveService.saveRecord(any(), any(), any(), any())).thenAnswer((_) async => {});

    final driveProvider = TestDriveProvider(mockDriveService);
    final syncProvider = SyncProvider()..updateDriveProvider(driveProvider);


    // Helper to log and pump
    Future<void> pumpFor(Duration duration) async {
       debugPrint('TEST: Pumping for $duration...');
       await tester.pump(duration);
    }
    
    // Helper to safely wait
    Future<void> safePumpAndSettle() async {
      debugPrint('TEST: Safe Pump And Settle...');
      // Instead of pumpAndSettle that can hang, use a limited pump loop or pump with duration
      // But pumpAndSettle triggers frame scheduling.
      // We try a short pumpAndSettle first with timeout
      try {
        await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 2));
      } catch (e) {
        debugPrint('TEST: pumpAndSettle timed out (likely due to animation) - ignoring and continuing');
        // If it times out, we just pump one last time
        await tester.pump();
      }
    }

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
          ChangeNotifierProvider<WorkspaceProvider>(create: (_) => WorkspaceProvider()),
          ChangeNotifierProvider<DriveProvider>.value(value: driveProvider),
          ChangeNotifierProvider<SyncProvider>.value(value: syncProvider),
        ],
        child: const MaterialApp(
          home: LandingScreen(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
    debugPrint('TEST: Widget Pumped');
    await safePumpAndSettle();

    final continueButton = find.text('Continue with Google');
    expect(continueButton, findsOneWidget);
    debugPrint('TEST: Found Continue Button');
    await tester.tap(continueButton);
    
    // Do NOT use pumpAndSettle here because SystemScanningScreen has an infinite CircularProgressIndicator
    // We pump enough time for the mocks and delays in SystemScanningScreen to finish
    await pumpFor(const Duration(milliseconds: 500)); // Process tap and show dialog/navigate
    await pumpFor(const Duration(seconds: 4)); // Wait for SystemScanningScreen delays 
    
    // Now we should be on WorkspaceSelectorScreen
    debugPrint('TEST: Waiting for ERP Workspace');
    final workspaceFinder = find.text('ERP Workspace');
    
    // Sometimes it takes longer
    for(int i=0; i<10; i++) {
        if(workspaceFinder.evaluate().isNotEmpty) break;
        await tester.pump(const Duration(milliseconds: 500));
    }
    
    expect(workspaceFinder, findsOneWidget);
    debugPrint('TEST: Found ERP Workspace');
    await tester.tap(workspaceFinder);
    
    debugPrint('TEST: Tapped ERP Workspace, waiting for dashboard...');
    // Dashboard load delay
    await pumpFor(const Duration(seconds: 2));
    await safePumpAndSettle();
    
    // Tap the Inventory card
     debugPrint('TEST: Searching for Inventory card');
    final inventoryCard = find.descendant(
      of: find.byType(GridView),
      matching: find.text('Inventory'),
    );
     // Wait for it
    for(int i=0; i<10; i++) {
        if(inventoryCard.evaluate().isNotEmpty) break;
        await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.tap(inventoryCard.first);
    await safePumpAndSettle();

    debugPrint('TEST: Tapped Inventory, waiting for Stocks tab...');
    final stocksTab = find.text('STOCKS');
     for(int i=0; i<10; i++) {
        if(stocksTab.evaluate().isNotEmpty) break;
        await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.tap(stocksTab);
    await safePumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await safePumpAndSettle();
    debugPrint('TEST: Opened Form');

    // 1. Text Field
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter item name'), 
        'MacBook Pro M3'
    );
    await safePumpAndSettle();

    // 2. Boolean Field
    await tester.tap(find.byType(Switch));
    await safePumpAndSettle();

    // 3. Dropdown Field
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await safePumpAndSettle();
    await tester.tap(find.text('Electronics').last);
    await safePumpAndSettle();

    // 4. Date Field
    await tester.dragUntilVisible(
      find.text('ACQUISITION DATE'),
      find.byType(SingleChildScrollView).first,
      const Offset(0, -500),
    );
    await tester.tap(find.text('Select Date')); // Initial text
    await safePumpAndSettle();
    await tester.tap(find.text('OK')); // Accepts current date
    await safePumpAndSettle();

    // 5. List Field
    await tester.dragUntilVisible(
      find.text('TAGS'),
      find.byType(SingleChildScrollView).first,
      const Offset(0, -500),
    );
    await tester.tap(find.widgetWithText(ActionChip, 'Add'));
    await safePumpAndSettle();
    
    await tester.enterText(find.byType(TextField).last, 'New');
    await tester.tap(find.widgetWithText(TextButton, 'Add')); // Button in dialog
    await safePumpAndSettle();

    // 6. Number & Currency Fields (Triggers Formula)
    await tester.dragUntilVisible(
      find.text('QUANTITY'),
      find.byType(SingleChildScrollView).first,
      const Offset(0, -500),
    );
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter quantity'),
        '10'
    );
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter unit cost'),
        '2500'
    );
    // Allow formula to calculate
    await pumpFor(const Duration(milliseconds: 500));

    // 7. Formula Check
    expect(find.text('25000.00'), findsOneWidget);

    // 8. Relation Field
    await tester.dragUntilVisible(
      find.text('SUPPLIER'),
      find.byType(SingleChildScrollView).first,
      const Offset(0, -500),
    );
    await tester.tap(find.text('Select Supplier').last); // Assuming default hint
    await safePumpAndSettle();
    // Wait for mock load? The mock is instant but we pumped.
    // Dialog should be open
    await tester.tap(find.text('Apple Inc.')); 
    await safePumpAndSettle();

    // 9. Table Field
    await tester.dragUntilVisible(
      find.text('COMPONENTS'),
      find.descendant(of: find.byType(DynamicFormScreen), matching: find.byType(SingleChildScrollView)),
      const Offset(0, -500),
    );
    await tester.tap(find.text('Add Item'));
    await safePumpAndSettle();
    
    // In Dialog
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter component name'),
        'Screen'
    );
    await tester.tap(find.text('Save Item'));
    await safePumpAndSettle();
    expect(find.text('Screen'), findsOneWidget); // Should appear in list
    expect(find.text('Save Item'), findsNothing); // Ensure dialog closed

    // 10. Scanner Field
    await tester.dragUntilVisible(
      find.text('BARCODE'),
      find.descendant(of: find.byType(DynamicFormScreen), matching: find.byType(SingleChildScrollView)),
      const Offset(0, -500),
    );
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Scan or enter code'),
        'SN123456'
    );

    // 11. Media & Signature Placeholders
    await tester.dragUntilVisible(
      find.text('SIGNATURE'),
      find.descendant(of: find.byType(DynamicFormScreen), matching: find.byType(SingleChildScrollView)),
      const Offset(0, -500),
    );
    expect(find.text('Tap to sign'), findsWidgets);
    
    // Save
    debugPrint('TEST: Saving form...');
    await tester.tap(find.text('SAVE'));
    await safePumpAndSettle();


    verify(() => mockDriveService.saveRecord(
      'mod1',
      'Inventory',
      'stocks',
      any(that: isA<Map<String, dynamic>>()
        .having((m) => m['item'], 'item', 'MacBook Pro M3')
        .having((m) => m['active'], 'active', true)
        .having((m) => m['category'], 'category', 'Electronics')
        .having((m) => m['qty'], 'qty', '10')
        .having((m) => m['tags'], 'tags', contains('New')) // Verify tags are saved
        .having((m) => m['cost'], 'cost', '2500')
        // Formula fields are typically not saved to payload if they are calc-only, 
        // OR they are computed and saved. 
        // DynamicFormScreen saves _formData. 
        // FormulaField does `onCalculated`. Currently `DynamicFormScreen` doesn't listen to `onCalculated` 
        // to update `_formData`... Wait, I should check that.
        // Let's check `DynamicFormScreen` implementation again.
      ),
    )).called(1);

    expect(find.text('STOCKS'), findsOneWidget);
  });
}
