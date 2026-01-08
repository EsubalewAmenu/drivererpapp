import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/module_screen.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/services/schema_service.dart';
import 'package:drivererpapp/services/drive_service.dart';

class MockSchemaProvider extends Mock implements SchemaProvider {}
class MockSchemaService extends Mock implements SchemaService {}
class MockDriveProvider extends Mock implements DriveProvider {}
class MockDriveService extends Mock implements DriveService {}
class MockWorkspaceProvider extends Mock implements WorkspaceProvider {}

void main() {
  late MockSchemaProvider mockSchemaProvider;
  late MockSchemaService mockSchemaService;
  late MockDriveProvider mockDriveProvider;
  late MockDriveService mockDriveService;
  late MockWorkspaceProvider mockWorkspaceProvider;

  setUp(() {
    mockSchemaProvider = MockSchemaProvider();
    mockSchemaService = MockSchemaService();
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();
    mockWorkspaceProvider = MockWorkspaceProvider();

    when(() => mockSchemaProvider.service).thenReturn(mockSchemaService);
    when(() => mockSchemaProvider.getFromMemory(any())).thenReturn(null);
    when(() => mockSchemaService.getCachedConfig(any())).thenAnswer((_) async => null);
    when(() => mockSchemaService.syncConfig(any())).thenAnswer((_) async => null);
    
    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockWorkspaceProvider.isLoading).thenReturn(false);
    when(() => mockWorkspaceProvider.currentWorkspace).thenReturn(null);
  });

  Widget createModuleScreen(ModuleSchema module) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SchemaProvider>.value(value: mockSchemaProvider),
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
      ],
      child: MaterialApp(
        home: ModuleScreen(module: module),
      ),
    );
  }

  testWidgets('ModuleScreen loads and displays module', (WidgetTester tester) async {
    final module = ModuleSchema(
      id: 'mod123',
      name: 'Sales',
      tabs: [],
      version: '1.0',
      icon: 'shopping_cart',
      primaryColor: '#3B82F6',
      settings: {},
      dashboard: DashboardConfig(cards: []),
    );

    when(() => mockSchemaService.syncConfig('mod123')).thenAnswer((_) async => Map<String, dynamic>.from({
      'id': 'mod123',
      'name': 'Sales',
      'tabs': [
        {'id': 'tab1', 'label': 'Orders', 'columns': []}
      ],
      'version': '1.0',
      'icon': 'shopping_cart',
      'primaryColor': '#3B82F6',
      'settings': {
        'name': {'value': 'Sales', 'label': 'Name', 'type': 'text'}
      },
      'dashboard': {'cards': []},
    }));

    await tester.pumpWidget(createModuleScreen(module));
    await tester.pump(); // Start sequence
    await tester.pumpAndSettle();

    expect(find.text('SALES'), findsOneWidget);
    expect(find.text('DASHBOARD'), findsOneWidget);
    expect(find.text('ORDERS'), findsOneWidget);

    // To handle the background sync Future.delayed(1500ms)
    await tester.pump(const Duration(seconds: 2));
  });
}
