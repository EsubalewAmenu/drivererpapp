import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;

import 'package:drivererpapp/services/drive/drive_company_mixin.dart';

import 'package:mocktail/mocktail.dart';

class BatchUpdateSpreadsheetRequestFake extends Fake implements sheets.BatchUpdateSpreadsheetRequest {}
class BatchUpdateValuesRequestFake extends Fake implements sheets.BatchUpdateValuesRequest {}

class MockSheetsApi extends Mock implements sheets.SheetsApi { }
class MockSpreadsheetsResource extends Mock implements sheets.SpreadsheetsResource {}
class MockValuesResource extends Mock implements sheets.SpreadsheetsValuesResource {}

class MockDriveApi extends Mock implements drive.DriveApi {}
class MockFilesResource extends Mock implements drive.FilesResource {}
class MockPermissionsResource extends Mock implements drive.PermissionsResource {}

class DummyDriveCompany with DriveCompanyMixin {
  @override
  final drive.DriveApi driveApi;

  @override
  final sheets.SheetsApi sheetsApi;

  DummyDriveCompany(this.driveApi, this.sheetsApi);

  @override
  Future<String?> getFileId(String folderId, String fileName) async => null;

  @override
  Future<String> getOrCreateSubFolder(String parentId, String folderName) async => 'ua_folder';

  @override
  Future<String?> checkRootFolder() async => 'root';

  @override
  Future<T> retryOp<T>(Future<T> Function() action, {int retries = 3}) async => action();

  @override
  Future<String> uploadFile(String folderId, String fileName, List<int> bytes, {String? mimeType}) async => 'uploaded_$fileName';

  @override
  Future<void> deleteFile(String fileId) async {}

  @override
  Future<void> upsertCompanyUserAccess(String rootFolderId, String companyFolderId, String userEmail, String spreadsheetId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(sheets.Spreadsheet());
    registerFallbackValue(sheets.ValueRange());
    registerFallbackValue(drive.File());
    registerFallbackValue(drive.Permission());
    registerFallbackValue(BatchUpdateSpreadsheetRequestFake());
    registerFallbackValue(BatchUpdateValuesRequestFake());
  });

  group('DriveCompanyMixin', () {
    test('ensureCompanyRegistry creates new registry when missing', () async {
      final mockSheetsApi = MockSheetsApi();
      final mockSpreadsheets = MockSpreadsheetsResource();
      final mockValues = MockValuesResource();

      final mockDriveApi = MockDriveApi();
      final mockFiles = MockFilesResource();
      final mockPermissions = MockPermissionsResource();

      // Wire up nested resources on the actual mock instances
      when(() => mockSheetsApi.spreadsheets).thenReturn(mockSpreadsheets);
      when(() => mockSpreadsheets.values).thenReturn(mockValues);
      when(() => mockValues.batchUpdate(any(), any())).thenAnswer((_) async => sheets.BatchUpdateValuesResponse());
      when(() => mockSpreadsheets.batchUpdate(any(), any())).thenAnswer((_) async => sheets.BatchUpdateSpreadsheetResponse());

      when(() => mockDriveApi.files).thenReturn(mockFiles);
      when(() => mockDriveApi.permissions).thenReturn(mockPermissions);
      when(() => mockFiles.create(any(), supportsAllDrives: any(named: 'supportsAllDrives'))).thenAnswer((_) async => drive.File()..id = 'fake_sheet_id');

      final t = DummyDriveCompany(mockDriveApi, mockSheetsApi);

      final id = await t.ensureCompanyRegistry('root123');

      expect(id, equals('fake_sheet_id'));
      verify(() => mockFiles.create(any(), supportsAllDrives: true)).called(1);
      verify(() => mockSpreadsheets.batchUpdate(any(), 'fake_sheet_id')).called(1);
      verify(() => mockValues.batchUpdate(any(), 'fake_sheet_id')).called(1);
    });
  });
}
