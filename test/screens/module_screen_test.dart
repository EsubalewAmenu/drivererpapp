import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drivererpapp/screens/module_screen.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/services/schema_service.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;

class MockDriveProvider extends Mock implements DriveProvider {}
class MockSchemaProvider extends Mock implements SchemaProvider {}
class MockSchemaService extends Mock implements SchemaService {}
class MockDriveService extends Mock implements DriveService {}
class MockWorkspaceProvider extends Mock implements WorkspaceProvider {}
class MockAuthService extends Mock implements AuthService {}

class _TestGoogleAccount extends Fake implements GoogleSignInAccount {
  final String _email;
  _TestGoogleAccount(this._email);

  @override
  String get email => _email;
}

class MockSheetsApi extends Mock implements sheets.SheetsApi {}
class MockSpreadsheetsResource extends Mock implements sheets.SpreadsheetsResource {}
class MockValuesResource extends Mock implements sheets.SpreadsheetsValuesResource {}
class MockValueRange extends Mock implements sheets.ValueRange {}

void main() {
  setUpAll(() {
    registerFallbackValue(0);
    registerFallbackValue(true);
    Provider.debugCheckInvalidValueType = null;
    SharedPreferences.setMockInitialValues({});
  });

  late MockDriveProvider mockDriveProvider;
  late MockSchemaProvider mockSchemaProvider;
  late MockSchemaService mockSchemaService;
  late MockDriveService mockDriveService;
  late MockWorkspaceProvider mockWorkspaceProvider;
    late MockAuthService mockAuthService;
  late MockSheetsApi mockSheets;
  late MockSpreadsheetsResource mockResources;
  late MockValuesResource mockValues;

  setUp(() {
    mockDriveProvider = MockDriveProvider();
    mockSchemaProvider = MockSchemaProvider();
    mockSchemaService = MockSchemaService();
    mockDriveService = MockDriveService();
    mockWorkspaceProvider = MockWorkspaceProvider();
      mockAuthService = MockAuthService();
    mockSheets = MockSheetsApi();
    mockResources = MockSpreadsheetsResource();
    mockValues = MockValuesResource();

    when(() => mockWorkspaceProvider.currentWorkspace).thenReturn(null);
    when(() => mockWorkspaceProvider.rootFolderId).thenReturn('root');

    when(() => mockSchemaProvider.service).thenReturn(mockSchemaService);
    when(() => mockSchemaService.driveService).thenReturn(mockDriveService);
    when(() => mockSchemaProvider.getFromMemory(any())).thenReturn(null);
    when(() => mockSchemaProvider.findModuleByIdOrName(any())).thenReturn(null);
    when(() => mockSchemaProvider.findModuleByTabId(any())).thenReturn(null);
    when(() => mockSchemaService.getCachedConfig(any())).thenAnswer((_) async => null);
    when(() => mockSchemaService.syncConfig(any(), 
      settingsId: any(named: 'settingsId'), 
      dashboardId: any(named: 'dashboardId'), 
      tabsId: any(named: 'tabsId')
    )).thenAnswer((_) async => null);
    when(() => mockSchemaService.saveTabField(any(), any(), any(), any(),
      settingsId: any(named: 'settingsId'),
      tabsId: any(named: 'tabsId')
    )).thenAnswer((_) async => {});
    
    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockDriveService.fetchRecords(any(), any(), any(), 
      offset: any(named: 'offset'), 
      limit: any(named: 'limit'),
      fetchSubTables: any(named: 'fetchSubTables'),
      descending: any(named: 'descending'),
      searchQuery: any(named: 'searchQuery'),
      quickFilter: any(named: 'quickFilter'),
    )).thenAnswer((_) async => <Map<String, dynamic>>[]);
    when(() => mockDriveService.fetchRecordsBySpreadsheetId(any(), any(),
      offset: any(named: 'offset'),
      limit: any(named: 'limit'),
      fetchSubTables: any(named: 'fetchSubTables'),
      descending: any(named: 'descending'),
      searchQuery: any(named: 'searchQuery'),
      quickFilter: any(named: 'quickFilter'),
    )).thenAnswer((_) async => <Map<String, dynamic>>[]);
    when(() => mockDriveService.getFileId(any(), any())).thenAnswer((_) async => 'mock_file_id');
    when(() => mockDriveService.getFileRevisions(any())).thenAnswer((_) async => []);
    when(() => mockDriveService.getFileModifiedTime(any())).thenAnswer((_) async => DateTime.now());
    when(() => mockDriveService.readSettingsById(any())).thenAnswer((_) async => {});
    when(() => mockDriveService.readDashboardById(any())).thenAnswer((_) async => {'cards': []});
    when(() => mockDriveService.readTabsById(any())).thenAnswer((_) async => []);
    
    when(() => mockWorkspaceProvider.lastUserAccessSpreadsheetId).thenReturn('ua_id');
      when(() => mockAuthService.currentUser).thenReturn(_TestGoogleAccount('test.com'));
    
    when(() => mockDriveService.sheetsApi).thenAnswer((_) => mockSheets);
    when(() => mockSheets.spreadsheets).thenAnswer((_) => mockResources);
    when(() => mockResources.values).thenAnswer((_) => mockValues);
    when(() => mockValues.get(any(), any())).thenAnswer((_) async => sheets.ValueRange(values: []));

    when(() => mockSchemaService.cacheConfig(any(), any(), 
      fileId: any(named: 'fileId'), 
      modifiedTime: any(named: 'modifiedTime')
    )).thenAnswer((_) => Future<void>.value());
    when(() => mockSchemaService.cacheConfig(any(), any())).thenAnswer((_) => Future<void>.value());
    
    when(() => mockSchemaProvider.updateMemoryCache(any(), any())).thenReturn(null);
    when(() => mockSchemaProvider.notifyListeners()).thenReturn(null);
  });

  Widget createModuleScreen(ModuleSchema module, {String? settingsId}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ChangeNotifierProvider<SchemaProvider>.value(value: mockSchemaProvider),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
          Provider<AuthService>.value(value: mockAuthService),
      ],
      child: MaterialApp(
        home: ModuleScreen(module: module, settingsSheetId: settingsId),
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
    
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('TAB 1'), findsOneWidget);

    await tester.tap(find.text('TAB 1'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_note_rounded));
    await tester.pumpAndSettle();
    expect(find.text('BLUEPRINT EDITOR'), findsWidgets);
    
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Version History'));
    await tester.pumpAndSettle();
    expect(find.textContaining('History'), findsWidgets);

    // Clear timers
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('ModuleScreen direct read by sheet ids', (WidgetTester tester) async {
    final module = ModuleSchema(id: 'direct', name: 'Direct', icon: 'i', primaryColor: '#000000', version: '1', settings: {}, tabs: [], dashboard: DashboardConfig(cards: []));
    
    when(() => mockDriveService.readSettingsById('sid1')).thenAnswer((_) async => {
      'name': {'value': 'Direct Updated', 'label': 'Name', 'type': 'text'}
    });

    await tester.pumpWidget(createModuleScreen(module, settingsId: 'sid1'));
    await tester.pumpAndSettle();
    
    // Direct read happens in _syncSchema which is called by _loadSchema
    // We need to wait for it.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    
    verify(() => mockDriveService.readSettingsById('sid1')).called(1);
    expect(find.text('DIRECT UPDATED'), findsOneWidget);

    // Clear timers
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('ModuleScreen extensions tab loading', (WidgetTester tester) async {
    final module = ModuleSchema(
      id: 'host', name: 'Host', icon: 'i', primaryColor: '#000000', version: '1',
      settings: {
        'extensions': SettingItem(label: 'Ext', type: 'list', value: ['ext1'])
      },
      tabs: [], dashboard: DashboardConfig(cards: [])
    );

    // Stub host sync to return the host module config with extensions
    when(() => mockSchemaService.syncConfig('host', 
      settingsId: any(named: 'settingsId'), 
      dashboardId: any(named: 'dashboardId'), 
      tabsId: any(named: 'tabsId')
    )).thenAnswer((_) async => {
      'settings': {
        'name': {'value': 'Host Module', 'label': 'Name', 'type': 'text'},
        'extensions': {'value': ['ext1'], 'label': 'Exts', 'type': 'list'}
      },
      'tabs': []
    });

    // Mock User access for "ext1" activation
    final vRange = sheets.ValueRange(values: [
      ['id', 'name', 'dashboard', 'settings', 'tabs', 'status'],
      ['ext1', 'Extension One', 'eid_dash', 'eid_sett', 'eid_tabs', 'activated']
    ]);
    // Stub specifically on mockValues which is shared via the chain
    when(() => mockValues.get(any(), any())).thenAnswer((_) async => vRange);

    when(() => mockSchemaService.getCachedConfig('ext1')).thenAnswer((_) async => {
      'settings': {
        'name': {'value': 'Ext 1 Name', 'label': 'Name', 'type': 'text'}
      }
    });

    await tester.pumpWidget(createModuleScreen(module));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('EXTENSIONS'));
    await tester.pumpAndSettle();

    expect(find.text('Ext 1 Name'), findsOneWidget);
    expect(find.text('Installed'), findsOneWidget);

    // Clear timers
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('ModuleScreen handles sync failure with error body', (WidgetTester tester) async {
    final module = ModuleSchema(id: 'fail', name: 'Fail', icon: 'i', primaryColor: '#000000', version: '1', settings: {}, tabs: [], dashboard: DashboardConfig(cards: []));
    
    when(() => mockSchemaService.getCachedConfig('fail')).thenAnswer((_) async => null);
    when(() => mockSchemaService.syncConfig('fail', settingsId: any(named: 'settingsId'), dashboardId: any(named: 'dashboardId'), tabsId: any(named: 'tabsId')))
        .thenAnswer((_) async => null);

    await tester.pumpWidget(createModuleScreen(module));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('Unable to load module data'), findsOneWidget);
    expect(find.text('RETRY'), findsOneWidget);

    // Clear timers
    await tester.pump(const Duration(seconds: 5));
  });
}
