import 'package:mocktail/mocktail.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drivererpapp/theme/app_theme.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:drivererpapp/providers/drive_provider.dart';

// Common mock types used across integration tests
class MockAuthService extends Mock implements AuthService {}
class MockDriveService extends Mock implements DriveService {}
class MockDriveApi extends Mock implements drive.DriveApi {}
class MockSheetsApi extends Mock implements sheets.SheetsApi {}
class MockSpreadsheetsResource extends Mock implements sheets.SpreadsheetsResource {}
class MockValuesResource extends Mock implements sheets.SpreadsheetsValuesResource {}

class TestMocks {
  final MockAuthService auth;
  final MockDriveService drive;
  final MockDriveApi driveApi;
  final MockSheetsApi sheetsApi;
  final MockSpreadsheetsResource spreadsheets;
  final MockValuesResource values;

  TestMocks({
    required this.auth,
    required this.drive,
    required this.driveApi,
    required this.sheetsApi,
    required this.spreadsheets,
    required this.values,
  });

  DriveService get driveService => drive;
}

class TestDriveProvider extends DriveProvider {
  final DriveService? _mockService;
  TestDriveProvider(this._mockService);
  @override
  DriveService? get driveService => _mockService;
}

/// Initialize the test environment. Call this in `setUpAll` of tests.
void initTestEnvironment() {
  SharedPreferences.setMockInitialValues({});
  AppTheme.useGoogleFonts = false;
  registerFallbackValue(drive.File());
}

/// Create and wire common mocks. Tests can still override specific behaviors.
TestMocks createTestMocks() {
  final auth = MockAuthService();
  final drive = MockDriveService();
  final driveApi = MockDriveApi();
  final sheetsApi = MockSheetsApi();
  final spreadsheets = MockSpreadsheetsResource();
  final values = MockValuesResource();

  when(() => sheetsApi.spreadsheets).thenReturn(spreadsheets);
  when(() => spreadsheets.values).thenReturn(values);
  when(() => drive.sheetsApi).thenReturn(sheetsApi);
  when(() => drive.driveApi).thenReturn(driveApi);

  // Default auth/driveservice behaviors that most tests expect
  try {
    when(() => auth.isAuthenticated).thenReturn(true);
    when(() => auth.currentUser).thenReturn(null);
  } catch (_) {}

  try {
    when(() => drive.getFileModifiedTime(any())).thenAnswer((_) async => DateTime.now());
    when(() => drive.fetchRecords(
      any(), any(), any(),
      offset: any(named: 'offset'),
      limit: any(named: 'limit'),
      fetchSubTables: any(named: 'fetchSubTables'),
      descending: any(named: 'descending'),
      searchQuery: any(named: 'searchQuery'),
      quickFilter: any(named: 'quickFilter'),
    )).thenAnswer((_) async => <Map<String, dynamic>>[]);
    when(() => drive.fetchRecordsBySpreadsheetId(
      any(), any(),
      offset: any(named: 'offset'),
      limit: any(named: 'limit'),
      fetchSubTables: any(named: 'fetchSubTables'),
      descending: any(named: 'descending'),
      searchQuery: any(named: 'searchQuery'),
      quickFilter: any(named: 'quickFilter'),
    )).thenAnswer((_) async => <Map<String, dynamic>>[]);
    when(() => drive.getFileId(any(), any())).thenAnswer((_) async => null);
    when(() => drive.readSettingsById(any())).thenAnswer((_) async => <String, dynamic>{});
    when(() => drive.readDashboardById(any())).thenAnswer((_) async => <String, dynamic>{});
    when(() => drive.readTabsById(any())).thenAnswer((_) async => <Map<String, dynamic>>[]);
    when(() => drive.getOrCreateSubFolder(any(), any())).thenAnswer((_) async => 'folder_id');
    when(() => drive.updateTabFields(any(), any(), any())).thenAnswer((_) async {});
      when(() => drive.updateTabField(any(), any(), any(), any())).thenAnswer((_) async {});
    when(() => drive.writeDashboardById(any(), any())).thenAnswer((_) async {});
    when(() => drive.writeTabsById(any(), any())).thenAnswer((_) async {});
  } catch (_) {}

  return TestMocks(auth: auth, drive: drive, driveApi: driveApi, sheetsApi: sheetsApi, spreadsheets: spreadsheets, values: values);
}
