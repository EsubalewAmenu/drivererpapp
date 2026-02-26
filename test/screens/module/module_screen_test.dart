import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:google_sign_in/google_sign_in.dart';

import 'package:drivererpapp/screens/module_screen.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/services/auth_service.dart';

class MockDriveService extends Mock implements DriveService {}
class MockSheetsApi extends Mock implements sheets.SheetsApi {}
class MockSpreadsheetsResource extends Mock implements sheets.SpreadsheetsResource {}
class MockValuesResource extends Mock implements sheets.SpreadsheetsValuesResource {}
class MockAuthService extends Mock implements AuthService {}

class TestDriveProvider extends DriveProvider {
  final DriveService? _svc;
  TestDriveProvider(this._svc);
  @override
  DriveService? get driveService => _svc;
}

class _TestGoogleAccount extends Fake implements GoogleSignInAccount {
  final String _email;
  _TestGoogleAccount(this._email);

  @override
  String get email => _email;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthService mockAuthService;
  late WorkspaceProvider workspaceProvider;

  setUp(() {
    mockAuthService = MockAuthService();
    workspaceProvider = WorkspaceProvider(driveService: null);
    when(() => mockAuthService.currentUser).thenReturn(_TestGoogleAccount('test@example.com'));
  });

  testWidgets('ModuleScreen shows enabled extension from cache', (tester) async {
    SharedPreferences.setMockInitialValues({
      'module_config_host_settings': jsonEncode({'extensions': ['inv']}),
      'module_config_host_dashboard': jsonEncode({'cards': []}),
      'module_config_host_tabs': jsonEncode([]),
    });
    final mockDrive = MockDriveService();
    when(() => mockDrive.getFileId(any(), any())).thenAnswer((_) async => null);
    when(() => mockDrive.getFileModifiedTime(any())).thenAnswer((_) async => DateTime.now());

    final hostModule = ModuleSchema(
      id: 'host',
      name: 'Host',
      icon: 'h',
      primaryColor: '#2196F3',
      version: '1',
      settings: {
        'extensions': SettingItem(label: 'Extensions', type: 'list', value: ['inv'])
      },
      dashboard: DashboardConfig(cards: []),
      tabs: [TabConfig(id: 't1', label: 'Items', columns: [])],
    );

    final extModule = ModuleSchema(
      id: 'inv',
      name: 'Inventory',
      icon: 'i',
      primaryColor: '#FF0000',
      version: '1',
      settings: {},
      dashboard: DashboardConfig(cards: []),
      tabs: [],
    );

    final schemaProvider = SchemaProvider(driveService: mockDrive);
    schemaProvider.updateMemoryCache(extModule.id, extModule);
    schemaProvider.updateMemoryCache(hostModule.id, hostModule);

    final driveProvider = TestDriveProvider(null);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SchemaProvider>.value(value: schemaProvider),
          ChangeNotifierProvider<DriveProvider>.value(value: driveProvider),
          ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaceProvider),
          ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
        ],
        child: MaterialApp(home: ModuleScreen(module: hostModule)),
      ),
    );

    await tester.pumpAndSettle();

    final extTab = find.text('EXTENSIONS');
    expect(extTab, findsOneWidget);
    await tester.tap(extTab);
    await tester.pumpAndSettle();

    expect(find.text('Inventory'), findsOneWidget);
    expect(find.text('Install'), findsWidgets);

    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
  });

  testWidgets('ModuleScreen loads direct sheet ids when provided', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final mockDrive = MockDriveService();

    when(() => mockDrive.readSettingsById('s1')).thenAnswer((_) async => {'name': {'label': 'Name', 'type': 'text', 'value': 'DirectHost'}});
    when(() => mockDrive.readDashboardById('d1')).thenAnswer((_) async => {'cards': []});
    when(() => mockDrive.readTabsById('t1')).thenAnswer((_) async => []);
    when(() => mockDrive.getFileModifiedTime(any())).thenAnswer((_) async => DateTime.utc(2025));
    when(() => mockDrive.getFileId(any(), any())).thenAnswer((_) async => null);

    final mockSheetsApi = MockSheetsApi();
    final mockSpreadsheets = MockSpreadsheetsResource();
    final mockValues = MockValuesResource();
    when(() => mockSheetsApi.spreadsheets).thenReturn(mockSpreadsheets);
    when(() => mockSpreadsheets.values).thenReturn(mockValues);
    when(() => mockDrive.sheetsApi).thenReturn(mockSheetsApi);
    when(() => mockValues.get(any(), 'modules!A1:Z')).thenAnswer((_) async => sheets.ValueRange(values: []));

    final hostModule = ModuleSchema(
      id: 'host3',
      name: 'Host',
      icon: 'h',
      primaryColor: '#2196F3',
      version: '1',
      settings: {},
      dashboard: DashboardConfig(cards: []),
      tabs: [],
    );

    final schemaProvider = SchemaProvider(driveService: mockDrive);
    final driveProvider = TestDriveProvider(mockDrive);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SchemaProvider>.value(value: schemaProvider),
          ChangeNotifierProvider<DriveProvider>.value(value: driveProvider),
          ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaceProvider),
          ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
        ],
        child: MaterialApp(
          home: ModuleScreen(module: hostModule, settingsSheetId: 's1', dashboardSheetId: 'd1', tabsSheetId: 't1'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.textContaining('DIRECTHOST'), findsOneWidget);
  });
}
