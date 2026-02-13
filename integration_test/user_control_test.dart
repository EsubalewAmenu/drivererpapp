import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/providers/theme_provider.dart';
import 'package:drivererpapp/screens/dashboard_screen.dart';
import 'package:drivererpapp/screens/user_control/user_control_screen.dart';
import 'package:drivererpapp/screens/user_control/user_access_management_screen.dart';
import 'package:drivererpapp/widgets/app_drawer.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;

// Local Mocks to ensure isolation and control
class MockAuthService extends Mock implements AuthService {}

class MockDriveService extends Mock implements DriveService {
  @override
  late drive.DriveApi driveApi;
  @override
  late sheets.SheetsApi sheetsApi;

  MockDriveService() {
    driveApi = MockDriveApi();
    sheetsApi = MockSheetsApi();
  }
}

class MockDriveApi extends Mock implements drive.DriveApi {}

class MockSheetsApi extends Mock implements sheets.SheetsApi {
  @override
  late sheets.SpreadsheetsResource spreadsheets;

  MockSheetsApi() {
    spreadsheets = MockSpreadsheetsResource();
  }
}

class MockSpreadsheetsResource extends Mock implements sheets.SpreadsheetsResource {
  final _values = MockValuesResource();
  @override
  sheets.SpreadsheetsValuesResource get values => _values;
}

class MockValuesResource extends Mock implements sheets.SpreadsheetsValuesResource {}

class TestDriveProvider extends DriveProvider {
  final DriveService? _mockService;
  TestDriveProvider(this._mockService);
  @override
  DriveService? get driveService => _mockService;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthService mockAuthService;
  late MockDriveService mockDriveService;
  late MockValuesResource mockValues;
  late WorkspaceProvider workspaceProvider;

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(sheets.ValueRange());
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    mockAuthService = MockAuthService();
    mockDriveService = MockDriveService();
    mockValues = mockDriveService.sheetsApi.spreadsheets.values as MockValuesResource;
    workspaceProvider = WorkspaceProvider();

