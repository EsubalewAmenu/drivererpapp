import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:flutter/foundation.dart';

import 'package:drivererpapp/services/drive/drive_company_mixin.dart';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:mocktail/mocktail.dart';
import 'package:drivererpapp/services/drive/drive_company_mixin.dart';

class MockSheetsApi extends Mock implements sheets.SheetsApi {}
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(sheets.Spreadsheet());
    registerFallbackValue(sheets.ValueRange());
    registerFallbackValue(drive.File());
    registerFallbackValue(drive.Permission());
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
      when(() => mockSpreadsheets.create(any())).thenAnswer((_) async => sheets.Spreadsheet()..spreadsheetId = 'fake_sheet_id');
      when(() => mockSpreadsheets.values).thenReturn(mockValues);
      when(() => mockValues.update(any(), any(), any(), valueInputOption: any(named: 'valueInputOption'))).thenAnswer((_) async => sheets.UpdateValuesResponse());

      when(() => mockDriveApi.files).thenReturn(mockFiles);
      when(() => mockDriveApi.permissions).thenReturn(mockPermissions);
      when(() => mockFiles.get(any(), $fields: any(named: r'$fields'), supportsAllDrives: any(named: 'supportsAllDrives'))).thenAnswer((_) async => drive.File()..parents = []);
      when(() => mockFiles.update(any(), any(), addParents: any(named: 'addParents'), removeParents: any(named: 'removeParents'), $fields: any(named: r'$fields'))).thenAnswer((_) async => drive.File()..id = 'moved');

      final t = DummyDriveCompany(mockDriveApi, mockSheetsApi);

      final id = await t.ensureCompanyRegistry('root123');

      expect(id, equals('fake_sheet_id'));
      verify(() => mockSpreadsheets.create(any())).called(1);
      verify(() => mockValues.update(any(), 'fake_sheet_id', 'companies!A1', valueInputOption: 'RAW')).called(1);
    });

    test('ensureUserAccessSpreadsheet creates spreadsheet when missing and initializes headers', () async {
      final mockSheetsApi = MockSheetsApi();
      final mockSpreadsheets = MockSpreadsheetsResource();
      final mockValues = MockValuesResource();

      final mockDriveApi = MockDriveApi();
      final mockFiles = MockFilesResource();
      final mockPermissions = MockPermissionsResource();

      when(() => mockSheetsApi.spreadsheets).thenReturn(mockSpreadsheets);
      when(() => mockSpreadsheets.create(any())).thenAnswer((_) async => sheets.Spreadsheet()..spreadsheetId = 'ua_new_id');
      when(() => mockSpreadsheets.values).thenReturn(mockValues);
      when(() => mockValues.update(any(), any(), any(), valueInputOption: any(named: 'valueInputOption'))).thenAnswer((_) async => sheets.UpdateValuesResponse());

      when(() => mockDriveApi.files).thenReturn(mockFiles);
      when(() => mockDriveApi.permissions).thenReturn(mockPermissions);
      when(() => mockFiles.get(any(), $fields: any(named: r'$fields'), supportsAllDrives: any(named: 'supportsAllDrives'))).thenAnswer((_) async => drive.File()..parents = ['company_parent']);
      when(() => mockFiles.update(any(), any(), addParents: any(named: 'addParents'), removeParents: any(named: 'removeParents'), $fields: any(named: r'$fields'))).thenAnswer((_) async => drive.File()..id = 'moved');

      when(() => mockValues.get(any(), any())).thenAnswer((_) async => sheets.ValueRange(values: []));

      when(() => mockValues.append(any(), any(), any(), valueInputOption: any(named: 'valueInputOption'), insertDataOption: any(named: 'insertDataOption'))).thenAnswer((_) async => sheets.AppendValuesResponse());

      final t = DummyDriveCompany(mockDriveApi, mockSheetsApi);

      final id = await t.ensureUserAccessSpreadsheet('ua_folder', 'user@example.com');

      expect(id, equals('ua_new_id'));
      verify(() => mockValues.update(any(), 'ua_new_id', 'modules!A1', valueInputOption: 'RAW')).called(1);
      verify(() => mockValues.append(any(), any(), any(), valueInputOption: any(named: 'valueInputOption'), insertDataOption: any(named: 'insertDataOption'))).called(1);
    });
  });
}
