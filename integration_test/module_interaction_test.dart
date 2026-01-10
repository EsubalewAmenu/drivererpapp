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
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:drivererpapp/screens/dashboard_screen.dart';
import 'package:drivererpapp/models/company_model.dart';
import 'package:drivererpapp/models/schema_models.dart';
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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const DashboardScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }

  testWidgets('Module Interaction: List -> Detail -> Edit -> Verify Refresh Flow', (tester) async {
    // Set a standard mobile surface size for consistent hit-testing
    await tester.binding.setSurfaceSize(const Size(1080, 1920));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final workspaceFile = drive.File()
      ..id = 'ws1'
      ..name = 'ERP Lab';
    final workspaceProvider = WorkspaceProvider();
    workspaceProvider.setWorkspace(workspaceFile);
    
    final driveProvider = TestDriveProvider(mockDriveService);

    // 1. Mock Module List and Config
    final moduleFile = drive.File()..id = 'mod1'..name = 'Inventory';
    when(() => mockDriveService.listModules('ws1')).thenAnswer((_) async => [moduleFile]);
    when(() => mockDriveService.getFileId('mod1', 'config')).thenAnswer((_) async => 'config_id');
    
    final moduleConfig = {
      'id': 'mod1',
      'name': 'Inventory',
      'icon': 'inventory',
      'primaryColor': '#F59E0B',
      'version': '1.0.0',
      'tabs': [
        {
          'id': 'items', 
          'label': 'Items', 
          'columns': [
            {'key': 'name', 'label': 'Name', 'type': 'text'},
            {'key': 'qty', 'label': 'Quantity', 'type': 'number'}
          ]
        }
      ],
      'dashboard': {'cards': []},
      'settings': {}
    };
    when(() => mockDriveService.readModuleConfig('config_id')).thenAnswer((_) async => moduleConfig);

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

    // 3. Start App
    await tester.pumpWidget(createTestWidget(
      workspaceProvider: workspaceProvider,
      driveProvider: driveProvider,
    ));
    
    // Wait for initial load and animations
    await tester.pumpAndSettle();
    
    // Check if we see the modules. Sometimes FutureBuilder needs an extra pump.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // 4. Open Inventory Module
    // Check for "Inventory" text. 
    final inventoryFinder = find.text('Inventory');
    await tester.ensureVisible(inventoryFinder);
    expect(inventoryFinder, findsOneWidget, reason: 'Inventory module card should be on Dashboard');
    
    await tester.tap(inventoryFinder);
    
    // Wait for the ModuleScreen to load and its intro sync to finish
    // ModuleScreen has a delayed sync and then its own FutureBuilder/State
    for(int i=0; i<10; i++) {
       await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pumpAndSettle();

    // First tab is Dashboard, we need to switch to ITEMS tab
    // The tab bar labels are uppercased in ModuleScreen
    final itemsTabFinder = find.text('ITEMS');
    expect(itemsTabFinder, findsOneWidget, reason: 'ITEMS tab should be visible in ModuleScreen');
    
    await tester.tap(itemsTabFinder);
    await tester.pumpAndSettle();
    
    // ModuleTabScreen has a 500ms delay in initState before _loadData
    for(int i=0; i<5; i++) {
       await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pumpAndSettle();

    // Verify record appears in list
    final recordInListFinder = find.text('Widget A');
    await tester.ensureVisible(recordInListFinder.first);
    expect(recordInListFinder, findsAtLeast(1)); 

    // 5. Open Record Detail
    // Tap the first occurrence (the one in the list)
    await tester.tap(recordInListFinder.first);
    await tester.pumpAndSettle();

    expect(find.text('DETAILS'), findsOneWidget);
    // In details, Widget A might be in header and a field
    expect(find.text('Widget A'), findsAtLeast(1));

    // 6. Open Edit Form
    // RecordDetailScreen uses Icons.edit_outlined
    final editIconFinder = find.byIcon(Icons.edit_outlined);
    expect(editIconFinder, findsOneWidget);
    await tester.tap(editIconFinder);
    await tester.pumpAndSettle();

    // Tab label in DynamicFormScreen is usually "EDIT [TAB_LABEL]"
    expect(find.text('EDIT ITEMS'), findsOneWidget);

    // 7. Update Name field
    // TextFormField with 'Widget A' as its initial value
    final nameField = find.widgetWithText(TextFormField, 'Widget A');
    await tester.ensureVisible(nameField);
    expect(nameField, findsOneWidget);
    await tester.enterText(nameField, 'Widget Updated');
    await tester.pumpAndSettle();
    
    // Mock Save
    when(() => mockDriveService.saveRecord(any(), any(), any(), any())).thenAnswer((_) async => {});

    // Save
    final saveButtonFinder = find.text('SAVE');
    await tester.ensureVisible(saveButtonFinder);
    expect(saveButtonFinder, findsOneWidget);
    await tester.tap(saveButtonFinder);
    await tester.pumpAndSettle();

    // 8. Verify Detail View shows updated data immediately
    // RecordDetailScreen listens for the return value and updates state
    expect(find.text('Widget Updated'), findsAtLeast(1));

    // 9. Go back and verify list is refreshed
    // The list refreshes because RecordDetailScreen pops with true
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

    // Navigate back to Module list
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    
    // ModuleTabScreen should have refreshed data
    expect(find.text('Widget Updated'), findsOneWidget);
    expect(find.text('Widget A'), findsNothing);

    // 10. Test Search Functionality in the list
    // In ModuleFilterBar, search is a TextField always visible
    final searchField = find.byType(TextField);
    await tester.enterText(searchField, 'Updated');
    await tester.pumpAndSettle();
    
    // Search has a debounce of 600ms
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();
    
    // The sync logic might call fetchRecords with searchQuery
    verify(() => mockDriveService.fetchRecords(
      any(), any(), any(), 
      searchQuery: 'Updated',
      offset: any(named: 'offset'),
      limit: any(named: 'limit'),
      fetchSubTables: any(named: 'fetchSubTables'),
      descending: any(named: 'descending'),
      quickFilter: any(named: 'quickFilter'),
    )).called(greaterThanOrEqualTo(1));
  });
}

