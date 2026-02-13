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
import 'package:drivererpapp/screens/user_control/module_access_detail_screen.dart';
import 'package:drivererpapp/screens/user_control/tabs/user_access_permissions_tab.dart';
import 'package:drivererpapp/screens/user_control/tabs/user_access_structure_tab.dart';
import 'package:drivererpapp/models/schema_models.dart';
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

class MockDriveApi extends Mock implements drive.DriveApi {
  @override
  late drive.PermissionsResource permissions;
  @override
  late drive.FilesResource files;

  MockDriveApi() {
    permissions = MockPermissionsResource();
    files = MockFilesResource();
  }
}

class MockPermissionsResource extends Mock implements drive.PermissionsResource {}

class MockFilesResource extends Mock implements drive.FilesResource {}

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
    registerFallbackValue(drive.Permission());
    registerFallbackValue(drive.PermissionList());
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

    testWidgets('Navigate to Module Detail page and verify Permissions tab', (WidgetTester tester) async {
      // Setup state
      workspaceProvider.setRootFolderId('root_123');
      workspaceProvider.setWorkspace(drive.File(id: 'workspace_123', name: 'Test Workspace'));

      // Mock existing module access
      when(() => mockValues.get('sheet_123', 'modules!A1:H1000'))
          .thenAnswer((_) async => sheets.ValueRange(values: [
            ['module_id', 'module_name', 'dashboard', 'settings', 'tabs', 'files', 'type', 'status'],
            ['crm', 'CRM Module', 'true', 'true', 'tabs_crm', 'files_crm', 'erp', 'activated'],
          ]));

      // Mock permissions check
      final mockPermissions = mockDriveService.driveApi.permissions as MockPermissionsResource;
      when(() => mockPermissions.list(
        any(),
        supportsAllDrives: any(named: 'supportsAllDrives'),
        pageSize: any(named: 'pageSize'),
        $fields: any(named: r'$fields'),
      )).thenAnswer((_) async => drive.PermissionList(permissions: [
        drive.Permission(emailAddress: 'test@example.com', role: 'reader'),
      ]));

      // Mock the row read in UserAccessPermissionsTab
      when(() => mockValues.get('sheet_123', 'modules!A2:H2'))
          .thenAnswer((_) async => sheets.ValueRange(values: [
            ['crm_folder', 'CRM Module', 'dash_id', 'set_id', 'tabs_id', 'files_id', 'erp', 'activated'],
          ]));

      // Start at UserAccessManagementScreen
      await tester.pumpWidget(createTestApp(const UserAccessManagementScreen(
        email: 'test@example.com',
        spreadsheetId: 'sheet_123',
      )));
      await tester.pumpAndSettle();

      // Find "View Details" and tap it
      final viewDetailsBtn = find.text('View Details');
      expect(viewDetailsBtn, findsOneWidget);
      await tester.tap(viewDetailsBtn);
      await tester.pumpAndSettle();

      // Verify navigation to ModuleAccessDetailScreen
      expect(find.byType(ModuleAccessDetailScreen), findsOneWidget);
      expect(find.text('CRM MODULE'), findsOneWidget);

      // Verify Permissions tab is visible
      expect(find.byType(UserAccessPermissionsTab), findsOneWidget);
      
      // Verify content in Permissions tab
      // Folders use 'Read Access' (Module Folder, Module Files) - 2 widgets
      // Files use 'Read Only' (Dashboard, Settings, Tabs) - 3 widgets
      expect(find.text('Read Access'), findsNWidgets(2));
      expect(find.text('Read Only'), findsNWidgets(3));
    });

    testWidgets('Change permissions and save in Permissions tab', (WidgetTester tester) async {
      // Setup state
      workspaceProvider.setRootFolderId('root_123');
      workspaceProvider.setWorkspace(drive.File(id: 'workspace_123', name: 'Test Workspace'));

      // Mock existing module access
      when(() => mockValues.get('sheet_123', 'modules!A1:H1000'))
          .thenAnswer((_) async => sheets.ValueRange(values: [
            ['module_id', 'module_name', 'dashboard', 'settings', 'tabs', 'files', 'type', 'status'],
            ['crm', 'CRM Module', 'true', 'true', 'tabs_crm', 'files_crm', 'erp', 'activated'],
          ]));

      // Mock initial permissions check (all Reader)
      final mockPermissions = mockDriveService.driveApi.permissions as MockPermissionsResource;
      when(() => mockPermissions.list(
        any(),
        supportsAllDrives: any(named: 'supportsAllDrives'),
        pageSize: any(named: 'pageSize'),
        $fields: any(named: r'$fields'),
      )).thenAnswer((_) async => drive.PermissionList(permissions: [
        drive.Permission(id: 'perm_123', emailAddress: 'test@example.com', role: 'reader'),
      ]));

      // Mock the row read in UserAccessPermissionsTab
      // This is called during load and during save
      when(() => mockValues.get('sheet_123', 'modules!A2:H2'))
          .thenAnswer((_) async => sheets.ValueRange(values: [
            ['crm_folder', 'CRM Module', 'dash_id', 'set_id', 'tabs_id', 'files_id', 'erp', 'activated'],
          ]));

      // Start at UserAccessManagementScreen
      await tester.pumpWidget(createTestApp(const UserAccessManagementScreen(
        email: 'test@example.com',
        spreadsheetId: 'sheet_123',
      )));
      await tester.pumpAndSettle();

      // Navigate to Detail page
      await tester.tap(find.text('View Details'));
      await tester.pumpAndSettle();

      // We are now on Permission tab. 
      // Current state: "Read Access" selected for Module Folder (ID: crm_folder)
      // Change to "Write Access"
      
      // Find "Write Access" for Module Folder. 
      // There are multiple "Write Access" widgets (one for each card: Folder, Files, Dashboard, etc.)
      // We can use descendant or find by coordinate, or find by text within a specific Card.
      
      final moduleFolderCard = find.ancestor(of: find.text('Module Folder'), matching: find.byType(Card));
      final writeAccessOption = find.descendant(of: moduleFolderCard, matching: find.text('Write Access'));
      
      await tester.tap(writeAccessOption);
      await tester.pumpAndSettle();

      // Verify "SAVE CHANGES" button appears
      expect(find.text('SAVE CHANGES'), findsOneWidget);

      // Mock the Update call
      when(() => mockPermissions.update(
        any(), any(), any(),
        supportsAllDrives: any(named: 'supportsAllDrives')
      )).thenAnswer((_) async => drive.Permission());

      // Tap SAVE CHANGES
      await tester.tap(find.text('SAVE CHANGES'));
      await tester.pumpAndSettle();

      // Verify Snack bar
      expect(find.text('Permissions updated successfully'), findsOneWidget);

      // Verify no more save button
      expect(find.text('SAVE CHANGES'), findsNothing);
      
      // Verify update was called for the folder ID 'crm_folder'
      verify(() => mockPermissions.update(
        any(),
        'crm_folder',
        'perm_123',
        supportsAllDrives: true
      )).called(1);
    });

    testWidgets('Modify and save structure in Structure tab', (WidgetTester tester) async {
      // Setup state
      workspaceProvider.setRootFolderId('root_123');
      workspaceProvider.setWorkspace(drive.File(id: 'workspace_123', name: 'Test Workspace'));

      // Mock existing module access
      when(() => mockValues.get('sheet_123', 'modules!A1:H1000'))
          .thenAnswer((_) async => sheets.ValueRange(values: [
            ['module_id', 'module_name', 'dashboard', 'settings', 'tabs', 'files', 'type', 'status'],
            ['crm', 'CRM Module', 'true', 'true', 'tabs_crm', 'files_crm', 'erp', 'activated'],
          ]));

      // Mock permissions check (required by ModuleAccessDetailScreen children sometimes, though Tab is separate)
      final mockPermissions = mockDriveService.driveApi.permissions as MockPermissionsResource;
      when(() => mockPermissions.list(any(), supportsAllDrives: any(named: 'supportsAllDrives'), pageSize: any(named: 'pageSize'), $fields: any(named: r'$fields')))
          .thenAnswer((_) async => drive.PermissionList(permissions: [
            drive.Permission(
              emailAddress: 'test@example.com',
              role: 'writer',
              type: 'user',
            ),
          ]));

      // Mock the row read in UserAccessStructureTab
      when(() => mockValues.get('sheet_123', 'modules!A2:H2'))
          .thenAnswer((_) async => sheets.ValueRange(values: [
            ['crm_folder', 'CRM Module', 'dash_id', 'set_id', 'tabs_id', 'files_id', 'erp', 'activated'],
          ]));

      // Mock readTabsById
      when(() => mockDriveService.readTabsById('tabs_id'))
          .thenAnswer((_) async => [
            {
              'id': 'tab_1',
              'label': 'Existing Tab',
              'columns': [
                {
                  'key': 'col_1',
                  'label': 'Existing Col',
                  'type': 'text',
                }
              ],
            }
          ]);

      // Start at UserAccessManagementScreen
      await tester.pumpWidget(createTestApp(const UserAccessManagementScreen(
        email: 'test@example.com',
        spreadsheetId: 'sheet_123',
      )));
      await tester.pumpAndSettle();

      // Navigate to Detail page
      await tester.tap(find.text('View Details'));
      await tester.pumpAndSettle();

      // Navigate to STRUCTURE tab
      await tester.tap(find.text('STRUCTURE'));
      await tester.pumpAndSettle();

      // Verify "Existing Tab" is visible
      expect(find.text('Existing Tab'), findsOneWidget);

      // 1. Edit the existing tab
      final editIcon = find.descendant(
        of: find.ancestor(of: find.text('Existing Tab'), matching: find.byType(Card)),
        matching: find.byIcon(Icons.edit_rounded),
      );
      await tester.tap(editIcon);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Updated Tab Label');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Updated Tab Label'), findsOneWidget);

      // 2. Expand tab to see columns
      await tester.tap(find.text('Updated Tab Label'));
      await tester.pumpAndSettle();

      // Verify "Existing Col" is visible
      expect(find.text('Existing Col'), findsOneWidget);

      // 3. Delete the existing column
      final deleteColIcon = find.descendant(
        of: find.ancestor(of: find.text('Existing Col'), matching: find.byType(Row)),
        matching: find.byIcon(Icons.delete_outline_rounded),
      ).first; // Ensure we get the icon button
      await tester.tap(deleteColIcon);
      await tester.pumpAndSettle();
      
      // Confirm delete in dialog
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Existing Col'), findsNothing);

      // 4. Add a new column
      await tester.tap(find.text('Add Column'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Column Name'), 'New Col Name');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('New Col Name'), findsOneWidget);

      // 5. Save changes
      when(() => mockDriveService.writeTabsById('tabs_id', any()))
          .thenAnswer((_) async => {});

      await tester.tap(find.text('SAVE STRUCTURE'));
      await tester.pumpAndSettle();

      // Verify success message
      expect(find.text('Structure updated successfully'), findsOneWidget);

      // Verify write was called
      verify(() => mockDriveService.writeTabsById('tabs_id', any())).called(1);
    });

    testWidgets('Change spreadsheet linkage in Structure tab', (tester) async {
      final mockDriveApi = mockDriveService.driveApi as MockDriveApi;
      final mockFiles = mockDriveApi.files as MockFilesResource;

      // Mock User's Access (the list of modules)
      when(() => mockValues.get('sheet_123', 'modules!A1:H1000'))
          .thenAnswer((_) async => sheets.ValueRange(values: [
            ['ID', 'Name', 'Dashboard', 'Settings', 'Tabs', 'Files', 'Type', 'Status'],
            ['crm', 'CRM Module', 'true', 'true', 'tabs_id', 'files_id', 'erp', 'activated'],
          ]));
      
      // Mock the row read in UserAccessStructureTab
      when(() => mockValues.get('sheet_123', 'modules!A2:H2'))
          .thenAnswer((_) async => sheets.ValueRange(values: [
            ['crm_folder', 'CRM Module', 'dash_id', 'set_id', 'tabs_id', 'files_id', 'erp', 'activated'],
          ]));

      // Mock readTabsById
      when(() => mockDriveService.readTabsById('tabs_id'))
          .thenAnswer((_) async => [
            {
              'id': 'tab_1',
              'label': 'Existing Tab',
              'fileId': 'old_file_id',
              'columns': [],
            }
          ]);

      // Mock spreadsheet picker list
      when(() => mockFiles.list(
            q: any(named: 'q'),
            spaces: any(named: 'spaces'),
            orderBy: any(named: 'orderBy'),
            pageSize: any(named: 'pageSize'),
            supportsAllDrives: any(named: 'supportsAllDrives'),
            includeItemsFromAllDrives: any(named: 'includeItemsFromAllDrives'),
            $fields: any(named: r'$fields'),
          )).thenAnswer((_) async => drive.FileList(files: [
            drive.File(id: 'new_spreadsheet_id', name: 'My New Spreadsheet'),
          ]));

      // Mock permissions (to avoid error logs if it tries to load)
      final mockPermissions = mockDriveApi.permissions as MockPermissionsResource;
      when(() => mockPermissions.list(any(), supportsAllDrives: any(named: 'supportsAllDrives'), pageSize: any(named: 'pageSize'), $fields: any(named: r'$fields')))
          .thenAnswer((_) async => drive.PermissionList(permissions: [
            drive.Permission(
              emailAddress: 'test@example.com',
              role: 'writer',
              type: 'user',
            ),
          ]));

      await tester.pumpWidget(createTestApp(const UserAccessManagementScreen(
        email: 'test@example.com',
        spreadsheetId: 'sheet_123',
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('View Details'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('STRUCTURE'));
      await tester.pumpAndSettle();

      // Verify old ID is shown
      expect(find.textContaining('old_file_id'), findsOneWidget);

      // Tap Change Spreadsheet
      await tester.tap(find.text('Change Spreadsheet'));
      await tester.pumpAndSettle();

      // Verify picker is shown
      expect(find.text('Choose Spreadsheet'), findsOneWidget);
      expect(find.text('My New Spreadsheet'), findsOneWidget);

      // Pick the new one
      await tester.tap(find.text('My New Spreadsheet'));
      await tester.pumpAndSettle();

      // Verify update on card
      expect(find.textContaining('new_spreadsheet_id'), findsOneWidget);
    });

    testWidgets('Comprehensive Structure Tab Management', (tester) async {
      // Setup row and tabs mock
      when(() => mockValues.get('sheet_123', 'modules!A1:H1000'))
          .thenAnswer((_) async => sheets.ValueRange(values: [
                ['ID', 'Name', 'Dash', 'Set', 'Tabs', 'Files', 'Type', 'Status'], // Header
                ['crm_folder', 'CRM Module', 'dash_id', 'set_id', 'tabs_id', 'files_id', 'erp', 'activated'],
              ]));

      when(() => mockValues.get('sheet_123', 'modules!A2:H2'))
          .thenAnswer((_) async => sheets.ValueRange(values: [
                ['crm_folder', 'CRM Module', 'dash_id', 'set_id', 'tabs_id', 'files_id', 'erp', 'activated'],
              ]));

      // Mock permissions for the CRM module files to avoid errors in Permissions tab
      final mockPerms = mockDriveService.driveApi.permissions as MockPermissionsResource;
      for (final id in ['crm_folder', 'dash_id', 'set_id', 'tabs_id', 'files_id']) {
        when(() => mockPerms.list(
          id,
          supportsAllDrives: any(named: 'supportsAllDrives'),
          pageSize: any(named: 'pageSize'),
          $fields: any(named: r'$fields'),
        )).thenAnswer((_) async => drive.PermissionList(permissions: [
          drive.Permission(
            emailAddress: 'test@example.com',
            role: 'writer',
            type: 'user',
          ),
        ]));
      }

      when(() => mockDriveService.readTabsById('tabs_id'))
          .thenAnswer((_) async => [
                {
                  'id': 'tab_1',
                  'label': 'Test Tab',
                  'columns': [
                    {'key': 'col_1', 'label': 'Old Col Name', 'type': 'text'},
                    {
                      'key': 'items',
                      'label': 'Items Table',
                      'type': 'table',
                      'columns': [
                        {'key': 'item_name', 'label': 'Item Name', 'type': 'text'}
                      ]
                    }
                  ],
                }
              ]);

      // We handle the save call too
      when(() => mockDriveService.writeTabsById('tabs_id', any()))
          .thenAnswer((_) async => {});

      await tester.pumpWidget(createTestApp(const UserAccessManagementScreen(
        email: 'test@example.com',
        spreadsheetId: 'sheet_123',
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('View Details'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('STRUCTURE'));
      await tester.pumpAndSettle();

      // 1. Expand tab
      await tester.tap(find.text('Test Tab'));
      await tester.pumpAndSettle();

      // 2. Edit an existing column label
      final editColIcon = find.descendant(
        of: find.ancestor(of: find.text('Old Col Name'), matching: find.byType(Row)),
        matching: find.byIcon(Icons.edit_rounded),
      ).first;
      await tester.tap(editColIcon);
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Column Name'), 'Better Col Name');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Better Col Name'), findsOneWidget);

      // 3. Edit advanced properties (Hidden/Required)
      final editColAgainIcon = find.descendant(
        of: find.ancestor(of: find.text('Better Col Name'), matching: find.byType(Row)),
        matching: find.byIcon(Icons.edit_rounded),
      ).first;
      await tester.tap(editColAgainIcon);
      await tester.pumpAndSettle();

      // Toggle switches (find by text in SwitchListTile)
      await tester.tap(find.text('Is Required'));
      await tester.pumpAndSettle();
      
      final hiddenSwitch = find.textContaining('Hidden');
      // Scroll to the switch more aggressively to ensure it's not under the button
      await tester.dragUntilVisible(
        hiddenSwitch,
        find.byType(ListView).hitTestable(),
        const Offset(0, -300),
      );
      await tester.tap(hiddenSwitch.hitTestable());
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Column Key'), 'better_col_key');
      await tester.enterText(find.widgetWithText(TextField, 'Help Text'), 'This is helpful');
      
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // 4. Manage sub-columns in Table type column
      // Expand Table Column
      await tester.tap(find.text('Items Table'));
      await tester.pumpAndSettle();

      // Verify sub-column exists
      expect(find.text('Item Name'), findsOneWidget);

      // Add sub-column to the table
      final addSubColBtn = find.text('Add Sub-Column');
      // Ensure the button is scrolled well into the viewport
      await tester.dragUntilVisible(
        addSubColBtn,
        find.byType(ListView).hitTestable(),
        const Offset(0, -300),
      );
      await tester.tap(addSubColBtn.hitTestable());
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Column Name'), 'Price');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Price'), findsOneWidget);

      // Delete the original sub-column
      final deleteSubColIcon = find.descendant(
        of: find.ancestor(of: find.text('Item Name'), matching: find.byType(Row)),
        matching: find.byIcon(Icons.delete_outline_rounded),
      ).first;
      // Scroll to the delete icon
      await tester.dragUntilVisible(
        deleteSubColIcon,
        find.byType(ListView).hitTestable(),
        const Offset(0, -300),
      );
      await tester.tap(deleteSubColIcon.hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Item Name'), findsNothing);

      // 4. Final Save of the entire Structure
      final saveBtn = find.text('SAVE STRUCTURE');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify the snackbar or success state
      expect(find.text('Structure updated successfully'), findsOneWidget);
      verify(() => mockDriveService.writeTabsById('tabs_id', any())).called(1);
    });

    testWidgets('Comprehensive Dashboard Tab Management', (tester) async {
       // Setup row and dashboard mock
      when(() => mockValues.get('sheet_123', 'modules!A1:H1000'))
          .thenAnswer((_) async => sheets.ValueRange(values: [
                ['ID', 'Name', 'Dash', 'Set', 'Tabs', 'Files', 'Type', 'Status'],
                ['crm_folder', 'CRM Module', 'dash_id', 'set_id', 'tabs_id', 'files_id', 'erp', 'activated'],
              ]));

      // Mock for individual tab loads (which use specific rows)
      when(() => mockValues.get('sheet_123', 'modules!A2:H2'))
          .thenAnswer((_) async => sheets.ValueRange(values: [
                ['crm_folder', 'CRM Module', 'dash_id', 'set_id', 'tabs_id', 'files_id', 'erp', 'activated'],
              ]));

      when(() => mockDriveService.readDashboardById('dash_id'))
          .thenAnswer((_) async => {
                'cards': [
                  {
                    'label': 'Total Revenue',
                    'formula': '=SUM(Sales!C:C)',
                    'type': 'kpi',
                  }
                ]
              });

      when(() => mockDriveService.writeDashboardById('dash_id', any()))
          .thenAnswer((_) async => {});

      // Mock permissions for the CRM module files (often checked by the UI)
      final mockPerms = mockDriveService.driveApi.permissions as MockPermissionsResource;
      for (final id in ['crm_folder', 'dash_id', 'set_id', 'tabs_id', 'files_id']) {
        when(() => mockPerms.list(
          id,
          supportsAllDrives: any(named: 'supportsAllDrives'),
          pageSize: any(named: 'pageSize'),
          $fields: any(named: r'$fields'),
        )).thenAnswer((_) async => drive.PermissionList(permissions: [
          drive.Permission(
            emailAddress: 'test@example.com',
            role: 'writer',
            type: 'user',
          ),
        ]));
      }

      await tester.pumpWidget(createTestApp(const UserAccessManagementScreen(
        email: 'test@example.com',
        spreadsheetId: 'sheet_123',
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('View Details'));
      await tester.pumpAndSettle();

      // Navigate to DASHBOARD tab
      // The TabBar might be scrollable, so we might need to drag it
      await tester.drag(find.byType(TabBar), const Offset(-600, 0));
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('DASHBOARD'));
      await tester.pumpAndSettle();

      // 1. Verify initial card
      expect(find.text('Total Revenue'), findsOneWidget);

      // 2. Add New Card
      final addCardBtn = find.text('Add Card');
      await tester.dragUntilVisible(
        addCardBtn,
        find.byType(ListView).hitTestable(),
        const Offset(0, -300),
      );
      await tester.tap(addCardBtn);
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Card Label'), 'New Users');
      await tester.enterText(find.widgetWithText(TextField, 'Formula'), '=COUNT(Users!A:A)');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('New Users'), findsOneWidget);

      // 3. Edit existing card
      final editIcon = find.descendant(
        of: find.ancestor(of: find.text('Total Revenue'), matching: find.byType(Card)),
        matching: find.byIcon(Icons.edit_rounded),
      ).first;
      await tester.dragUntilVisible(
        editIcon,
        find.byType(ListView).hitTestable(),
        const Offset(0, -300),
      );
      await tester.tap(editIcon);
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Card Label'), 'Gross Revenue');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Gross Revenue'), findsOneWidget);
      expect(find.text('Total Revenue'), findsNothing);

      // 4. Delete a card
      final deleteIcon = find.descendant(
        of: find.ancestor(of: find.text('New Users'), matching: find.byType(Card)),
        matching: find.byIcon(Icons.delete_outline),
      ).first;
      await tester.dragUntilVisible(
        deleteIcon,
        find.byType(ListView).hitTestable(),
        const Offset(0, -300),
      );
      await tester.tap(deleteIcon);
      await tester.pumpAndSettle();

      expect(find.text('New Users'), findsNothing);

      // 5. Save DASHBOARD
      final saveBtn = find.text('SAVE DASHBOARD');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.text('Dashboard updated successfully'), findsOneWidget);
      verify(() => mockDriveService.writeDashboardById('dash_id', any())).called(1);
    });

    testWidgets('Comprehensive Settings Tab Management', (tester) async {
      // Setup row and settings mock
      // Mock for UserAccessManagementScreen to list modules
      when(() => mockValues.get('sheet_123', 'modules!A1:H1000'))
          .thenAnswer((_) async => sheets.ValueRange(values: [
                ['ID', 'Name', 'Dash', 'Set', 'Tabs', 'Files', 'Type', 'Status'], // Header
                ['crm_folder', 'CRM Module', 'dash_id', 'set_id', 'tabs_id', 'files_id', 'erp', 'activated'],
              ]));

      // Mock for individual tab loads (which use specific rows)
      when(() => mockValues.get('sheet_123', 'modules!A2:H2'))
          .thenAnswer((_) async => sheets.ValueRange(values: [
                ['crm_folder', 'CRM Module', 'dash_id', 'set_id', 'tabs_id', 'files_id', 'erp', 'activated'],
              ]));

      // Mock permissions for the CRM module files
      final mockPerms = mockDriveService.driveApi.permissions as MockPermissionsResource;
      for (final id in ['crm_folder', 'dash_id', 'set_id', 'tabs_id', 'files_id']) {
        when(() => mockPerms.list(
          id,
          supportsAllDrives: any(named: 'supportsAllDrives'),
          pageSize: any(named: 'pageSize'),
          $fields: any(named: r'$fields'),
        )).thenAnswer((_) async => drive.PermissionList(permissions: [
          drive.Permission(
            emailAddress: 'test@example.com',
            role: 'writer',
            type: 'user',
          ),
        ]));
      }

      final initialSettings = {
        'tax_rate': {
          'label': 'Tax Rate',
          'type': 'number',
          'help': 'Enter the tax rate',
          'value': 0.1
        },
        'company_name': {
          'label': 'Company Name',
          'type': 'text',
          'value': 'Original Corp'
        }
      };

      when(() => mockDriveService.readSettingsById('set_id'))
          .thenAnswer((_) async => initialSettings);

      when(() => mockDriveService.writeSettingsById('set_id', any()))
          .thenAnswer((_) async => {});

      await tester.pumpWidget(createTestApp(const UserAccessManagementScreen(
        email: 'test@example.com',
        spreadsheetId: 'sheet_123',
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('View Details'));
      await tester.pumpAndSettle();

      // Navigate to SETTINGS tab
      // The tab might be off-screen, scroll the TabBar
      await tester.drag(find.byType(TabBar), const Offset(-400, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SETTINGS'));
      await tester.pumpAndSettle();

      // 1. Verify existing settings
      expect(find.text('Tax Rate'), findsOneWidget);
      expect(find.text('Company Name'), findsOneWidget);

      // 2. Add New Setting
      final addSettingBtn = find.text('Add New Setting');
      await tester.dragUntilVisible(
        addSettingBtn,
        find.byType(ListView).hitTestable(),
        const Offset(0, -300),
      );
      await tester.tap(addSettingBtn);
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Label'), 'Theme Color');
      await tester.enterText(find.widgetWithText(TextField, 'Setting Key (ID)'), 'theme_color');
      // Default type is text, let's keep it or change it
      await tester.tap(find.text('TEXT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('NUMBER').last);
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Theme Color'), findsOneWidget);

      // 3. Edit Setting Value (Change Company Name)
      // For text type, it's a TextFormField. 
      // Tax Rate is type number, it also uses TextFormField.
      final companyNameCard = find.ancestor(
        of: find.text('Company Name'),
        matching: find.byType(Card),
      );
      await tester.dragUntilVisible(
        companyNameCard,
        find.byType(ListView).hitTestable(),
        const Offset(0, -200),
      );
      // Move it down slightly from the top to avoid TabBar overlap
      await tester.drag(find.byType(ListView).hitTestable(), const Offset(0, 100));
      await tester.pumpAndSettle();

      final textField = find.descendant(of: companyNameCard, matching: find.byType(TextFormField));
      await tester.enterText(textField, 'New Corp');
      await tester.pumpAndSettle();

      // 4. Delete a setting
      final taxRateCard = find.ancestor(of: find.text('Tax Rate'), matching: find.byType(Card));
      await tester.dragUntilVisible(
        taxRateCard,
        find.byType(ListView).hitTestable(),
        const Offset(0, -200),
      );
      // Move it slightly to the middle to avoid TabBar at top or Save button at bottom
      await tester.drag(find.byType(ListView).hitTestable(), const Offset(0, -50));
      await tester.pumpAndSettle();

      final deleteIcon = find.descendant(
        of: taxRateCard,
        matching: find.byIcon(Icons.delete_outline_rounded),
      ).first;
      
      await tester.tap(deleteIcon);
      await tester.pumpAndSettle();
      
      final deleteBtn = find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete'));
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(find.text('Tax Rate'), findsNothing);

      // 5. Final Save
      final saveBtn = find.text('SAVE SETTINGS');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.text('Settings updated successfully'), findsOneWidget);
      verify(() => mockDriveService.writeSettingsById('set_id', any())).called(1);
    });
  });
}
