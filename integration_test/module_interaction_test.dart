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
import 'package:drivererpapp/screens/module_screen.dart';
import 'package:drivererpapp/models/company_model.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthService mockAuthService;
  late MockDriveService mockDriveService;
  late MockValuesResource mockValues;

  setUpAll(() {
    initTestEnvironment();
  });

  setUp(() {
    final mocks = createTestMocks();
    mockAuthService = mocks.auth;
    mockDriveService = mocks.drive;
    mockValues = mocks.values;
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
        ChangeNotifierProvider<SchemaProvider>(create: (_) => SchemaProvider(driveService: mockDriveService, userEmail: 'user@example.com')),
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

  testWidgets('Module Interaction: List -> Detail -> Edit -> Verify Refresh Flow', (tester) async {

    final workspaceFile = drive.File()
      ..id = 'ws1'
      ..name = 'ERP Lab';
    final workspaceProvider = WorkspaceProvider();
    workspaceProvider.setWorkspace(workspaceFile);
    
    final driveProvider = TestDriveProvider(mockDriveService);

    // 1. Mock Module List and Config (Multi-spreadsheet model)
    final uaRange = sheets.ValueRange(values: [
      ['id','module_name','dashboard','settings','tabs'],
      ['mod1','Inventory','', 'conf1', 'tabs1'],
    ]);
    
    // Stub the values resource directly to avoid chain lookup issues
    when(() => mockValues.get('ua1', 'modules!A1:Z')).thenAnswer((_) async => uaRange);
    
    // Mock the discrete parts
    when(() => mockDriveService.readSettingsById('conf1')).thenAnswer((_) async => {
      'name': {'value': 'Inventory'},
      'version': {'value': '1.0.0'},
    });
    
    final List<Map<String, dynamic>> mockTabs = [
      {
        'id': 'items',
        'label': 'ITEMS',
        'fileId': 'sheet_mod1',
        'columns': [
          {'key': 'item_id', 'label': 'ID', 'type': 'text'},
          {'key': 'item_name', 'label': 'Name', 'type': 'text'},
          {'key': 'qty', 'label': 'Quantity', 'type': 'number'},
        ],
      },
    ];
    when(() => mockDriveService.readTabsById('tabs1')).thenAnswer((_) async => mockTabs);
    when(() => mockDriveService.readDashboardById(any())).thenAnswer((_) async => {'cards': []});

    // 2. Mock Records (using the tab's specific sheet spreadsheet id)
    final records = [
      {'item_id': 'r1', 'item_name': 'Widget A', 'qty': 10},
    ];
    
    when(() => mockDriveService.fetchRecordsBySpreadsheetId(
          'sheet_mod1', 
          'items',
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
      userAccessSpreadsheetId: 'ua1',
    ));
    
    await tester.pumpAndSettle();
    
    // Verify Dashboard loaded the module
    expect(find.text('Inventory'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Inventory'),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );
    await tester.tap(find.text('Inventory'));
    await tester.pumpAndSettle();

    // 4. Verify Module Screen & Tabs switch
    final itemsTabFinder = find.text('ITEMS');
    expect(itemsTabFinder, findsOneWidget, reason: 'ITEMS tab should be visible in ModuleScreen');
    await tester.tap(itemsTabFinder);
    await tester.pumpAndSettle();

    // Verify record appears in list
    expect(find.text('Widget A'), findsOneWidget);

    // 5. Open Record Detail
    await tester.tap(find.text('Widget A'));
    await tester.pumpAndSettle();

    expect(find.text('DETAILS'), findsOneWidget);
    expect(find.text('Widget A'), findsAtLeast(1));

    // 6. Go to Edit
    final editButton = find.byIcon(Icons.edit_outlined);
    expect(editButton, findsOneWidget);
    await tester.tap(editButton);
    await tester.pumpAndSettle();

    // 7. Verify Form & Update
    final nameField = find.widgetWithText(TextFormField, 'Widget A');
    expect(nameField, findsOneWidget);
    
    await tester.enterText(nameField, 'Widget A Updated');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Mock successful save
    when(() => mockDriveService.saveRecordBySpreadsheetId(any(), any(), any()))
        .thenAnswer((_) async => {});

    final saveButton = find.text('SAVE');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // 8. Verify back in detail and see updated name
    // Mock the refresh fetch
    final updatedRecords = [
      {'item_id': 'r1', 'item_name': 'Widget A Updated', 'qty': 10},
    ];
    when(() => mockDriveService.fetchRecordsBySpreadsheetId(
          'sheet_mod1', 
          'items',
          offset: any(named: 'offset'), 
          limit: any(named: 'limit'), 
          fetchSubTables: any(named: 'fetchSubTables'), 
          descending: any(named: 'descending'),
          searchQuery: any(named: 'searchQuery'),
          quickFilter: any(named: 'quickFilter'),
        )).thenAnswer((_) async => List<Map<String, dynamic>>.from(updatedRecords));

    // Need to trigger a rebuild or wait for the detail screen to refresh
    // Detailed record view should have updated
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    
    expect(find.text('Widget A Updated'), findsAtLeast(1));
  });
}

