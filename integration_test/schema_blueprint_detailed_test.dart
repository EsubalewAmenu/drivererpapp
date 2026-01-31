import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/providers/theme_provider.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/screens/schema_editor_screen.dart';
import 'helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthService mockAuthService;
  late MockDriveService mockDriveService;

  setUpAll(() {
    initTestEnvironment();
  });

  setUp(() {
    final mocks = createTestMocks();
    mockAuthService = mocks.auth;
    mockDriveService = mocks.drive;
    when(() => mockAuthService.isAuthenticated).thenReturn(true);
    when(() => mockAuthService.currentUser).thenReturn(null);
    when(() => mockDriveService.getFileModifiedTime(any())).thenAnswer((_) async => DateTime.now());
    when(() => mockDriveService.getOrCreateSubFolder(any(), any())).thenAnswer((_) async => 'folder_id');
    when(() => mockDriveService.getFileId(any(), any())).thenAnswer((_) async => 'file_id');
  });

  testWidgets('Schema Blueprint Editor: Detailed Flow (Tabs, Columns, KPIs)', (tester) async {
    debugPrint('TEST: Starting schema_blueprint_detailed_test');
    
    final moduleSchema = ModuleSchema(
      id: 'mod1',
      name: 'Lab',
      icon: 'science',
      primaryColor: '#F59E0B',
      version: '1.0.0',
      tabs: [
        TabConfig(id: 't1', label: 'T1', columns: []),
        TabConfig(id: 't2', label: 'T2', columns: []),
      ],
      dashboard: DashboardConfig(cards: []),
      settings: {},
    );

    final workspaceProvider = WorkspaceProvider();
    final driveProvider = TestDriveProvider(mockDriveService);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaceProvider),
        ChangeNotifierProvider<DriveProvider>.value(value: driveProvider),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<SchemaProvider>(create: (_) => SchemaProvider(driveService: mockDriveService, userEmail: 'user@example.com')),
      ],
      child: MaterialApp(
        home: SchemaEditorScreen(
          module: moduleSchema,
          // Provide explicit per-user sheet ids so save can proceed and pop
          settingsSheetId: 's_mod1',
          dashboardSheetId: 'd_mod1',
          tabsSheetId: 't_mod1',
        ),
        debugShowCheckedModeBanner: false,
      ),
    ));

    await tester.pumpAndSettle();

    // 1. Add a Tab
    final addTabButton = find.text('Add New Tab');
    await tester.ensureVisible(addTabButton);
    await tester.pumpAndSettle(); // Allow scroll to settle
    await tester.tap(addTabButton);
    await tester.pumpAndSettle();
    
    await tester.enterText(find.widgetWithText(TextField, 'Tab Name'), 'Observations');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    
    expect(find.text('Observations'), findsOneWidget);

    // 2. Add a Column to the Tab
    final observationsTab = find.text('Observations');
    await tester.ensureVisible(observationsTab);
    await tester.pumpAndSettle();
    await tester.tap(observationsTab);
    await tester.pumpAndSettle();
    
    await tester.tap(find.text('Add Column'));
    await tester.pumpAndSettle();
    
    await tester.enterText(find.widgetWithText(TextField, 'Column Name'), 'Notes');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('TEXT'), findsOneWidget);

    // 3. Add a KPI Card
    final dashboardTab = find.text('DASHBOARD');
    await tester.ensureVisible(dashboardTab);
    await tester.pumpAndSettle();
    await tester.tap(dashboardTab);
    await tester.pumpAndSettle();
    
    final addCardButton = find.text('Add Card');
    await tester.ensureVisible(addCardButton);
    await tester.pumpAndSettle();
    await tester.tap(addCardButton);
    await tester.pumpAndSettle();
    
    // Select Template
    final numberCard = find.text('Number');
    await tester.ensureVisible(numberCard);
    await tester.pumpAndSettle();
    await tester.tap(numberCard);
    await tester.pumpAndSettle();

    // Toggle to Custom Mode
    await tester.tap(find.text('Use Formula Builder')); 
    await tester.pumpAndSettle();

    // Edit Fields
    await tester.enterText(find.byType(TextField).at(0), 'Total Items');
    await tester.enterText(find.byType(TextField).at(1), '=SUM(A:A)');
    
    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();
    
    expect(find.text('Total Items'), findsAtLeastNWidgets(1));

    // 4. Save and Activate
    // Ensure write methods used by SchemaService when direct ids provided resolve
    when(() => mockDriveService.writeSettingsById(any(), any())).thenAnswer((_) async {});
    when(() => mockDriveService.writeDashboardById(any(), any())).thenAnswer((_) async {});
    when(() => mockDriveService.writeTabsById(any(), any())).thenAnswer((_) async {});
    await tester.tap(find.byType(TextButton).first); // SAVE/ACTIVATE
    await tester.pumpAndSettle();

    // Success snackbar and pop
    expect(find.byType(SchemaEditorScreen), findsNothing);
  });
}
