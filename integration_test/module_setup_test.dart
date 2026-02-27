import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:drivererpapp/models/company_model.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/providers/theme_provider.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:drivererpapp/screens/dashboard_screen.dart';
import 'helpers/test_helpers.dart';

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthService mockAuthService;
  late MockDriveService mockDriveService;
  late MockValuesResource mockValues;
  late MockGoogleSignInAccount mockUser;

  setUpAll(() {
    initTestEnvironment();
  });

  setUp(() {
    final mocks = createTestMocks();
    mockAuthService = mocks.auth;
    mockDriveService = mocks.drive;
    mockValues = mocks.values;
    mockUser = MockGoogleSignInAccount();

    when(() => mockUser.email).thenReturn('integration@example.com');
    when(() => mockUser.displayName).thenReturn('Integration User');
    when(() => mockUser.photoUrl).thenReturn(null);
    when(() => mockAuthService.currentUser).thenReturn(mockUser);
  });

  testWidgets('Module Activation and Blueprint Editing Flow', (tester) async {
    debugPrint('TEST: Starting module_setup_test flow');
    final workspace = drive.File()..id = 'ws1'..name = 'Test Workspace';
    
    // Initial state: no modules installed
    final emptyRange = sheets.ValueRange(values: []);
    when(() => mockValues.get('ua1', 'modules!A1:Z'))
      .thenAnswer((_) async => emptyRange);
    
    when(() => mockDriveService.ensureCompanyRegistry(any()))
        .thenAnswer((_) async => 'companies_sheet_id');
    when(() => mockDriveService.getCompanies(any())).thenAnswer(
      (_) async => [
        Company(id: 'c1', name: 'Test Workspace', folderId: 'ws1', role: 'Owner')
      ],
    );

    final workspaceProvider = WorkspaceProvider(driveService: mockDriveService);
    workspaceProvider.setWorkspace(workspace);
    await workspaceProvider.loadCompanies('root123');
    // Pre-seed the last user_access spreadsheet id so Dashboard builds with installed modules
    await workspaceProvider.saveUserAccessSpreadsheetId('ua1');

    final driveProvider = TestDriveProvider(mockDriveService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
          ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaceProvider),
          ChangeNotifierProvider<DriveProvider>.value(value: driveProvider),
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<SchemaProvider>(create: (_) => SchemaProvider(driveService: mockDriveService)),
        ],
        child: const MaterialApp(
          home: DashboardScreen(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );

    await tester.pumpAndSettle();

    debugPrint('STEP 1: Checking for "No modules installed"');
    // 1. Verify we are on Dashboard and see "No modules installed"
    expect(find.text('No modules installed.\nVisit the Marketplace to expand.'), findsOneWidget);

    debugPrint('STEP 2: Selecting module from Marketplace');
    // 2. Select a module from Catalog (Marketplace)
    // Expansion Module "CRM" or "Inventory"
    final inventoryMarketplaceFinder = find.text('Inventory').last;
    await tester.scrollUntilVisible(inventoryMarketplaceFinder, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(inventoryMarketplaceFinder);
    await tester.pumpAndSettle();

    debugPrint('STEP 3: Verifying Module Details');
    // 3. Verify Module Details
    expect(find.text('INVENTORY'), findsOneWidget);
    expect(find.text('KEY BENEFITS'), findsOneWidget);

    debugPrint('STEP 4: Activating Module');
    // 4. Activate Module
    when(() => mockDriveService.createWorkspace(any(), any())).thenAnswer((_) async {
      // After creating the workspace, update the user_access sheet mock
      // We provide the IDs immediately to avoid refresh timing issues in the test
      final installedRange = sheets.ValueRange(values: [
        ['id', 'module_name', 'dashboard', 'settings', 'tabs'],
        ['new_mod_id', 'Inventory', 'dash_id', 'config_id', 'tabs_id']
      ]);
      when(() => mockValues.get('ua1', 'modules!A1:Z'))
          .thenAnswer((_) async => installedRange);
      return drive.File()..id = 'new_mod_id';
    });
    // Ensure createModuleConfig used during activation returns an id map
    when(() => mockDriveService.createModuleConfig(any(), any(), any()))
      .thenAnswer((_) async => {'settings': 'created_cfg_id', 'dashboard': 'created_dash_id', 'tabs': 'created_tabs_id'});
    // Ensure checkRootFolder resolves
    when(() => mockDriveService.checkRootFolder()).thenAnswer((_) async => 'root_folder_id');
    // Ensure config folder creation returns an id (async)
    when(() => mockDriveService.getOrCreateSubFolder('new_mod_id', 'config'))
        .thenAnswer((_) async => 'new_mod_config_folder');
    // Seed saveRecordBySpreadsheetId calls should resolve as Future<void>
    when(() => mockDriveService.saveRecordBySpreadsheetId(any(), any(), any()))
        .thenAnswer((_) async {});
    // After seeding, getFileId for tab spreadsheets should return a non-null id
    when(() => mockDriveService.getFileId('new_mod_id', any()))
        .thenAnswer((inv) async {
      return '${inv.positionalArguments[1]}_sheet_id';
    });
    // Provide defaults for user access helpers in case activation attempts them
    when(() => mockDriveService.upsertUserAccessModule(any(), any(), any(), any(), any(), any(), any()))
        .thenAnswer((_) async {});
    when(() => mockDriveService.setUserAccessModuleStatus(any(), any(), any()))
        .thenAnswer((_) async {});
    
    await tester.tap(find.text('ACTIVATE'));
    await tester.pumpAndSettle();

    final subscriptionTitle = find.textContaining('INVENTORY SUBSCRIPTION');
    if (subscriptionTitle.evaluate().isNotEmpty) {
      expect(subscriptionTitle, findsOneWidget);
      expect(find.text('Subscribe'), findsOneWidget);
      expect(find.textContaining('No subscription found'), findsOneWidget);
      return;
    }
    
    // Wait for SnackBar to disappear as it blocks taps in CI (800x600)
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    debugPrint('Navigated back to Dashboard. Checking for core module...');
    // Ensure workspace provider knows the user_access spreadsheet id so dashboard shows installed modules
    await workspaceProvider.saveUserAccessSpreadsheetId('ua1');
    await tester.pumpAndSettle();

    // 5. Open the module to load its config
    when(() => mockDriveService.getFileId('new_mod_id', 'config')).thenAnswer((_) async => null);
    when(() => mockDriveService.readSettingsById(any())).thenAnswer((_) async => <String, dynamic>{});
    when(() => mockDriveService.readDashboardById(any())).thenAnswer((_) async => <String, dynamic>{'cards': <dynamic>[]});
    when(() => mockDriveService.readTabsById(any())).thenAnswer((_) async => <Map<String, dynamic>>[]);

    // Provide generic mocks for the new granular read methods
    when(() => mockDriveService.readSettingsById('config_id')).thenAnswer((_) async => <String, dynamic>{
      'id': {'label': 'ID', 'type': 'text', 'value': 'new_mod_id'},
      'name': {'label': 'Name', 'type': 'text', 'value': 'Inventory'},
      'icon': {'label': 'Icon', 'type': 'text', 'value': 'inventory'},
      'primaryColor': {'label': 'Color', 'type': 'text', 'value': '#3B82F6'},
      'version': {'label': 'Version', 'type': 'text', 'value': '1.0.0'},
    });
    when(() => mockDriveService.readTabsById(any())).thenAnswer((_) async => <Map<String, dynamic>>[
       {'id': 't1', 'label': 'Stock Adjustment', 'columns': []}
    ]);

    // Force Dashboard refresh with a fresh workspace instance
    workspaceProvider.setWorkspace(drive.File()..id = 'ws1'..name = 'Test Workspace');
    await tester.pumpAndSettle();

    debugPrint('STEP 8b: Tapping newly activated module');
    // Now open the module from Dashboard to see the tabs
    final inventoryCard = find.text('Inventory');
    expect(inventoryCard, findsAtLeast(1));
    await tester.dragUntilVisible(
      inventoryCard.first,
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );
    await tester.tap(inventoryCard.first);
    await tester.pumpAndSettle();

    // Should be back in ModuleScreen, showing the tabs.
    // Inventory asset has "Stock Adjustment" tab (or our mocked 'Stock Adjustment' tab).
    await tester.pump(const Duration(milliseconds: 1500));
    expect(
      find.byWidgetPredicate((w) {
        if (w is Text && w.data != null) {
          return w.data!.toUpperCase().contains('STOCK ADJUSTMENT');
        }
        return false;
      }),
      findsOneWidget,
    );
  });
}

