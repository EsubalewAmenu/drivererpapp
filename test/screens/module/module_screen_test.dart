import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/module_screen.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class MockDriveService extends Mock implements DriveService {}

class TestDriveProvider extends DriveProvider {
  final DriveService? mockService;
  TestDriveProvider(this.mockService);
  @override
  DriveService? get driveService => mockService;
}

void main() {
  testWidgets('ModuleScreen extensions tab shows no extensions message', (tester) async {
    final mockDrive = MockDriveService();
    final tab = TabConfig(id: 't1', label: 'Items', columns: []);
    final module = ModuleSchema(id: 'mod1', name: 'Inventory', icon: 'inventory', primaryColor: '#2196F3', version: '1.0', settings: {}, dashboard: DashboardConfig(cards: []), tabs: [tab]);

    final schemaProvider = SchemaProvider();
    schemaProvider.updateMemoryCache(module.id, module);

    final driveProvider = TestDriveProvider(mockDrive);
    final workspaceProvider = WorkspaceProvider();
    workspaceProvider.setWorkspace(drive.File()..id = 'ws1');

    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<SchemaProvider>.value(value: schemaProvider),
      ChangeNotifierProvider<DriveProvider>.value(value: driveProvider),
      ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaceProvider),
    ], child: MaterialApp(home: ModuleScreen(module: module))));

    await tester.pumpAndSettle();

    // Switch to EXTENSIONS tab
    final extTab = find.text('EXTENSIONS');
    expect(extTab, findsOneWidget);
    await tester.tap(extTab);
    await tester.pumpAndSettle();

    expect(find.text('No extensions available'), findsOneWidget);
  });
}
