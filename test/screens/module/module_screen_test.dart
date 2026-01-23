import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drivererpapp/screens/module_screen.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';

class MockDriveService extends Mock implements DriveService {}

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
}

