import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/module_screen.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:drivererpapp/services/schema_service.dart';
import 'package:drivererpapp/services/drive_service.dart';

class MockDriveProvider extends Mock implements DriveProvider {}
class MockSchemaProvider extends Mock implements SchemaProvider {}
class MockSchemaService extends Mock implements SchemaService {}
class MockDriveService extends Mock implements DriveService {}
class MockWorkspaceProvider extends Mock implements WorkspaceProvider {}

void main() {
  setUpAll(() {
    registerFallbackValue(0);
    registerFallbackValue(true);
    // Allow using mock provider instances in ChangeNotifierProvider.value in tests
    Provider.debugCheckInvalidValueType = null;
  });

  late MockDriveProvider mockDriveProvider;
  late MockSchemaProvider mockSchemaProvider;
  late MockSchemaService mockSchemaService;
  late MockDriveService mockDriveService;
  late MockWorkspaceProvider mockWorkspaceProvider;

  setUp(() {
    mockDriveProvider = MockDriveProvider();
    mockSchemaProvider = MockSchemaProvider();
    mockSchemaService = MockSchemaService();
    mockDriveService = MockDriveService();
    mockWorkspaceProvider = MockWorkspaceProvider();
    when(() => mockWorkspaceProvider.currentWorkspace).thenReturn(null);
    when(() => mockWorkspaceProvider.rootFolderId).thenReturn('root');

    when(() => mockSchemaProvider.service).thenReturn(mockSchemaService);
    when(() => mockSchemaProvider.getFromMemory(any())).thenReturn(null);
    when(() => mockSchemaService.getCachedConfig(any())).thenAnswer((_) async => null);
    when(() => mockSchemaService.syncConfig(any())).thenAnswer((_) async => null);
    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockDriveService.fetchRecords(any(), any(), any(), 
      offset: any(named: 'offset'), 
      limit: any(named: 'limit'),
      fetchSubTables: any(named: 'fetchSubTables'),
      descending: any(named: 'descending'),
      searchQuery: any(named: 'searchQuery'),
      quickFilter: any(named: 'quickFilter'),
    )).thenAnswer((_) async => <Map<String, dynamic>>[]);
    when(() => mockDriveService.getFileId(any(), any())).thenAnswer((_) async => 'mock_file_id');
    when(() => mockDriveService.getFileRevisions(any())).thenAnswer((_) async => []);
  });

  Widget createModuleScreen(ModuleSchema module) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ChangeNotifierProvider<SchemaProvider>.value(value: mockSchemaProvider),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
      ],
      child: MaterialApp(
        home: ModuleScreen(module: module),
      ),
    );
  }

  testWidgets('ModuleScreen loads schema and shows tabs', (WidgetTester tester) async {
    final module = ModuleSchema(
      id: 'm1',
      name: 'Test Module',
      icon: 'inventory',
      primaryColor: '#F59E0B',
      version: '1.0.0',
      settings: {
        'name': SettingItem(label: 'Name', type: 'text', value: 'Test Module'),
      },
      tabs: [
        TabConfig(id: 't1', label: 'Tab 1', columns: []),
      ],
      dashboard: DashboardConfig(cards: []),
    );

    final configJson = module.toJson();

    when(() => mockSchemaService.getCachedConfig('m1')).thenAnswer((_) async => configJson);

    await tester.pumpWidget(createModuleScreen(module));
    await tester.pumpAndSettle();
    
    // Handle timers in ModuleScreen and ModuleDashboard
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('TAB 1'), findsOneWidget);

    // Test tab switching
    await tester.tap(find.text('TAB 1'));
    await tester.pumpAndSettle();

    // Test Blueprint button
    await tester.tap(find.byIcon(Icons.edit_note_rounded));
    await tester.pumpAndSettle();
    expect(find.text('BLUEPRINT EDITOR'), findsWidgets);
    
    // Go back
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Test History button
    await tester.tap(find.byTooltip('Version History'));
    await tester.pumpAndSettle();
    
    expect(find.textContaining('History'), findsWidgets);
    
    // Close history
    if (find.text('CLOSE').evaluate().isNotEmpty) {
      await tester.tap(find.text('CLOSE'));
    } else if (find.text('CANCEL').evaluate().isNotEmpty) {
      await tester.tap(find.text('CANCEL'));
    } else if (find.byType(TextButton).evaluate().isNotEmpty) {
      await tester.tap(find.byType(TextButton).last);
    }
    await tester.pumpAndSettle();
  });

  testWidgets('ModuleScreen handles asset fallback', (WidgetTester tester) async {
    final module = ModuleSchema(
      id: 'm_fallback',
      name: 'NonExistentModule',
      icon: 'inventory',
      primaryColor: '#F59E0B',
      version: '1.0.0',
      settings: {},
      tabs: [],
      dashboard: DashboardConfig(cards: []),
    );

    when(() => mockSchemaService.getCachedConfig('m_fallback')).thenAnswer((_) async => null);
    when(() => mockSchemaService.syncConfig('m_fallback')).thenAnswer((_) async => null);

    await tester.pumpWidget(createModuleScreen(module));
    await tester.pump(); // Start _loadSchema
    
    // Wait for the sync and asset check to complete
    await tester.pump(const Duration(seconds: 1)); 
    await tester.pumpAndSettle();

    // Should have navigated to editor because of asset fallback
    expect(find.text('COMPLETE SETUP'), findsWidgets);
  });

  testWidgets('ModuleScreen handles cache load and background sync', (WidgetTester tester) async {
     final module = ModuleSchema(
      id: 'm_cache',
      name: 'Cached Module',
      icon: 'inventory',
      primaryColor: '#F59E0B',
      version: '1.0.0',
      settings: {'name': SettingItem(label: 'Name', type: 'text', value: 'Cached Module')},
      tabs: [TabConfig(id: 't1', label: 'Tab 1', columns: [])],
      dashboard: DashboardConfig(cards: []),
    );

    final configJson = module.toJson();
    when(() => mockSchemaService.getCachedConfig('m_cache')).thenAnswer((_) async => configJson);
    when(() => mockSchemaService.syncConfig('m_cache')).thenAnswer((_) async => configJson);

    await tester.pumpWidget(createModuleScreen(module));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2)); // Wait for delayed background sync
    await tester.pumpAndSettle();

    verify(() => mockSchemaService.syncConfig('m_cache')).called(1);
  });

  testWidgets('ModuleScreen handles parsing errors', (WidgetTester tester) async {
    final module = ModuleSchema(
      id: 'm_err',
      name: 'Err Module',
      icon: 'inventory',
      primaryColor: '#F59E0B',
      version: '1.0.0',
      settings: {},
      tabs: [],
      dashboard: DashboardConfig(cards: []),
    );

    final configJson = {
      'settings': {
        'name': {'value': 'Broken Module'}, // Missing label/type -> SettingItem.fromJson fails
        'options_list': {'label': 'L', 'type': 'l', 'value': ['A', 'B']},
      },
      'tabs': [
        {'id': 't1'}, // Missing label/columns -> TabConfig.fromJson fails
        {
          'id': 't2', 
          'label': 'Tab 2', 
          'columns': [
            {'key': 'c1', 'label': 'C1', 'type': 'select', 'options': 'settings.options_list'}
          ]
        }
      ]
    };

    when(() => mockSchemaService.getCachedConfig('m_err')).thenAnswer((_) async => configJson);

    await tester.pumpWidget(createModuleScreen(module));
    await tester.pump(); // Start _loadSchema
    await tester.pump(const Duration(seconds: 2)); // Wait for cache load and sync timer
    await tester.pumpAndSettle();

    expect(find.text('ERROR TAB'), findsOneWidget);
    expect(find.text('TAB 2'), findsOneWidget);
  });
}
