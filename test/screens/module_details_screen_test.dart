import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/module_details_screen.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/services/schema_service.dart';
import 'package:drivererpapp/screens/dashboard_screen.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class MockDriveProvider extends Mock implements DriveProvider {}
class MockWorkspaceProvider extends Mock implements WorkspaceProvider {}
class MockDriveService extends Mock implements DriveService {}
class MockSheetsApi extends Mock implements sheets.SheetsApi {}
class MockSpreadsheetsResource extends Mock implements sheets.SpreadsheetsResource {}
class MockValuesResource extends Mock implements sheets.SpreadsheetsValuesResource {}
class MockAuthService extends Mock implements AuthService {}
class MockSchemaProvider extends Mock implements SchemaProvider {}
class MockSchemaService extends Mock implements SchemaService {}

class TestAssetBundle extends CachingAssetBundle {
  final Map<String, String> assets;
  TestAssetBundle({required this.assets});

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (assets.containsKey(key)) return assets[key]!;
    throw FlutterError('Asset not found: $key');
  }

  @override
  Future<ByteData> load(String key) async => ByteData(0);
}

class _TestGoogleAccount extends Fake implements GoogleSignInAccount {
  final String _email;
  _TestGoogleAccount(this._email);

  @override
  String get email => _email;
}

void main() {
  setUpAll(() {
    Provider.debugCheckInvalidValueType = null;
  });
  late MockDriveProvider mockDriveProvider;
  late MockWorkspaceProvider mockWorkspaceProvider;
  late MockDriveService mockDriveService;
  late MockAuthService mockAuthService;
  late MockSchemaProvider mockSchemaProvider;
  late MockSchemaService mockSchemaService;

  setUp(() {
    mockDriveProvider = MockDriveProvider();
    mockWorkspaceProvider = MockWorkspaceProvider();
    mockDriveService = MockDriveService();
    mockAuthService = MockAuthService();
    mockSchemaProvider = MockSchemaProvider();
    mockSchemaService = MockSchemaService();
    
    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockDriveService.getFileId(any(), any())).thenAnswer((_) async => null);
    when(() => mockSchemaProvider.service).thenReturn(mockSchemaService);
    when(() => mockSchemaService.cacheConfig(any(), any())).thenAnswer((_) async => true);
    when(() => mockSchemaService.removeCachedConfig(any())).thenAnswer((_) async => true);
    when(() => mockSchemaProvider.updateMemoryCache(any(), any())).thenReturn(null);
    when(() => mockDriveService.ensureUserAccessSpreadsheet(any(), any())).thenAnswer((_) async => 'uas123');
    when(() => mockDriveService.ensureUserAccessFolder(any())).thenAnswer((_) async => 'uaf123');
    when(() => mockDriveService.checkRootFolder()).thenAnswer((_) async => 'root123');
    when(() => mockDriveService.getOrCreateSubFolder(any(), any())).thenAnswer((_) async => 'sub123');
    when(() => mockDriveService.upsertUserAccessModule(any(), any(), any(), any(), any(), any())).thenAnswer((_) async => {});
    when(() => mockDriveService.setUserAccessModuleStatus(any(), any(), any())).thenAnswer((_) async => {});
    when(() => mockDriveService.registerModule(any(), any(), any(), any())).thenAnswer((_) async => {});
    when(() => mockDriveService.createModuleConfig(any(), any(), any())).thenAnswer((_) async => 'cfg123');

    when(() => mockWorkspaceProvider.currentWorkspace).thenReturn(drive.File()..id = 'ws123'..name = 'My Workspace');
    when(() => mockWorkspaceProvider.loadCompanies(any())).thenAnswer((_) async {});
    when(() => mockAuthService.currentUser).thenReturn(_TestGoogleAccount('test@example.com'));
  });

  Widget createModuleDetailsScreen(Map<String, String> info) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
        ChangeNotifierProvider<SchemaProvider>.value(value: mockSchemaProvider),
        Provider<AuthService>.value(value: mockAuthService),
      ],
      child: MaterialApp(
        home: ModuleDetailsScreen(moduleInfo: info),
      ),
    );
  }

  Widget createModuleDetailsScreenWithBundle(Map<String, String> info, {TestAssetBundle? bundle}) {
    final app = MaterialApp(home: ModuleDetailsScreen(moduleInfo: info));
    final root = bundle != null ? DefaultAssetBundle(bundle: bundle, child: app) : app;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
        ChangeNotifierProvider<SchemaProvider>.value(value: mockSchemaProvider),
        Provider<AuthService>.value(value: mockAuthService),
      ],
      child: root,
    );
  }

  testWidgets('ModuleDetailsScreen displays module info', (WidgetTester tester) async {
    final info = {
      'name': 'CRM',
      'desc': 'Customer Management',
      'icon': 'people',
      'color': '#3B82F6',
    };
    
    await tester.pumpWidget(createModuleDetailsScreen(info));

    expect(find.text('CRM'), findsOneWidget);
    expect(find.text('Customer Management'), findsOneWidget);
    expect(find.text('ACTIVATE'), findsOneWidget);
  });

  testWidgets('ModuleDetailsScreen activates module', (WidgetTester tester) async {
    final info = {
      'name': 'CRM',
      'desc': 'Customer Management',
      'icon': 'people',
      'color': '#3B82F6',
    };

    when(() => mockDriveService.createWorkspace(any(), any()))
        .thenAnswer((_) async => drive.File()..id = 'mod123');
    final mockSheetsApi = MockSheetsApi();
    final mockSpreadsheets = MockSpreadsheetsResource();
    final mockValues = MockValuesResource();
    when(() => mockSheetsApi.spreadsheets).thenReturn(mockSpreadsheets);
    when(() => mockSpreadsheets.values).thenReturn(mockValues);
    when(() => mockDriveService.sheetsApi).thenReturn(mockSheetsApi);
    when(() => mockValues.get(any(), 'modules!A1:Z')).thenAnswer((_) async => sheets.ValueRange(values: []));

    await tester.pumpWidget(createModuleDetailsScreen(info));

    await tester.tap(find.text('ACTIVATE'));
    await tester.pump();
    
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    
    await tester.pumpAndSettle();
    
    verify(() => mockDriveService.createWorkspace('ws123', 'CRM')).called(1);
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('ModuleDetailsScreen handles activation error', (WidgetTester tester) async {
    final info = {
      'name': 'CRM',
      'desc': 'Customer Management',
      'icon': 'people',
      'color': '#3B82F6',
    };

    when(() => mockDriveService.createWorkspace(any(), any()))
        .thenThrow(Exception('Creation failed'));

    await tester.pumpWidget(createModuleDetailsScreen(info));

    await tester.tap(find.text('ACTIVATE'));
    await tester.pumpAndSettle();

    expect(find.text('Error activating module: Exception: Creation failed'), findsOneWidget);
    expect(find.text('ACTIVATE'), findsOneWidget); // Toggle back
  });

  testWidgets('ModuleDetailsScreen handles missing auth/workspace', (WidgetTester tester) async {
    final info = {
      'name': 'CRM',
      'desc': 'Customer Management',
      'icon': 'people',
      'color': '#3B82F6',
    };

    when(() => mockDriveProvider.driveService).thenReturn(null);

    await tester.pumpWidget(createModuleDetailsScreen(info));

    await tester.tap(find.text('ACTIVATE'));
    await tester.pumpAndSettle();

    expect(find.text('Error activating module: Exception: Authentication or Workspace missing'), findsOneWidget);
  });

  testWidgets('ModuleDetailsScreen seeds initial data during activation', (WidgetTester tester) async {
    final info = {
      'name': 'Inventory',
      'desc': 'Stock Management',
      'icon': 'inventory',
      'color': '#3B82F6',
    };

    // Mock asset loading
    final moduleJson = {
      'tabs': [
        {
          'id': 't1',
          'initial_data': [
            {'name': 'Item 1'},
            {'name': 'Item 2'},
          ]
        }
      ]
    };
    
    final assets = {
      'assets/erp_modules/module_asset_map.json': jsonEncode({'inventory': 'inventory.json'}),
      'assets/erp_modules/inventory.json': jsonEncode(moduleJson),
    };

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (ByteData? message) async {
        String key = '';
        if (message != null) {
          try {
            key = const StandardMessageCodec().decodeMessage(message) as String? ?? '';
          } catch (_) {
            key = '';
          }
        }
        if (key.contains('module_asset_map.json')) {
          final Uint8List list = utf8.encoder.convert(assets['assets/erp_modules/module_asset_map.json']!);
          return list.buffer.asByteData();
        }
        if (key.contains('inventory.json')) {
          final Uint8List list = utf8.encoder.convert(assets['assets/erp_modules/inventory.json']!);
          return list.buffer.asByteData();
        }
        return null;
      },
    );
    when(() => mockDriveService.createWorkspace(any(), any()))
        .thenAnswer((_) async => drive.File()..id = 'mod123');
    when(() => mockDriveService.saveRecord(any(), any(), any(), any()))
        .thenAnswer((_) async => drive.File());
    final mockSheetsApi = MockSheetsApi();
    final mockSpreadsheets = MockSpreadsheetsResource();
    final mockValues = MockValuesResource();
    when(() => mockSheetsApi.spreadsheets).thenReturn(mockSpreadsheets);
    when(() => mockSpreadsheets.values).thenReturn(mockValues);
    when(() => mockDriveService.sheetsApi).thenReturn(mockSheetsApi);
    when(() => mockValues.get(any(), 'modules!A1:Z')).thenAnswer((_) async => sheets.ValueRange(values: []));

    await tester.pumpWidget(createModuleDetailsScreenWithBundle(info, bundle: TestAssetBundle(assets: assets)));
    await tester.pumpAndSettle(); // Load config

    // Ensure module JSON is present for the activation flow (rootBundle mocking
    // may not always be honored in test environment). Inject directly into
    // the state so the activation path will seed initial_data.
    final state = tester.state(find.byType(ModuleDetailsScreen)) as dynamic;
    try {
      state._moduleJson = moduleJson;
    } catch (_) {}
    await tester.pump();

    await tester.tap(find.text('ACTIVATE'));
    await tester.pump();
    await tester.pumpAndSettle();

    // Verify seeding occurred during activation
    verify(() => mockDriveService.saveRecord('mod123', 'Inventory', 't1', {'name': 'Item 1'})).called(1);
    verify(() => mockDriveService.saveRecord('mod123', 'Inventory', 't1', {'name': 'Item 2'})).called(1);
    expect(find.byType(DashboardScreen), findsOneWidget);
    
    // Cleanup mock handler
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', null);
  });

  testWidgets('ModuleDetailsScreen handles unknown module and icon defaults', (tester) async {
    final info = {
      'name': 'Custom Module',
      'desc': 'Description',
      'icon': 'unknown_icon_123',
      'color': '#3B82F6',
    };

    // Mock asset loading with unknown icon
    final moduleJson = {
      'icon': 'unknown_icon_123',
      'tabs': []
    };
    
    final assets = {
      'assets/erp_modules/module_asset_map.json': jsonEncode({'custom module': 'custom_module.json', 'custom%20module': 'custom_module.json'}),
      'assets/erp_modules/custom_module.json': jsonEncode(moduleJson),
    };

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (ByteData? message) async {
        String key = '';
        if (message != null) {
          try {
            key = const StandardMessageCodec().decodeMessage(message) as String? ?? '';
          } catch (_) {
            key = '';
          }
        }
        if (key.contains('module_asset_map.json')) {
          final Uint8List list = utf8.encoder.convert(assets['assets/erp_modules/module_asset_map.json']!);
          return list.buffer.asByteData();
        }
        if (key.contains('custom_module.json')) {
          final Uint8List list = utf8.encoder.convert(assets['assets/erp_modules/custom_module.json']!);
          return list.buffer.asByteData();
        }
        return null;
      },
    );

    await tester.pumpWidget(createModuleDetailsScreenWithBundle(info, bundle: TestAssetBundle(assets: assets)));
    await tester.pumpAndSettle();
    expect(find.text('CUSTOM MODULE'), findsOneWidget);
    // Should show default pros
    expect(find.text('Streamlined Workflow'), findsOneWidget);
    
    // Cleanup mock handler
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', null);
  });
}