    when(() => mockAuthService.isAuthenticated).thenReturn(true);
    when(() => mockAuthService.currentUser).thenReturn(null);
  });

  Widget createTestApp(Widget home) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<DriveProvider>(create: (_) => TestDriveProvider(mockDriveService)),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaceProvider),
      ],
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          primaryColor: Colors.blue,
          scaffoldBackgroundColor: Colors.white,
          textTheme: const TextTheme(
            bodyLarge: TextStyle(fontFamily: 'Roboto'),
            bodyMedium: TextStyle(fontFamily: 'Roboto'),
          ),
        ),
        home: home,
      ),
    );
  }

  group('User Control Navigation Integration Test', () {
    testWidgets('Open drawer and navigate to User Control screen', (WidgetTester tester) async {
      // 1. Setup Workspace Provider state
      workspaceProvider.setRootFolderId('root_123');
      workspaceProvider.setWorkspace(drive.File(id: 'workspace_123', name: 'Test Workspace'));

      // 2. Mock Dashboard data loading (avoiding empty screen hanging)
      when(() => mockValues.get(any(), any()))
          .thenAnswer((_) async => sheets.ValueRange(values: []));

      // 3. Mock UserControlScreen dependencies (Registry and user list)
      when(() => mockDriveService.ensureCompanyRegistry(any()))
          .thenAnswer((_) async => 'registry_id');
      
      when(() => mockValues.get('registry_id', 'user_access!A:C'))
          .thenAnswer((_) async => sheets.ValueRange(values: [
            ['company_folder_id', 'email', 'spreadsheet_id'],
            ['workspace_123', 'test@example.com', 'sheet_123'],
          ]));

      // Start the application
      await tester.pumpWidget(createTestApp(const DashboardScreen()));
      await tester.pumpAndSettle();

      // Ensure we are on Dashboard
      expect(find.byType(DashboardScreen), findsOneWidget);

      // Open the Drawer
      final scaffoldFinder = find.byType(Scaffold);
      final ScaffoldState state = tester.state(scaffoldFinder);
      state.openDrawer();
      await tester.pumpAndSettle();

      // Verify Drawer is open
      expect(find.byType(AppDrawer), findsOneWidget);
      
      // Tap on "User Control"
      final userControlItem = find.text('User Control');
      expect(userControlItem, findsOneWidget);
      await tester.tap(userControlItem);
      await tester.pumpAndSettle();

      // Verify we navigated to the User Control Screen
      expect(find.byType(UserControlScreen), findsOneWidget);
      expect(find.text('USER CONTROL'), findsOneWidget);
    });

    testWidgets('Open Add User dialog and verify its components', (WidgetTester tester) async {
      // Setup state
      workspaceProvider.setRootFolderId('root_123');
      workspaceProvider.setWorkspace(drive.File(id: 'workspace_123', name: 'Test Workspace'));

      // Mock drive registry
      when(() => mockDriveService.ensureCompanyRegistry(any()))
          .thenAnswer((_) async => 'registry_id');
      
      // Mock user list (empty for this test)
      when(() => mockValues.get('registry_id', 'user_access!A:C'))
          .thenAnswer((_) async => sheets.ValueRange(values: []));

      // Go directly to UserControlScreen
      await tester.pumpWidget(createTestApp(const UserControlScreen()));
      await tester.pumpAndSettle();

      // Find the "Add User" FAB and tap it
      final addUserFab = find.widgetWithText(FloatingActionButton, 'Add User');
      expect(addUserFab, findsOneWidget);
      await tester.tap(addUserFab);
      await tester.pumpAndSettle();

      // Verify the dialog is shown
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Add User')), findsOneWidget);
      
      // Verify TextField presence
      expect(find.byType(TextField), findsOneWidget);

      // Verify buttons
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);

      // Tap Cancel to close
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Verify dialog is gone
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('Add user successfully', (WidgetTester tester) async {
      // Setup state
      workspaceProvider.setRootFolderId('root_123');
      workspaceProvider.setWorkspace(drive.File(id: 'workspace_123', name: 'Test Workspace'));

      // Mock drive registry
      when(() => mockDriveService.ensureCompanyRegistry(any()))
          .thenAnswer((_) async => 'registry_id');
      
      // Mock user list (initial empty, then one user after refresh)
      var userListCallCount = 0;
      when(() => mockValues.get('registry_id', 'user_access!A:C'))
          .thenAnswer((_) async {
            if (userListCallCount == 0) {
              userListCallCount++;
              return sheets.ValueRange(values: []);
            }
            return sheets.ValueRange(values: [
              ['company_folder_id', 'email', 'spreadsheet_id'],
              ['workspace_123', 'newuser@example.com', 'new_sheet_123'],
            ]);
          });

      // Mock steps in adding user
      when(() => mockDriveService.getOrCreateSubFolder(any(), any()))
          .thenAnswer((_) async => 'user_access_folder_id');
      when(() => mockDriveService.createUserAccessSpreadsheet(any(), any()))
          .thenAnswer((_) async => 'new_sheet_123');
      when(() => mockDriveService.upsertCompanyUserAccess(any(), any(), any(), any()))
          .thenAnswer((_) async => {});

      // Go to UserControlScreen
      await tester.pumpWidget(createTestApp(const UserControlScreen()));
      await tester.pumpAndSettle();

      // Open Add User dialog
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Add User'));
      await tester.pumpAndSettle();

      // Enter email
      await tester.enterText(find.byType(TextField), 'newuser@example.com');
      await tester.pumpAndSettle();

      // Tap Add
      await tester.tap(find.text('Add'));
      
      // The adding process involves async calls and then Navigator.pop and _loadUsers()
      // We might need multiple pumps to handle the async work and state updates
      await tester.pump(); // Start async work
      await tester.pumpAndSettle(); // Wait for navigation and list refresh

      // Verify dialog is closed
      expect(find.byType(AlertDialog), findsNothing);

      // Verify the new user is in the list
      expect(find.text('newuser@example.com'), findsOneWidget);
    });

    testWidgets('Show error when adding user with empty email', (WidgetTester tester) async {
      workspaceProvider.setRootFolderId('root_123');
      workspaceProvider.setWorkspace(drive.File(id: 'workspace_123', name: 'Test Workspace'));

      await tester.pumpWidget(createTestApp(const UserControlScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Add User'));
      await tester.pumpAndSettle();

      // Tap Add without entering email
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      // Verify SnackBar with error message
      expect(find.text('Please enter an email address'), findsOneWidget);
      
      // Dialog should still be open
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('Tap user card to navigate to User Access Management screen', (WidgetTester tester) async {
      // Setup state
      workspaceProvider.setRootFolderId('root_123');
      workspaceProvider.setWorkspace(drive.File(id: 'workspace_123', name: 'Test Workspace'));

      // Mock drive registry
      when(() => mockDriveService.ensureCompanyRegistry(any()))
          .thenAnswer((_) async => 'registry_id');

      // 1. Mock general calls first (e.g. for UserAccessManagementScreen modules)
      when(() => mockValues.get(any(), any()))
          .thenAnswer((_) async => sheets.ValueRange(values: []));
      
      // 2. Mock specific calls that override the general ones (e.g. for UserControlScreen list)
      when(() => mockValues.get('registry_id', 'user_access!A:C'))
          .thenAnswer((_) async => sheets.ValueRange(values: [
            ['company_folder_id', 'email', 'spreadsheet_id'],
            ['workspace_123', 'test@example.com', 'sheet_123'],
          ]));

      // Go to UserControlScreen
      await tester.pumpWidget(createTestApp(const UserControlScreen()));
      await tester.pumpAndSettle();

      // Find the user email text and tap on the card
      final userCard = find.text('test@example.com');
      expect(userCard, findsOneWidget);
      await tester.tap(userCard);
      await tester.pumpAndSettle();

      // Verify navigation to UserAccessManagementScreen
      expect(find.byType(UserAccessManagementScreen), findsOneWidget);
      expect(find.text('MANAGE ACCESS'), findsOneWidget);
    });

    testWidgets('Add module in User Access Management screen', (WidgetTester tester) async {
      // 1. Setup state
      workspaceProvider.setRootFolderId('root_123');
      workspaceProvider.setWorkspace(drive.File(id: 'workspace_123', name: 'Test Workspace'));
      await workspaceProvider.saveUserAccessSpreadsheetId('registry_sheet_id');

      // 2. Mock specific behaviors
      when(() => mockDriveService.ensureCompanyRegistry(any()))
          .thenAnswer((_) async => 'registry_id');

      // 3. Chain mock calls for initial load of UserAccessManagementScreen
      // Reading from widget.spreadsheetId (modules!A1:H1000) - current access
      when(() => mockValues.get('sheet_123', 'modules!A1:H1000'))
          .thenAnswer((_) async => sheets.ValueRange(values: [
            ['module_id', 'module_name', 'dashboard', 'settings', 'tabs', 'files', 'type', 'status'],
          ])); // Empty access list

      // Reading from registry for available modules
      when(() => mockValues.get('registry_sheet_id', 'modules!A1:H1000'))
          .thenAnswer((_) async => sheets.ValueRange(values: [
            ['module_id', 'module_name', 'dashboard_id', 'settings_id', 'tabs_id', 'files_id', 'type', 'status'],
            ['crm', 'CRM Module', 'dash_crm', 'set_crm', 'tabs_crm', 'files_crm', 'erp', 'activated'],
          ]));

      // Mock various DriveService calls during "Add"
      when(() => mockDriveService.getOrCreateSubFolder(any(), any()))
          .thenAnswer((_) async => 'config_folder_id');
      when(() => mockDriveService.readDashboardById(any()))
          .thenAnswer((_) async => {'cards': []});
      when(() => mockDriveService.readSettingsById(any()))
          .thenAnswer((_) async => {'theme': 'light'});
      when(() => mockDriveService.readTabsById(any()))
          .thenAnswer((_) async => []);
      when(() => mockDriveService.createModuleConfig(any(), any(), any()))
          .thenAnswer((_) async => {'dashboard': 'd_id', 'settings': 's_id', 'tabs': 't_id'});
      when(() => mockDriveService.upsertUserAccessModule(any(), any(), any(), any(), any(), any(), any(), moduleType: any(named: 'moduleType')))
          .thenAnswer((_) async => {});
      when(() => mockDriveService.setUserAccessModuleStatus(any(), any(), any()))
          .thenAnswer((_) async => {});

      // 4. Start at UserAccessManagementScreen directly for this test
      await tester.pumpWidget(createTestApp(const UserAccessManagementScreen(
        email: 'test@example.com',
        spreadsheetId: 'sheet_123',
      )));
      await tester.pumpAndSettle();

      // Find "ADD MODULE" button
      final addModuleBtn = find.text('ADD MODULE');
      expect(addModuleBtn, findsOneWidget);
      await tester.tap(addModuleBtn);
      await tester.pumpAndSettle();

      // Verify Dialog
      expect(find.text('Add Modules'), findsOneWidget);
      expect(find.text('CRM Module'), findsOneWidget);

      // Select module (Checkbox/InkWell)
      await tester.tap(find.text('CRM Module'));
      await tester.pumpAndSettle();

      // Tap "Add" in dialog
      final addBtn = find.descendant(of: find.byType(AlertDialog), matching: find.text('Add'));
      await tester.tap(addBtn);

      // New mock for refresh after add
      when(() => mockValues.get('sheet_123', 'modules!A1:H1000'))
          .thenAnswer((_) async => sheets.ValueRange(values: [
            ['module_id', 'module_name', 'dashboard', 'settings', 'tabs', 'files', 'type', 'status'],
            ['crm', 'CRM Module', 'true', 'true', 'tabs_crm', 'files_crm', 'erp', 'activated'],
          ]));

      await tester.pumpAndSettle();

      // Verify module is now in the list
      expect(find.text('CRM Module'), findsOneWidget);
    });

    testWidgets('Deactivate and activate module access', (WidgetTester tester) async {
      // Setup state
      workspaceProvider.setRootFolderId('root_123');
      workspaceProvider.setWorkspace(drive.File(id: 'workspace_123', name: 'Test Workspace'));

      // Mock existing module access
      when(() => mockValues.get('sheet_123', 'modules!A1:H1000'))
          .thenAnswer((_) async => sheets.ValueRange(values: [
            ['module_id', 'module_name', 'dashboard', 'settings', 'tabs', 'files', 'type', 'status'],
            ['crm', 'CRM Module', 'true', 'true', 'tabs_crm', 'files_crm', 'erp', 'activated'],
          ]));

      // Go to UserAccessManagementScreen
      await tester.pumpWidget(createTestApp(const UserAccessManagementScreen(
        email: 'test@example.com',
        spreadsheetId: 'sheet_123',
      )));
      await tester.pumpAndSettle();

      // Find the Switch
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      
      // Initial state is active
      Switch switchWidget = tester.widget(switchFinder);
      expect(switchWidget.value, isTrue);

      // 1. Toggle to Deactivate
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Verify local state change (SAVE CHANGES button should appear)
      expect(find.text('SAVE CHANGES'), findsOneWidget);
      switchWidget = tester.widget(switchFinder);
      expect(switchWidget.value, isFalse);

      // 2. Toggle back to Activate (Undo change)
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // SAVE CHANGES should disappear as it matches original state
      expect(find.text('SAVE CHANGES'), findsNothing);
      switchWidget = tester.widget(switchFinder);
      expect(switchWidget.value, isTrue);

      // 3. Deactivate again and SAVE
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Mock the save operation (sheets.values.update)
      when(() => mockDriveService.sheetsApi.spreadsheets.values.update(
        any(), any(), any(), 
        valueInputOption: any(named: 'valueInputOption')
      )).thenAnswer((_) async => sheets.UpdateValuesResponse());

      await tester.tap(find.text('SAVE CHANGES'));
      await tester.pumpAndSettle();

      // Verify we navigated back (Navigator.pop is called on success in _saveChanges)
      // Since we started at UserAccessManagementScreen, it should pop to nothing/root
      // Actually, in the test it might throw if there's no previous route.
      // But we can verify it attempted to save.
      verify(() => mockDriveService.sheetsApi.spreadsheets.values.update(
        any(), any(), any(), 
        valueInputOption: 'RAW'
      )).called(1);
    });
  });
}
