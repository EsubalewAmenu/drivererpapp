import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/user_control/module_access_detail_screen.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/models/company_model.dart';
import '../../helpers/fake_billing_http_overrides.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;

class MockDriveProvider extends Mock implements DriveProvider {}

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

  MockDriveApi() {
    permissions = MockPermissionsResource();
  }
}

class MockSheetsApi extends Mock implements sheets.SheetsApi {
  @override
  late sheets.SpreadsheetsResource spreadsheets;

  MockSheetsApi() {
    spreadsheets = MockSpreadsheetsResource();
  }
}

class MockSpreadsheetsResource extends Mock implements sheets.SpreadsheetsResource {
  @override
  late sheets.SpreadsheetsValuesResource values;

  MockSpreadsheetsResource() {
    values = MockValuesResource();
  }
}

class MockValuesResource extends Mock implements sheets.SpreadsheetsValuesResource {}
class MockPermissionsResource extends Mock implements drive.PermissionsResource {}
class TestWorkspaceProvider extends WorkspaceProvider {
  TestWorkspaceProvider() : super(driveService: null);

  @override
  Company? get currentCompany =>
      Company(id: 'company1', name: 'Company', folderId: 'folder1');
}

void main() {
  late MockDriveProvider mockDriveProvider;
  late MockDriveService mockDriveService;
  late TestWorkspaceProvider testWorkspaceProvider;
  late MockPermissionsResource mockPermissionsResource;
  late MockValuesResource mockValuesResource;

  setUp(() {
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();
    testWorkspaceProvider = TestWorkspaceProvider();
    mockPermissionsResource = mockDriveService.driveApi.permissions as MockPermissionsResource;
    mockValuesResource = (mockDriveService.sheetsApi.spreadsheets.values as MockValuesResource);

    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);

    when(() => mockValuesResource.get(any(), any())).thenAnswer(
      (_) async => sheets.ValueRange(
        values: [
          [
            'moduleFolderId',
            'Test Module',
            'dashboardId',
            'settingsId',
            'tabsId',
            'moduleFilesId',
            'module',
            'active',
          ]
        ],
      ),
    );

    when(() => mockDriveService.readTabsById(any())).thenAnswer((_) async => []);
    when(() => mockDriveService.readDashboardById(any()))
        .thenAnswer((_) async => {'cards': []});
    when(() => mockDriveService.readSettingsById(any())).thenAnswer(
      (_) async => {
        'name': {'label': 'Name', 'type': 'text', 'value': 'Test Module'}
      },
    );

    when(
      () => mockPermissionsResource.list(
        any(),
        supportsAllDrives: any(named: 'supportsAllDrives'),
        pageSize: any(named: 'pageSize'),
        $fields: any(named: r'$fields'),
      ),
    ).thenAnswer((_) async => drive.PermissionList(permissions: []));

    when(
      () => mockPermissionsResource.list(
        any(),
        supportsAllDrives: any(named: 'supportsAllDrives'),
        $fields: any(named: r'$fields'),
      ),
    ).thenAnswer((_) async => drive.PermissionList(permissions: []));
  });

  Widget createTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: testWorkspaceProvider),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ModuleAccessDetailScreen(
            email: 'test@example.com',
            spreadsheetId: 'sheet123',
            moduleId: 'mod123',
            moduleName: 'Test Module',
            rowIndex: 2,
          ),
        ),
      ),
    );
  }

  group('ModuleAccessDetailScreen', () {
    testWidgets('displays all five tabs', (WidgetTester tester) async {
      await HttpOverrides.runZoned(
        () async {
          await tester.pumpWidget(createTestWidget());
          await tester.pumpAndSettle();
        },
        createHttpClient: (_) => FakeBillingHttpOverrides().createHttpClient(null),
      );

      expect(find.text('SUBSCRIPTION'), findsOneWidget);
      expect(find.text('PERMISSIONS'), findsOneWidget);
      expect(find.text('STRUCTURE'), findsOneWidget);
      expect(find.text('DASHBOARD'), findsOneWidget);
      expect(find.text('SETTINGS'), findsOneWidget);
    });

    testWidgets('displays correct title', (WidgetTester tester) async {
      await HttpOverrides.runZoned(
        () async {
          await tester.pumpWidget(createTestWidget());
          await tester.pumpAndSettle();
        },
        createHttpClient: (_) => FakeBillingHttpOverrides().createHttpClient(null),
      );

      expect(find.text('TEST MODULE'), findsOneWidget);
    });

    testWidgets('can switch between tabs', (WidgetTester tester) async {
      await HttpOverrides.runZoned(
        () async {
          await tester.pumpWidget(createTestWidget());
          await tester.pumpAndSettle();
        },
        createHttpClient: (_) => FakeBillingHttpOverrides().createHttpClient(null),
      );

      // Tap STRUCTURE tab
      await tester.tap(find.text('STRUCTURE'));
      await tester.pumpAndSettle();

      // Tap DASHBOARD tab
      await tester.tap(find.text('DASHBOARD'));
      await tester.pumpAndSettle();

      // Tap SETTINGS tab
      await tester.tap(find.text('SETTINGS'));
      await tester.pumpAndSettle();

      expect(find.byType(TabBar), findsOneWidget);
    });

    testWidgets('displays TabBar with correct styling', (WidgetTester tester) async {
      await HttpOverrides.runZoned(
        () async {
          await tester.pumpWidget(createTestWidget());
          await tester.pumpAndSettle();
        },
        createHttpClient: (_) => FakeBillingHttpOverrides().createHttpClient(null),
      );

      final tabBar = find.byType(TabBar);
      expect(tabBar, findsOneWidget);

      // Verify TabBar has 5 tabs
      final tabBarWidget = tester.widget<TabBar>(tabBar);
      expect(tabBarWidget.tabs.length, 5);
    });

    testWidgets('passes correct parameters to tabs', (WidgetTester tester) async {
      await HttpOverrides.runZoned(
        () async {
          await tester.pumpWidget(createTestWidget());
          await tester.pumpAndSettle();
        },
        createHttpClient: (_) => FakeBillingHttpOverrides().createHttpClient(null),
      );

      // We can verify the AppBar title contains the module name
      expect(find.text('TEST MODULE'), findsWidgets);
    });

    testWidgets('AppBar displays with correct styling', (WidgetTester tester) async {
      await HttpOverrides.runZoned(
        () async {
          await tester.pumpWidget(createTestWidget());
          await tester.pumpAndSettle();
        },
        createHttpClient: (_) => FakeBillingHttpOverrides().createHttpClient(null),
      );

      final appBar = find.byType(AppBar);
      expect(appBar, findsOneWidget);

      final appBarWidget = tester.widget<AppBar>(appBar);
      expect(appBarWidget.centerTitle, true);
    });
  });
}
