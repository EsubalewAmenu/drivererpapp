import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;

import 'package:drivererpapp/screens/module_screen.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';

class MockDriveService extends Mock implements DriveService {}
class MockSheetsApi extends Mock implements sheets.SheetsApi {}
class MockSpreadsheetsResource extends Mock implements sheets.SpreadsheetsResource {}
class MockValuesResource extends Mock implements sheets.SpreadsheetsValuesResource {}

class TestDriveProvider extends DriveProvider {
  final DriveService? _svc;
  TestDriveProvider(this._svc);
  @override
  DriveService? get driveService => _svc;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ModuleScreen shows enabled extension from cache', (tester) async {
    SharedPreferences.setMockInitialValues({
      'module_config_host_settings': jsonEncode({'extensions': ['inv']}),
      'module_config_host_dashboard': jsonEncode({'cards': []}),
      'module_config_host_tabs': jsonEncode([]),
    });
    final mockDrive = MockDriveService();
    when(() => mockDrive.getFileId(any(), any())).thenAnswer((_) async => null);
    when(() => mockDrive.getFileModifiedTime(any())).thenAnswer((_) async => DateTime.now());

    // Create a host module with extensions setting
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

    // Create cached extension module
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
    // Cache host module so UI builds from cached module immediately
    schemaProvider.updateMemoryCache(hostModule.id, hostModule);

    final driveProvider = TestDriveProvider(null);
    final workspaceProvider = WorkspaceProvider(driveService: null);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SchemaProvider>.value(value: schemaProvider),
          ChangeNotifierProvider<DriveProvider>.value(value: driveProvider),
          ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaceProvider),
        ],
        child: MaterialApp(home: ModuleScreen(module: hostModule)),
      ),
    );

    // Wait for futures (FutureBuilder) to complete
    await tester.pumpAndSettle();

    // Switch to EXTENSIONS tab
    final extTab = find.text('EXTENSIONS');
    expect(extTab, findsOneWidget);
    await tester.tap(extTab);
    await tester.pumpAndSettle();

    // The extension card should display the cached module name
    expect(find.text('Inventory'), findsOneWidget);
    // Since no active modules were returned by driveService, activation shows 'Install'
    expect(find.text('Install'), findsWidgets);

    // Allow background delayed sync timer to run and settle so no pending timers remain
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
  });



  testWidgets('ModuleScreen loads direct sheet ids when provided', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final mockDrive = MockDriveService();

    // Provide direct reads
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
    final workspaceProvider = WorkspaceProvider(driveService: null);
    workspaceProvider.setWorkspace(drive.File()..id = 'ws1');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SchemaProvider>.value(value: schemaProvider),
          ChangeNotifierProvider<DriveProvider>.value(value: driveProvider),
          ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaceProvider),
        ],
        child: MaterialApp(home: ModuleScreen(module: hostModule, settingsSheetId: 's1', dashboardSheetId: 'd1', tabsSheetId: 't1')),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 800));

    // Should have cached and processed the direct name
    expect(find.textContaining('DIRECTHOST') , findsOneWidget);
  });

}

