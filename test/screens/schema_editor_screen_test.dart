import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:drivererpapp/screens/schema_editor_screen.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/services/schema_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/schema_editor/structure_editor.dart';
import 'package:drivererpapp/screens/schema_editor/dashboard_editor.dart';
import 'package:drivererpapp/screens/schema_editor/settings_editor.dart';

class MockDriveProvider extends Mock implements DriveProvider {}
class MockSchemaProvider extends Mock implements SchemaProvider {}
class MockDriveService extends Mock implements DriveService {}
class MockSchemaService extends Mock implements SchemaService {}

void main() {
  late MockDriveProvider mockDriveProvider;
  late MockSchemaProvider mockSchemaProvider;
  late MockDriveService mockDriveService;
  late MockSchemaService mockSchemaService;
  late ModuleSchema testModule;

  setUp(() {
    mockDriveProvider = MockDriveProvider();
    mockSchemaProvider = MockSchemaProvider();
    mockDriveService = MockDriveService();
    mockSchemaService = MockSchemaService();

    // Setup Providers
    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockSchemaProvider.service).thenReturn(mockSchemaService);

    // Setup Test Data
    testModule = ModuleSchema(
      id: 'test_module',
      name: 'Test Module',
      icon: 'home',
      primaryColor: '#2196F3',
      version: '1.0.0',
      settings: {
        'setting1': SettingItem(
          type: 'text', 
          label: 'Setting 1', 
          defaultValue: 'default'
        )
      },
      dashboard: DashboardConfig(cards: []),
      tabs: [],
    );
  });

  Widget createWidgetUnderTest(bool isNewSetup) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ChangeNotifierProvider<SchemaProvider>.value(value: mockSchemaProvider),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SchemaEditorScreen(
                        module: testModule,
                        isNewSetup: isNewSetup,
                      ),
                    ),
                  );
                },
                child: const Text('OPEN EDITOR'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('SchemaEditorScreen renders correctly with 3 tabs', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest(false));
    await tester.tap(find.text('OPEN EDITOR'));
    await tester.pumpAndSettle();

    // Check AppBar title
    expect(find.text('BLUEPRINT EDITOR'), findsOneWidget);

    // Check Tabs
    expect(find.text('STRUCTURE'), findsOneWidget);
    expect(find.text('DASHBOARD'), findsOneWidget);
    expect(find.text('SETTINGS'), findsOneWidget);

    // Initial View should be StructureEditor
    expect(find.byType(StructureEditor), findsOneWidget);
  });

  testWidgets('SchemaEditorScreen changes tabs correctly', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest(false));
    await tester.tap(find.text('OPEN EDITOR'));
    await tester.pumpAndSettle();

    // Tap Dashboard Tab
    await tester.tap(find.text('DASHBOARD'));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardEditor), findsOneWidget);

    // Tap Settings Tab
    await tester.tap(find.text('SETTINGS'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsEditor), findsOneWidget);
  });

  testWidgets('SchemaEditorScreen saves changes successfully', (WidgetTester tester) async {
    // Setup Mock Responses for Save
    when(() => mockDriveService.getFileId(any(), any())).thenAnswer((_) async => 'existing_file_id');
    when(() => mockDriveService.updateModuleConfig(any(), any())).thenAnswer((_) async {});
    when(() => mockDriveService.getFileModifiedTime(any())).thenAnswer((_) async => DateTime.now());
    when(() => mockSchemaService.cacheConfig(any(), any(), fileId: any(named: 'fileId'), modifiedTime: any(named: 'modifiedTime'))).thenAnswer((_) async {});
    when(() => mockSchemaProvider.updateMemoryCache(any(), any())).thenReturn(null);

    await tester.pumpWidget(createWidgetUnderTest(false));
    await tester.tap(find.text('OPEN EDITOR'));
    await tester.pumpAndSettle();

    // Tap Save
    await tester.tap(find.text('SAVE'));
    await tester.pump(); // Start save
    await tester.pump(const Duration(milliseconds: 100)); // Allow async
    await tester.pumpAndSettle(); // Finish save

    // Verify calls
    verify(() => mockDriveService.getFileId('test_module', 'config')).called(1);
    verify(() => mockDriveService.updateModuleConfig('existing_file_id', any())).called(1);
    verify(() => mockSchemaProvider.updateMemoryCache('test_module', null)).called(1);
    
    // Should verify Success SnackBar
    expect(find.text('Configuration saved successfully.'), findsOneWidget);
    
    // Check that we popped back to main screen
    expect(find.text('OPEN EDITOR'), findsOneWidget);
  });

  testWidgets('SchemaEditorScreen handles save error', (WidgetTester tester) async {
    // Setup Mock Responses for Failure
    when(() => mockDriveService.getFileId(any(), any())).thenThrow(Exception('Drive Error'));

    await tester.pumpWidget(createWidgetUnderTest(false));
    await tester.tap(find.text('OPEN EDITOR'));
    await tester.pumpAndSettle();

    // Tap Save
    await tester.tap(find.text('SAVE'));
    await tester.pump(); // Start save
    await tester.pump(const Duration(milliseconds: 100)); // Allow async
    await tester.pumpAndSettle(); // Finish save

    // Verify calls
    verify(() => mockDriveService.getFileId('test_module', 'config')).called(1);
    
    // Should verify Error SnackBar
    expect(find.textContaining('Error saving configuration: Exception: Drive Error'), findsOneWidget);
    // Should still be on the editor screen
    expect(find.text('SAVE'), findsOneWidget);
  });
}
