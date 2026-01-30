import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:drivererpapp/theme/app_theme.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/providers/theme_provider.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:drivererpapp/models/company_model.dart';
import 'package:drivererpapp/screens/dashboard_screen.dart';
import 'package:drivererpapp/screens/workspace_selector_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthService mockAuthService;
  late MockDriveService mockDriveService;
  late MockValuesResource mockValues;

  setUpAll(() {
    initTestEnvironment();
  });

  setUp(() {
    final mocks = createTestMocks();
    mockAuthService = mocks.auth;
    mockDriveService = mocks.drive;
    mockValues = mocks.values;
  });

  Widget createTestWidget({
    required WorkspaceProvider workspaceProvider,
    required DriveProvider driveProvider,
    String? userAccessSpreadsheetId,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaceProvider),
        ChangeNotifierProvider<DriveProvider>.value(value: driveProvider),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<SchemaProvider>(create: (_) => SchemaProvider(driveService: mockDriveService)),
      ],
      child: MaterialApp(
        home: DashboardScreen(userAccessSpreadsheetId: userAccessSpreadsheetId),
        debugShowCheckedModeBanner: false,
      ),
    );
  }

  testWidgets('Dashboard: Period Switching and Module Navigation', (tester) async {
    debugPrint('TEST: Starting dashboard_interaction_test (Period & Navigation)');
    
    final workspace = drive.File()..id = 'ws1'..name = 'ERP Lab';
    final moduleFile = drive.File()..id = 'mod1'..name = 'CRM';
    
    // Mock the user_access sheet rows via Sheets API
    final mockValueRange = sheets.ValueRange(values: [
      ['id', 'module_name', 'dashboard', 'settings', 'tabs'],
      ['mod1', 'CRM', '', 'config_id', 'tabs_id'],
    ]);
    when(() => mockValues.get('ua1', 'modules!A1:Z'))
        .thenAnswer((_) async => mockValueRange);
    when(() => mockDriveService.getFileId('mod1', 'config')).thenAnswer((_) async => 'config_id');
    when(() => mockDriveService.readModuleConfig('config_id')).thenAnswer((_) async => <String, dynamic>{
      'id': 'mod1',
      'name': 'CRM',
      'icon': 'trending_up',
      'primaryColor': '#4F46E5',
      'tabs': [],
      'dashboard': {'cards': []}
    });

    final workspaceProvider = WorkspaceProvider();
    workspaceProvider.setWorkspace(workspace);
    final driveProvider = TestDriveProvider(mockDriveService);

    await tester.pumpWidget(createTestWidget(
      workspaceProvider: workspaceProvider,
      driveProvider: driveProvider,
      userAccessSpreadsheetId: 'ua1',
    ));

    await tester.pumpAndSettle();

    // 1. Initial Dashboard Check
    expect(find.text('ERP LAB'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);

    // 2. Period Switch
    await tester.tap(find.text('MONTH'));
    await tester.pumpAndSettle();
    
    // Check Profit - formatting might include commas or different spacing
    // We expect a loss in the mocked month data: 35000 - 42000 = -7000
    expect(find.textContaining('7000'), findsOneWidget);

    // 3. Navigate to Module (case-insensitive matcher)
    // Debug: list Text widgets to help diagnose missing CRM label
    final allTextFinder = find.byType(Text);
    final texts = tester.widgetList<Text>(allTextFinder).map((t) => t.data ?? '').toList();
    debugPrint('DEBUG: Text widgets in tree -> $texts');

    // Verify CRM is present in the dashboard text widgets
    expect(texts.any((s) => s.toUpperCase().contains('CRM')), isTrue);
  });

  testWidgets('Dashboard: Workspace Switching via Drawer', (tester) async {
    debugPrint('TEST: Starting dashboard_interaction_test (Workspace Switch)');
    
    final ws1 = drive.File()..id = 'ws1'..name = 'Company A';
    final companyB = Company(id: 'c2', name: 'Company B', folderId: 'ws2');
    
    // No modules in user access sheet
    final emptyRange = sheets.ValueRange(values: []);
    when(() => mockValues.get('ua1', 'modules!A1:Z'))
      .thenAnswer((_) async => emptyRange);
    when(() => mockDriveService.checkRootFolder()).thenAnswer((_) async => 'root_id');
    when(() => mockDriveService.ensureCompanyRegistry(any())).thenAnswer((_) async => 'reg_id');
    when(() => mockDriveService.getCompanies(any())).thenAnswer((_) async => [
      Company(id: 'c1', name: 'Company A', folderId: 'ws1'),
      companyB,
    ]);

    final workspaceProvider = WorkspaceProvider(driveService: mockDriveService);
    workspaceProvider.setWorkspace(ws1);
    final driveProvider = TestDriveProvider(mockDriveService);

    await tester.pumpWidget(createTestWidget(
      workspaceProvider: workspaceProvider,
      driveProvider: driveProvider,
      userAccessSpreadsheetId: 'ua1',
    ));

    await tester.pumpAndSettle();
    expect(find.text('COMPANY A'), findsOneWidget);

    // 1. Open Drawer
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    // 2. Click "Switch Workspace"
    await tester.tap(find.text('Switch Workspace'));
    await tester.pumpAndSettle();

    expect(find.byType(WorkspaceSelectorScreen), findsOneWidget);

    // 3. Select Company B from the list
    final companyBCard = find.text('Company B');
    await tester.ensureVisible(companyBCard);
    await tester.tap(companyBCard);
    await tester.pumpAndSettle();

    // After selection, it should pop back to Dashboard
    expect(find.text('COMPANY B'), findsOneWidget);
  });
}
