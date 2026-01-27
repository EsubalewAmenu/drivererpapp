import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/theme/app_theme.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/providers/theme_provider.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:drivererpapp/screens/dashboard_screen.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthService extends Mock implements AuthService {}
class MockDriveService extends Mock implements DriveService {}
class MockSheetsApi extends Mock implements sheets.SheetsApi {}
class MockSpreadsheetsResource extends Mock implements sheets.SpreadsheetsResource {}
class MockValuesResource extends Mock implements sheets.SpreadsheetsValuesResource {}

class TestDriveProvider extends DriveProvider {
  final DriveService? mockService;
  TestDriveProvider(this.mockService);
  @override
  DriveService? get driveService => mockService;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthService mockAuthService;
  late MockDriveService mockDriveService;

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    AppTheme.useGoogleFonts = false;
  });

  setUp(() {
    mockAuthService = MockAuthService();
    mockDriveService = MockDriveService();
    final mockSheetsApi = MockSheetsApi();
    final mockSpreadsheets = MockSpreadsheetsResource();
    final mockValues = MockValuesResource();
    when(() => mockSheetsApi.spreadsheets).thenReturn(mockSpreadsheets);
    when(() => mockSpreadsheets.values).thenReturn(mockValues);
    when(() => mockDriveService.sheetsApi).thenReturn(mockSheetsApi);

    when(() => mockAuthService.isAuthenticated).thenReturn(true);
    when(() => mockAuthService.currentUser).thenReturn(null);
    when(() => mockDriveService.getFileModifiedTime(any())).thenAnswer((_) async => DateTime.now());
    final emptyRange = sheets.ValueRange(values: []);
    when(() => mockDriveService.sheetsApi.spreadsheets.values.get('ua1', 'modules!A1:Z'))
      .thenAnswer((_) async => emptyRange);
    when(() => mockDriveService.getFileId(any(), any())).thenAnswer((_) async => null);
    when(() => mockDriveService.checkRootFolder()).thenAnswer((_) async => 'root_id');
    when(() => mockDriveService.createRootFolder()).thenAnswer((_) async => 'root_id');
  });

  Widget createTestWidget({
    required WorkspaceProvider workspaceProvider,
    required DriveProvider driveProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaceProvider),
        ChangeNotifierProvider<DriveProvider>.value(value: driveProvider),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<SchemaProvider>(create: (_) => SchemaProvider(driveService: mockDriveService)),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const DashboardScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }

  testWidgets('Navigation and Theme Integration Test', (tester) async {
    final workspaceFile = drive.File()
      ..id = 'ws1'
      ..name = 'ERP Lab';
    final workspaceProvider = WorkspaceProvider();
    workspaceProvider.setWorkspace(workspaceFile);
    
    final driveProvider = TestDriveProvider(mockDriveService);

    await tester.pumpWidget(createTestWidget(
      workspaceProvider: workspaceProvider,
      driveProvider: driveProvider,
    ));
    await tester.pumpAndSettle();

    // 1. Verify we are on Dashboard
    expect(find.text('ERP LAB'), findsOneWidget);

    // 2. Navigate to Settings
    final settingsIcon = find.byIcon(Icons.settings_rounded);
    await tester.tap(settingsIcon);
    await tester.pumpAndSettle();
    expect(find.text('SETTINGS'), findsOneWidget);

    // 3. Toggle Theme
    final themeToggle = find.byType(Switch);
    await tester.tap(themeToggle);
    await tester.pumpAndSettle();

    // Go back
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    // 4. Open Drawer and Switch Workspace
    // On some devices, tapping by icon Icons.menu might be tricky if there are multiple.
    // We can also use ScaffoldState to open it or find the Open Drawer button by tooltip
    final scaffoldFinder = find.byType(Scaffold);
    expect(scaffoldFinder, findsAtLeast(1));
    
    // Try to open drawer
    await tester.tap(find.byIcon(Icons.menu).first);
    await tester.pumpAndSettle();

    // Verify drawer content
    expect(find.text('DRIVE ERP'), findsOneWidget);
    
    final switchWorkspaceFinder = find.text('Switch Workspace');
    expect(switchWorkspaceFinder, findsOneWidget);
    
    await tester.tap(switchWorkspaceFinder);
    await tester.pumpAndSettle();

    expect(find.text('AVAILABLE ENVIRONMENTS'), findsOneWidget);
  });
}

