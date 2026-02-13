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

  Widget createTestApp() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<DriveProvider>(create: (_) => TestDriveProvider(mockDriveService)),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaceProvider),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const DashboardScreen(),
        // Define routes if necessary, but Dashboard leads to UserControl via direct push in Drawer
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
      await tester.pumpWidget(createTestApp());
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
      
      // Verify the mocked user is visible
      expect(find.text('test@example.com'), findsOneWidget);
    });
  });
}
