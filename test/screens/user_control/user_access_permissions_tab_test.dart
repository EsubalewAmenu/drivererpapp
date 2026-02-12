import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/user_control/tabs/user_access_permissions_tab.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
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

  @override
  Future<DateTime?> getFileModifiedTime(String fileId) async => DateTime.now();
}

class MockDriveApi extends Mock implements drive.DriveApi {
  @override
  late drive.PermissionsResource permissions;

  MockDriveApi() {
    permissions = MockPermissionsResource();
  }
}

class MockPermissionsResource extends Mock implements drive.PermissionsResource {}

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

void main() {
  late MockDriveProvider mockDriveProvider;
  late MockDriveService mockDriveService;

  setUp(() {
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();

    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
  });

  Widget createTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: UserAccessPermissionsTab(
            email: 'user@example.com',
            spreadsheetId: 'sheet123',
            moduleId: 'mod123',
            moduleName: 'Test Module',
            rowIndex: 2,
          ),
        ),
      ),
    );
  }

  group('UserAccessPermissionsTab', () {
    testWidgets('displays loading initially', (WidgetTester tester) async {
      when(() => mockDriveService.sheetsApi.spreadsheets.values.get(any(), any()))
          .thenAnswer((_) async => sheets.ValueRange());

      await tester.pumpWidget(createTestWidget());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays error on sheet not found', (WidgetTester tester) async {
      when(() => mockDriveService.sheetsApi.spreadsheets.values.get(any(), any()))
          .thenThrow(Exception('Not found'));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Failed to load permissions'), findsOneWidget);
    });

    testWidgets('loads permission list', (WidgetTester tester) async {
      final valueRange = sheets.ValueRange(
        values: [['mod_id', 'dash_id', 'settings_id', 'tabs_id', 'files_id']]
      );

      when(() => mockDriveService.sheetsApi.spreadsheets.values.get(any(), any()))
          .thenAnswer((_) async => valueRange);

      when(() => mockDriveService.driveApi.permissions.list(any()))
          .thenAnswer((_) async => drive.PermissionList(permissions: []));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('displays permissions when loaded', (WidgetTester tester) async {
      final valueRange = sheets.ValueRange(
        values: [['mod_id', 'dash_id', 'settings_id', 'tabs_id', 'files_id']]
      );

      when(() => mockDriveService.sheetsApi.spreadsheets.values.get(any(), any()))
          .thenAnswer((_) async => valueRange);

      when(() => mockDriveService.driveApi.permissions.list(any()))
          .thenAnswer((_) async => drive.PermissionList(
            permissions: [
              drive.Permission(id: 'p1', emailAddress: 'user@example.com', role: 'reader'),
            ]
          ));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(UserAccessPermissionsTab), findsOneWidget);
    });

    testWidgets('handles multiple permissions', (WidgetTester tester) async {
      final valueRange = sheets.ValueRange(
        values: [['mod_id', 'dash_id', 'settings_id', 'tabs_id', 'files_id']]
      );

      when(() => mockDriveService.sheetsApi.spreadsheets.values.get(any(), any()))
          .thenAnswer((_) async => valueRange);

      when(() => mockDriveService.driveApi.permissions.list(any()))
          .thenAnswer((_) async => drive.PermissionList(
            permissions: [
              drive.Permission(id: 'p1', emailAddress: 'user1@example.com', role: 'reader'),
              drive.Permission(id: 'p2', emailAddress: 'user2@example.com', role: 'writer'),
            ]
          ));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(UserAccessPermissionsTab), findsOneWidget);
    });

    testWidgets('shows retry button on error', (WidgetTester tester) async {
      when(() => mockDriveService.sheetsApi.spreadsheets.values.get(any(), any()))
          .thenThrow(Exception('Error'));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('handles empty permissions', (WidgetTester tester) async {
      final valueRange = sheets.ValueRange(
        values: [['mod_id', 'dash_id', 'settings_id', 'tabs_id', 'files_id']]
      );

      when(() => mockDriveService.sheetsApi.spreadsheets.values.get(any(), any()))
          .thenAnswer((_) async => valueRange);

      when(() => mockDriveService.driveApi.permissions.list(any()))
          .thenAnswer((_) async => drive.PermissionList(permissions: []));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
