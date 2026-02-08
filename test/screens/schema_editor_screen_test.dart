import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/schema_editor_screen.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/services/schema_service.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class MockSchemaProvider extends Mock implements SchemaProvider {}
class MockDriveProvider extends Mock implements DriveProvider {}
class MockSchemaService extends Mock implements SchemaService {}
class MockWorkspaceProvider extends Mock implements WorkspaceProvider {}
class MockAuthService extends Mock implements AuthService {}
class MockDriveService extends Mock implements DriveService {}

class FakeModuleSchema extends Fake implements ModuleSchema {}
class FakeDashboardCard extends Fake implements DashboardCard {}

class MockUser extends Mock implements GoogleSignInAccount {
  @override
  final String email;
  MockUser({required this.email});
}

void main() {
  late MockSchemaProvider mockSchemaProvider;
  late MockDriveProvider mockDriveProvider;
  late MockSchemaService mockSchemaService;

  setUpAll(() {
    registerFallbackValue(FakeModuleSchema());
    registerFallbackValue(FakeDashboardCard());
  });

  setUp(() {
    mockSchemaProvider = MockSchemaProvider();
    mockDriveProvider = MockDriveProvider();
    mockSchemaService = MockSchemaService();

    when(() => mockSchemaProvider.service).thenReturn(mockSchemaService);
    when(() => mockSchemaProvider.updateMemoryCache(any(), any())).thenReturn(null);

    // Default mock behavior for save methods
    when(() => mockSchemaService.saveSettingFields(any(), any(), settingsId: any(named: 'settingsId')))
        .thenAnswer((_) async {});
    when(() => mockSchemaService.saveTabFields(any(), any(), any(), settingsId: any(named: 'settingsId'), tabsId: any(named: 'tabsId')))
        .thenAnswer((_) async {});
    when(() => mockSchemaService.saveDashboardPart(any(), any(), settingsId: any(named: 'settingsId'), dashboardId: any(named: 'dashboardId')))
        .thenAnswer((_) async {});
    when(() => mockSchemaService.saveTabsPart(any(), any(), settingsId: any(named: 'settingsId'), tabsId: any(named: 'tabsId')))
        .thenAnswer((_) async {});
    when(() => mockSchemaService.cacheConfig(any(), any(), fileId: any(named: 'fileId'), modifiedTime: any(named: 'modifiedTime')))
        .thenAnswer((_) async {});
  });

  Widget createEditorScreen(ModuleSchema module, {bool isNewSetup = false, String? settingsSheetId, String? dashboardSheetId, String? tabsSheetId}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SchemaProvider>.value(value: mockSchemaProvider),
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
      ],
      child: MaterialApp(
        home: SchemaEditorScreen(module: module, isNewSetup: isNewSetup, settingsSheetId: settingsSheetId, dashboardSheetId: dashboardSheetId, tabsSheetId: tabsSheetId),
      ),
    );
  }

  final testModule = ModuleSchema(
    id: 'mod123',
    name: 'Sales',
    tabs: [
      TabConfig(id: 'tab1', label: 'Orders', columns: [])
    ],
    version: '1.0',
    icon: 'shopping_cart',
    primaryColor: '#3B82F6',
    settings: {
      'custom_name': SettingItem(
        label: 'Custom Name',
        type: 'text',
        defaultValue: 'Default',
        value: 'Current Value'
      )
    },
    dashboard: DashboardConfig(cards: [
      DashboardCard(label: 'KPI 1', formula: '100', format: 'number')
    ]),
  );

  testWidgets('SchemaEditorScreen renders and switches tabs', (WidgetTester tester) async {
    await tester.pumpWidget(createEditorScreen(testModule));

    expect(find.text('BLUEPRINT EDITOR'), findsOneWidget);
    expect(find.text('STRUCTURE'), findsOneWidget);
    
    // Switch to Dashboard
    await tester.tap(find.text('DASHBOARD'));
    await tester.pumpAndSettle();
    expect(find.text('Add Card'), findsOneWidget);

    // Switch to Settings
    await tester.tap(find.text('SETTINGS'));
    await tester.pumpAndSettle();
    expect(find.text('Custom Name'), findsOneWidget);
  });

  testWidgets('SchemaEditorScreen saves changes successfully', (WidgetTester tester) async {
    await tester.pumpWidget(createEditorScreen(testModule, settingsSheetId: 's1', dashboardSheetId: 'd1', tabsSheetId: 't1'));
    
    // Make a change to trigger a settings save
    await tester.tap(find.text('SETTINGS'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'New Value');
    await tester.pump();

    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    verify(() => mockSchemaService.saveSettingFields('mod123', any(), settingsId: 's1')).called(1);
    verify(() => mockSchemaProvider.updateMemoryCache('mod123', any())).called(1);
  });

  testWidgets('SchemaEditorScreen handles save error', (WidgetTester tester) async {
    when(() => mockSchemaService.saveSettingFields(any(), any(), settingsId: any(named: 'settingsId')))
        .thenThrow(Exception('Save failed'));

    await tester.pumpWidget(createEditorScreen(testModule, settingsSheetId: 's1', dashboardSheetId: 'd1', tabsSheetId: 't1'));
    
    // Make a change to trigger save
    await tester.tap(find.text('SETTINGS'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Err');
    await tester.pump();

    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Error saving configuration:'), findsOneWidget);
  });

  testWidgets('SchemaEditorScreen renders ACTIVATE in new setup mode', (WidgetTester tester) async {
    await tester.pumpWidget(createEditorScreen(testModule, isNewSetup: true));
    expect(find.text('COMPLETE SETUP'), findsOneWidget);
    expect(find.text('ACTIVATE'), findsOneWidget);
  });

  testWidgets('SchemaEditorScreen allows adding and editing cards', (WidgetTester tester) async {
    await tester.pumpWidget(createEditorScreen(testModule));
    
    await tester.tap(find.text('DASHBOARD'));
    await tester.pumpAndSettle();

    // Edit existing card
    await tester.tap(find.byIcon(Icons.edit_rounded));
    await tester.pumpAndSettle();
    expect(find.text('CONFIGURE CARD'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'New KPI Name');
    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();
    expect(find.text('New KPI Name'), findsOneWidget);

    // Add new card
    await tester.tap(find.text('Add Card'));
    await tester.pumpAndSettle();
    expect(find.text('CHOOSE VISUALIZATION'), findsOneWidget);
    
    // Select a template
    await tester.tap(find.text('Number'));
    await tester.pumpAndSettle();
    
    // Configure the new card
    expect(find.text('CONFIGURE CARD'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Fresh Card');
    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();
    expect(find.text('Fresh Card'), findsOneWidget);

    // Delete a card
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    expect(find.text('New KPI Name'), findsNothing);
  });

  testWidgets('SchemaEditorScreen handles settings and tab changes', (WidgetTester tester) async {
    await tester.pumpWidget(createEditorScreen(testModule, settingsSheetId: 's1', dashboardSheetId: 'd1', tabsSheetId: 't1'));
    
    // Test onSettingChanged (Settings Tab)
    await tester.tap(find.text('SETTINGS'));
    await tester.pumpAndSettle();
    
    // Find the text field for custom_name
    await tester.enterText(find.byType(TextField).first, 'Updated Value');
    await tester.pump();
    
    // Verify it saved by switching away and back? 
    // Actually we can just save and check if the save call has the new value.
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    verify(() => mockSchemaService.saveSettingFields(any(), any(), settingsId: any(named: 'settingsId'))).called(1);
  });

  testWidgets('SchemaEditorScreen handles deactivation', (WidgetTester tester) async {
    final mockWorkspaceProvider = MockWorkspaceProvider();
    final mockWorkspaceFile = drive.File(id: 'w1', name: 'W1');
    when(() => mockWorkspaceProvider.currentWorkspace).thenReturn(mockWorkspaceFile);
    when(() => mockWorkspaceProvider.lastUserAccessSpreadsheetId).thenReturn('ua123');
    
    final mockAuthService = MockAuthService();
    when(() => mockAuthService.currentUser).thenReturn(MockUser(email: 'test@test.com'));
    
    final mockDriveService = MockDriveService();
    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockDriveService.setUserAccessModuleStatus(any(), any(), any())).thenAnswer((_) async {});

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<SchemaProvider>.value(value: mockSchemaProvider),
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
      ],
      child: MaterialApp(
        home: SchemaEditorScreen(module: testModule),
      ),
    ));

    await tester.tap(find.text('SETTINGS'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('DEACTIVATE'));
    await tester.pumpAndSettle();

    expect(find.text('Deactivate Module'), findsOneWidget);
    await tester.tap(find.text('DEACTIVATE').last); // The button in dialog
    await tester.pumpAndSettle();

    verify(() => mockDriveService.setUserAccessModuleStatus('ua123', 'mod123', 'deactivated')).called(1);
  });
}
