import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/module/module_tab_screen.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/providers/theme_provider.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:drivererpapp/services/schema_service.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';

class MockDriveProvider extends Mock implements DriveProvider {}
class MockDriveService extends Mock implements DriveService {}
class MockThemeProvider extends Mock implements ThemeProvider {}
class MockSchemaProvider extends Mock implements SchemaProvider {}
class MockSchemaService extends Mock implements SchemaService {}
class MockWorkspaceProvider extends Mock implements WorkspaceProvider {}
class FakeModuleSchema extends Fake implements ModuleSchema {}
class FakeQuickFilter extends Fake implements QuickFilter {}
class FakeListTemplateConfig extends Fake implements ListTemplateConfig {}
class FakeDetailTemplateConfig extends Fake implements DetailTemplateConfig {}

void main() {
  late MockDriveProvider mockDriveProvider;
  late MockDriveService mockDriveService;
  late MockThemeProvider mockThemeProvider;
  late MockSchemaProvider mockSchemaProvider;
  late MockSchemaService mockSchemaService;
  late MockWorkspaceProvider mockWorkspaceProvider;
  late ModuleSchema testModule;
  late TabConfig testTab;

  setUpAll(() {
    registerFallbackValue(FakeModuleSchema());
    registerFallbackValue(FakeQuickFilter());
    registerFallbackValue(FakeListTemplateConfig());
    registerFallbackValue(FakeDetailTemplateConfig());
  });

  setUp(() {
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();
    mockThemeProvider = MockThemeProvider();
    mockSchemaProvider = MockSchemaProvider();
    mockSchemaService = MockSchemaService();
    mockWorkspaceProvider = MockWorkspaceProvider();

    // Use a large enough surface size for all tests
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.implicitView!.physicalSize = const Size(1024, 768);
    binding.platformDispatcher.implicitView!.devicePixelRatio = 1.0;

    testTab = TabConfig(id: 't1', label: 'Tab 1', columns: [
      ColumnConfig(key: 'name', label: 'Name', type: 'text'),
    ]);

    testModule = ModuleSchema(
      id: 'mod1',
      name: 'Test Module',
      icon: 'inventory',
      primaryColor: '#F59E0B',
      version: '1.0.0',
      settings: {},
      tabs: [testTab],
      dashboard: DashboardConfig(cards: []),
    );

    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockThemeProvider.themeMode).thenReturn(ThemeMode.light);
    when(() => mockSchemaProvider.service).thenReturn(mockSchemaService);
    when(() => mockWorkspaceProvider.currentWorkspace).thenReturn(null);
    // default getFromMemory -> null unless explicitly set in a test
    when(() => mockSchemaProvider.getFromMemory(any())).thenReturn(null);
    // default cached config is null
    when(() => mockSchemaService.getCachedConfig(any())).thenAnswer((_) async => null);
    when(() => mockSchemaService.saveModuleConfig(any(), any())).thenAnswer((_) async {});
    when(() => mockSchemaProvider.updateMemoryCache(any(), any())).thenReturn(null);
    when(() => mockDriveService.fetchRecords(
      any(), any(), any(),
      offset: any(named: 'offset'),
      limit: any(named: 'limit'),
      fetchSubTables: any(named: 'fetchSubTables'),
      descending: any(named: 'descending'),
      searchQuery: any(named: 'searchQuery'),
      quickFilter: any(named: 'quickFilter'),
    )).thenAnswer((_) async => [
      {'name': 'Record 1', 'record_id': '100'},
      {'name': 'Record 2', 'record_id': '200'},
    ]);
  });

  Widget createModuleTabScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: mockThemeProvider),
        ChangeNotifierProvider<SchemaProvider>.value(value: mockSchemaProvider),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ModuleTabScreen(
            tab: testTab,
            primaryColor: Colors.blue,
            module: testModule,
          ),
        ),
      ),
    );
  }

  testWidgets('ModuleTabScreen loads and displays records', (WidgetTester tester) async {
    await tester.pumpWidget(createModuleTabScreen());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    
    await tester.pumpAndSettle();

    expect(find.text('Record 1'), findsOneWidget);
    expect(find.text('Record 2'), findsOneWidget);
  });

  testWidgets('ModuleTabScreen search filters records', (WidgetTester tester) async {
    await tester.pumpWidget(createModuleTabScreen());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Record 1');
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

    // One in the TextField, one in the list tile
    expect(find.text('Record 1'), findsNWidgets(2));
    expect(find.text('Record 2'), findsNothing);
  });

  testWidgets('ModuleTabScreen allows custom filtering', (WidgetTester tester) async {
    // For stability in headless tests, inject the custom quick filter directly
    final customFilter = QuickFilter(
      label: 'Name Equals Record 2',
      key: 'f1',
      field: 'name',
      operator: '==',
      value: 'Record 2',
    );

    // Create a module where the tab already contains the quick filter
    final tabWithFilter = testTab.copyWith(quickFilters: [customFilter]);
    final moduleWithFilter = ModuleSchema(
      id: testModule.id,
      name: testModule.name,
      icon: testModule.icon,
      primaryColor: testModule.primaryColor,
      version: testModule.version,
      settings: testModule.settings,
      dashboard: testModule.dashboard,
      tabs: [tabWithFilter],
    );

    when(() => mockSchemaProvider.getFromMemory(any())).thenReturn(moduleWithFilter);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
          ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
          ChangeNotifierProvider<ThemeProvider>.value(value: mockThemeProvider),
          ChangeNotifierProvider<SchemaProvider>.value(value: mockSchemaProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ModuleTabScreen(
              tab: tabWithFilter,
              primaryColor: Colors.blue,
              module: moduleWithFilter,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Ensure the filter chip exists
    expect(find.text('Name Equals Record 2'), findsOneWidget);

    // Activate the filter
    await tester.tap(find.text('Name Equals Record 2'));
    await tester.pumpAndSettle();

    // Filtering should apply and show only Record 2
    expect(find.text('Record 2'), findsOneWidget);
    expect(find.text('Record 1'), findsNothing);
  });

  testWidgets('ModuleTabScreen loads more data on scroll', (WidgetTester tester) async {
    // Setup specific mock for this test
    reset(mockDriveService);
    
    // First page (20 items)
    when(() => mockDriveService.fetchRecords(
      'mod1', 
      'Test Module', 
      't1',
      offset: 0,
      limit: any(named: 'limit'),
      fetchSubTables: any(named: 'fetchSubTables'),
      descending: any(named: 'descending'),
      searchQuery: any(named: 'searchQuery'),
      quickFilter: any(named: 'quickFilter'),
    )).thenAnswer((_) async => List.generate(20, (i) => {'name': 'Item ${20-i}', 'record_id': '${1020-i}'}));

    // Second page (1 item)
    when(() => mockDriveService.fetchRecords(
      'mod1', 
      'Test Module', 
      't1',
      offset: 20,
      limit: any(named: 'limit'),
      fetchSubTables: any(named: 'fetchSubTables'),
      descending: any(named: 'descending'),
      searchQuery: any(named: 'searchQuery'),
      quickFilter: any(named: 'quickFilter'),
    )).thenAnswer((_) async => [{'name': 'Item 0', 'record_id': '1000'}]);

    await tester.pumpWidget(createModuleTabScreen());
    await tester.pumpAndSettle();

    // Verify first page loaded (check first item in desc order)
    expect(find.text('Item 20'), findsOneWidget);
    
    // Scroll to the bottom to trigger load more
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    
    // Verification: Trigger load more
    verify(() => mockDriveService.fetchRecords(
      any(), any(), any(), 
      offset: 20, 
      limit: any(named: 'limit'), 
      fetchSubTables: any(named: 'fetchSubTables'),
      descending: any(named: 'descending'),
      searchQuery: any(named: 'searchQuery'),
      quickFilter: any(named: 'quickFilter'),
    )).called(greaterThanOrEqualTo(1));

    await tester.pumpAndSettle();

    // Verify item from second page exists
    expect(find.text('Item 0'), findsOneWidget);
  });

  testWidgets('ModuleTabScreen displays error and allows retry', (WidgetTester tester) async {
    when(() => mockDriveService.fetchRecords(any(), any(), any(),
      offset: any(named: 'offset'),
      limit: any(named: 'limit'),
      fetchSubTables: any(named: 'fetchSubTables'),
      descending: any(named: 'descending'),
      searchQuery: any(named: 'searchQuery'),
      quickFilter: any(named: 'quickFilter'),
    )).thenThrow(Exception('Failed to load'));

    await tester.pumpWidget(createModuleTabScreen());
    await tester.pumpAndSettle();

    expect(find.text('Failed to load records. Please try again.'), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

    // Setup success for retry
    when(() => mockDriveService.fetchRecords(any(), any(), any(),
      offset: any(named: 'offset'),
      limit: any(named: 'limit'),
      fetchSubTables: any(named: 'fetchSubTables'),
      descending: any(named: 'descending'),
      searchQuery: any(named: 'searchQuery'),
      quickFilter: any(named: 'quickFilter'),
    )).thenAnswer((_) async => [{'name': 'Retried Record', 'record_id': '300'}]);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Retried Record'), findsOneWidget);
  });

  testWidgets('ModuleTabScreen displays offline error message', (WidgetTester tester) async {
    when(() => mockDriveService.fetchRecords(any(), any(), any(),
      offset: any(named: 'offset'),
      limit: any(named: 'limit'),
      fetchSubTables: any(named: 'fetchSubTables'),
      descending: any(named: 'descending'),
      searchQuery: any(named: 'searchQuery'),
      quickFilter: any(named: 'quickFilter'),
    )).thenThrow(Exception('SocketException: failed host lookup'));

    await tester.pumpWidget(createModuleTabScreen());
    await tester.pumpAndSettle();

    expect(find.text('Records unavailable (Offline)'), findsOneWidget);
  });

  testWidgets('ModuleTabScreen handles load more error and allows retry within list', (WidgetTester tester) async {
    // First page success
    when(() => mockDriveService.fetchRecords(any(), any(), any(),
      offset: 0,
      limit: any(named: 'limit'),
      fetchSubTables: any(named: 'fetchSubTables'),
      descending: any(named: 'descending'),
      searchQuery: any(named: 'searchQuery'),
      quickFilter: any(named: 'quickFilter'),
    )).thenAnswer((_) async => List.generate(20, (i) => {'name': 'Item $i', 'record_id': '$i'}));

    // Second page fails
    when(() => mockDriveService.fetchRecords(any(), any(), any(),
      offset: 20,
      limit: any(named: 'limit'),
      fetchSubTables: any(named: 'fetchSubTables'),
      descending: any(named: 'descending'),
      searchQuery: any(named: 'searchQuery'),
      quickFilter: any(named: 'quickFilter'),
    )).thenThrow(Exception('Load more failed'));

    await tester.pumpWidget(createModuleTabScreen());
    await tester.pumpAndSettle();

    // Scroll to bottom
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Failed to load more records'), findsOneWidget);
    
    // Setup success for second page retry
    when(() => mockDriveService.fetchRecords(any(), any(), any(),
      offset: 20,
      limit: any(named: 'limit'),
      fetchSubTables: any(named: 'fetchSubTables'),
      descending: any(named: 'descending'),
      searchQuery: any(named: 'searchQuery'),
      quickFilter: any(named: 'quickFilter'),
    )).thenAnswer((_) async => [{'name': 'More Item', 'record_id': '100'}]);

    // Manual scroll to finding the retry button to avoid "Too many elements" issues with scrollUntilVisible
    for (int i = 0; i < 10; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pump();
      if (find.text('Retry').evaluate().isNotEmpty) break;
    }

    final retryButton = find.descendant(
      of: find.byType(ListView),
      matching: find.text('Retry'),
    ).first;
    
    await tester.tap(retryButton);
    await tester.pumpAndSettle();

    expect(find.text('More Item'), findsOneWidget);
  });

  testWidgets('ModuleTabScreen handles null module gracefully', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
          ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
          ChangeNotifierProvider<ThemeProvider>.value(value: mockThemeProvider),
          ChangeNotifierProvider<SchemaProvider>.value(value: mockSchemaProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ModuleTabScreen(
              tab: testTab,
              primaryColor: Colors.blue,
              module: null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    verifyNever(() => mockDriveService.fetchRecords(any(), any(), any(),
      offset: any(named: 'offset'),
      limit: any(named: 'limit'),
      fetchSubTables: any(named: 'fetchSubTables'),
      descending: any(named: 'descending'),
      searchQuery: any(named: 'searchQuery'),
      quickFilter: any(named: 'quickFilter'),
    ));
  });

  testWidgets('ModuleTabScreen search displays no items found message', (WidgetTester tester) async {
    when(() => mockDriveService.fetchRecords(
      any(), any(), any(),
      offset: any(named: 'offset'),
      limit: any(named: 'limit'),
      fetchSubTables: any(named: 'fetchSubTables'),
      descending: any(named: 'descending'),
      searchQuery: 'Nonexistent',
    )).thenAnswer((_) async => []);

    await tester.pumpWidget(createModuleTabScreen());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Nonexistent');
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

    expect(find.text('No items found'), findsOneWidget);
  });

  testWidgets('ModuleTabScreen navigates to record detail on tap', (WidgetTester tester) async {
    await tester.pumpWidget(createModuleTabScreen());
    await tester.pumpAndSettle();

    when(() => mockSchemaProvider.getFromMemory(any())).thenReturn(testModule);

    await tester.tap(find.text('Record 1'));
    await tester.pumpAndSettle();

    // Should find Record 1 as title in RecordDetailScreen AppBar or similar
    expect(find.text('Record 1'), findsWidgets);
    // Check if back button is present, indicating navigation
    expect(find.byIcon(Icons.arrow_back), findsWidgets);
  });

  testWidgets('ModuleTabScreen navigates to add record screen', (WidgetTester tester) async {
    await tester.pumpWidget(createModuleTabScreen());
    await tester.pumpAndSettle();

    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);
    await tester.tap(fab);
    await tester.pumpAndSettle();

    // Check if we navigated away or show a form
    expect(find.byType(Form), findsWidgets);
  });

  testWidgets('ModuleTabScreen supports pull to refresh', (WidgetTester tester) async {
    await tester.pumpWidget(createModuleTabScreen());
    await tester.pumpAndSettle();

    clearInteractions(mockDriveService);

    // Pull to refresh: Drag down significantly from the top
    // Use a gesture to ensure we pull it far enough
    final TestGesture gesture = await tester.startGesture(tester.getCenter(find.byType(ListView)));
    await gesture.moveBy(const Offset(0.0, 400.0));
    await tester.pump();
    await gesture.up();
    
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    verify(() => mockDriveService.fetchRecords(
      any(), any(), any(),
      offset: 0,
      limit: any(named: 'limit'),
      fetchSubTables: any(named: 'fetchSubTables'),
      descending: any(named: 'descending'),
      searchQuery: any(named: 'searchQuery'),
      quickFilter: any(named: 'quickFilter'),
    )).called(greaterThanOrEqualTo(1));
  });

  testWidgets('ModuleTabScreen tests all filter operators', (WidgetTester tester) async {
    final complexTab = TabConfig(
      id: 't1', 
      label: 'Tab 1', 
      columns: [
        ColumnConfig(key: 'name', label: 'Name', type: 'text'),
        ColumnConfig(key: 'age', label: 'Age', type: 'number'),
      ],
      quickFilters: [
        QuickFilter(label: 'Not Record 1', field: 'name', operator: '!=', value: 'Record 1', key: 'f1'),
        QuickFilter(label: 'Contains ord', field: 'name', operator: 'contains', value: 'ord', key: 'f2'),
        QuickFilter(label: 'Starts with Rec', field: 'name', operator: 'startsWidth', value: 'Rec', key: 'f3'),
        QuickFilter(label: 'Age > 20', field: 'age', operator: '>', value: '20', key: 'f4'),
        QuickFilter(label: 'Age < 20', field: 'age', operator: '<', value: '20', key: 'f5'),
        QuickFilter(label: 'Z-Name > R', field: 'name', operator: '>', value: 'R', key: 'f6'),
        QuickFilter(label: 'A-Name < R', field: 'name', operator: '<', value: 'R', key: 'f7'),
        QuickFilter(label: 'Equals Record 1', field: 'name', operator: '==', value: 'Record 1', key: 'f8'),
      ],
      enableCustomFilters: true,
    );

    when(() => mockDriveService.fetchRecords(any(), any(), any(),
      offset: any(named: 'offset'),
      limit: any(named: 'limit'),
      fetchSubTables: any(named: 'fetchSubTables'),
      descending: any(named: 'descending'),
      quickFilter: any(named: 'quickFilter'),
      searchQuery: any(named: 'searchQuery'),
    )).thenAnswer((_) async => [
      {'name': 'Record 1', 'age': '10', 'record_id': '100'},
      {'name': 'Record 2', 'age': '30', 'record_id': '200'},
    ]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
          ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
          ChangeNotifierProvider<ThemeProvider>.value(value: mockThemeProvider),
          ChangeNotifierProvider<SchemaProvider>.value(value: mockSchemaProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ModuleTabScreen(
              tab: complexTab,
              primaryColor: Colors.blue,
              module: testModule,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Test !=
    final f1 = find.text('Not Record 1');
    await tester.ensureVisible(f1);
    await tester.tap(f1);
    await tester.pumpAndSettle();
    expect(find.text('Record 1'), findsNothing);
    expect(find.text('Record 2'), findsOneWidget);

    // Test contains
    final f2 = find.text('Contains ord');
    await tester.ensureVisible(f2);
    await tester.tap(f2);
    await tester.pumpAndSettle();
    expect(find.text('Record 2'), findsOneWidget);

    // Test startsWidth
    final f3 = find.text('Starts with Rec');
    await tester.ensureVisible(f3);
    await tester.tap(f3);
    await tester.pumpAndSettle();
    expect(find.text('Record 2'), findsOneWidget);

    // Test > (Numeric)
    final f4 = find.text('Age > 20');
    await tester.ensureVisible(f4);
    await tester.tap(f4);
    await tester.pumpAndSettle();
    expect(find.text('Record 2'), findsOneWidget);
    expect(find.text('Record 1'), findsNothing);

    // Test < (Numeric)
    final f5 = find.text('Age < 20');
    await tester.ensureVisible(f5);
    await tester.tap(f5);
    await tester.pumpAndSettle();
    expect(find.text('Record 1'), findsOneWidget);
    expect(find.text('Record 2'), findsNothing);

    // Test > (String)
    final f6 = find.text('Z-Name > R');
    await tester.ensureVisible(f6);
    await tester.tap(f6);
    await tester.pumpAndSettle();
    // 'Record 1' vs 'R' -> 'Record 1' starts with 'R' then 'e', so it's > 'R'
    expect(find.text('Record 1'), findsOneWidget);

    // Test < (String)
    final f7 = find.text('A-Name < R');
    await tester.ensureVisible(f7);
    await tester.tap(f7);
    await tester.pumpAndSettle();
    // No match since both 'Record 1' and 'Record 2' are > 'R'
    expect(find.text('No items found'), findsOneWidget);

    // Test ==
    final f8 = find.text('Equals Record 1');
    await tester.ensureVisible(f8);
    await tester.tap(f8);
    await tester.pumpAndSettle();
    expect(find.text('Record 1'), findsOneWidget);
    expect(find.text('Record 2'), findsNothing);
  });

  testWidgets('ModuleTabScreen updates when tab configuration changes', (WidgetTester tester) async {
    await tester.pumpWidget(createModuleTabScreen());
    await tester.pumpAndSettle();

    final newTab = TabConfig(id: 't2', label: 'Tab 2', columns: [
      ColumnConfig(key: 'name', label: 'Name', type: 'text'),
    ]);

    when(() => mockDriveService.fetchRecords(
      any(), any(), 't2',
      offset: any(named: 'offset'),
      limit: any(named: 'limit'),
      fetchSubTables: any(named: 'fetchSubTables'),
      descending: any(named: 'descending'),
      searchQuery: any(named: 'searchQuery'),
      quickFilter: any(named: 'quickFilter'),
    )).thenAnswer((_) async => []);

    // Update the widget with a new tab
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
          ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
          ChangeNotifierProvider<ThemeProvider>.value(value: mockThemeProvider),
          ChangeNotifierProvider<SchemaProvider>.value(value: mockSchemaProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ModuleTabScreen(
              tab: newTab,
              primaryColor: Colors.blue,
              module: testModule,
            ),
          ),
        ),
      ),
    );
    
    // Verify it triggers a new load for the new tab ID
    verify(() => mockDriveService.fetchRecords(
      any(), any(), 't2',
      offset: any(named: 'offset'),
      limit: any(named: 'limit'),
      fetchSubTables: any(named: 'fetchSubTables'),
      descending: any(named: 'descending'),
      searchQuery: any(named: 'searchQuery'),
      quickFilter: any(named: 'quickFilter'),
    )).called(1);
  });

  testWidgets('ModuleTabScreen displays standard card template', (WidgetTester tester) async {
    final standardTab = TabConfig(
      id: 't1', 
      label: 'Tab 1', 
      columns: [
        ColumnConfig(key: 'name', label: 'Name', type: 'text'),
        ColumnConfig(key: 'status', label: 'Status', type: 'text'),
        ColumnConfig(key: 'price', label: 'Price', type: 'number'),
      ],
      listTemplate: ListTemplateConfig(
        template: 'standard',
        titleKey: 'name',
        subtitleKey: 'status',
        trailingKey: 'price',
        detailKeys: ['status'],
      ),
    );

    when(() => mockDriveService.fetchRecords(any(), any(), any(),
      offset: any(named: 'offset'),
      limit: any(named: 'limit'),
      fetchSubTables: any(named: 'fetchSubTables'),
      descending: any(named: 'descending'),
      searchQuery: any(named: 'searchQuery'),
      quickFilter: any(named: 'quickFilter'),
    )).thenAnswer((_) async => [
      {'name': 'Expensive Item', 'status': 'Available', 'price': '\$100', 'record_id': '500'},
    ]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
          ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
          ChangeNotifierProvider<ThemeProvider>.value(value: mockThemeProvider),
          ChangeNotifierProvider<SchemaProvider>.value(value: mockSchemaProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ModuleTabScreen(
              tab: standardTab,
              primaryColor: Colors.blue,
              module: testModule,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Expensive Item'), findsOneWidget);
    expect(find.text('Available'), findsNWidgets(2)); // One in subtitle, one in detailKeys
    expect(find.text('\$100'), findsOneWidget); // Trailing
    expect(find.text('STATUS'), findsOneWidget); // Detail label (uppercase)
  });
}
