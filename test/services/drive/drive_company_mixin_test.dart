import 'package:drivererpapp/models/company_model.dart';
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

class TestDriveCompany with DriveCompanyMixin {
  @override
  final drive.DriveApi driveApi;

  @override
  final sheets.SheetsApi sheetsApi;

  // injectable behavior for helpers
  Future<String?> Function(String, String)? onGetFileId;
  Future<String> Function(String, String)? onGetOrCreateSubFolder;
  Future<String?> Function()? onCheckRootFolder;
  Future<String> Function(String, String, List<int>, {String? mimeType})? onUploadFile;
  Future<void> Function(String)? onDeleteFile;

  TestDriveCompany(this.driveApi, this.sheetsApi);

  @override
  Future<String?> getFileId(String folderId, String fileName) {
    if (onGetFileId != null) return onGetFileId!(folderId, fileName);
    return Future.value(null);
  }

  @override
  Future<String> getOrCreateSubFolder(String parentId, String folderName) {
    if (onGetOrCreateSubFolder != null) return onGetOrCreateSubFolder!(parentId, folderName);
    return Future.value('sub_$folderName');
  }

  @override
  Future<String?> checkRootFolder() {
    if (onCheckRootFolder != null) return onCheckRootFolder!();
    return Future.value('root');
  }

  @override
  Future<T> retryOp<T>(Future<T> Function() action, {int retries = 3}) async => action();

  @override
  Future<String> uploadFile(String folderId, String fileName, List<int> bytes, {String? mimeType}) {
    if (onUploadFile != null) return onUploadFile!(folderId, fileName, bytes, mimeType: mimeType);
    return Future.value('uploaded_id');
  }

  @override
  Future<void> deleteFile(String fileId) async {
    if (onDeleteFile != null) await onDeleteFile!(fileId);
  }
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

  late MockSheetsApi mockSheetsApi;
  late MockSpreadsheetsResource mockSpreadsheets;
  late MockValuesResource mockValues;
  late MockDriveApi mockDriveApi;
  late MockFilesResource mockFiles;
  late MockPermissionsResource mockPermissions;
  late TestDriveCompany t;

  setUp(() {
    mockSheetsApi = MockSheetsApi();
    mockSpreadsheets = MockSpreadsheetsResource();
    mockValues = MockValuesResource();

    mockDriveApi = MockDriveApi();
    mockFiles = MockFilesResource();
    mockPermissions = MockPermissionsResource();

    // Wire up nested resources on the actual mock instances
    when(() => mockSheetsApi.spreadsheets).thenReturn(mockSpreadsheets);
    when(() => mockSpreadsheets.values).thenReturn(mockValues);
    when(() => mockDriveApi.files).thenReturn(mockFiles);
    when(() => mockDriveApi.permissions).thenReturn(mockPermissions);

    t = TestDriveCompany(mockDriveApi, mockSheetsApi);
  });

  group('DriveCompanyMixin', () {
    test('ensureCompanyRegistry creates new registry when missing', () async {
      when(() => mockValues.batchUpdate(any(), any())).thenAnswer((_) async => sheets.BatchUpdateValuesResponse());
      when(() => mockSpreadsheets.batchUpdate(any(), any())).thenAnswer((_) async => sheets.BatchUpdateSpreadsheetResponse());
      when(() => mockFiles.create(any(), supportsAllDrives: any(named: 'supportsAllDrives'))).thenAnswer((_) async => drive.File()..id = 'fake_sheet_id');

      final id = await t.ensureCompanyRegistry('root123');

      expect(id, equals('fake_sheet_id'));
      verify(() => mockFiles.create(any(), supportsAllDrives: true)).called(1);
      verify(() => mockSpreadsheets.batchUpdate(any(), 'fake_sheet_id')).called(1);
      verify(() => mockValues.batchUpdate(any(), 'fake_sheet_id')).called(1);
    });

    test('registerModule appends row to modules sheet', () async {
      when(() => mockValues.append(any(), any(), any(), 
        valueInputOption: any(named: 'valueInputOption'), 
        insertDataOption: any(named: 'insertDataOption')
      )).thenAnswer((_) async => sheets.AppendValuesResponse());
      
      t.onGetFileId = (_, __) async => 'registry_id';

      await t.registerModule('root123', 'ws123', 'Accounting', 'folder888');

      verify(() => mockValues.append(any(), 'registry_id', 'modules!A1', 
        valueInputOption: 'RAW', 
        insertDataOption: 'INSERT_ROWS'
      )).called(1);
    });

    test('upsertCompanyUserAccess updates existing row', () async {
      t.onGetFileId = (_, __) async => 'registry_id';
      
      when(() => mockValues.get('registry_id', 'user_access!A2:C')).thenAnswer((_) async => sheets.ValueRange(
        values: [
          ['comp1', 'user@test.com', 'old_sheet_id'],
        ]
      ));

      when(() => mockValues.update(any(), any(), any(), valueInputOption: any(named: 'valueInputOption')))
        .thenAnswer((_) async => sheets.UpdateValuesResponse());

      await t.upsertCompanyUserAccess('root123', 'comp1', 'user@test.com', 'new_sheet_id');

      verify(() => mockValues.update(any(), 'registry_id', 'user_access!A2:C2', valueInputOption: 'RAW')).called(1);
    });

    test('getCompanies handles null values', () async {
      t.onGetFileId = (_, __) async => 'registry_id';
      when(() => mockValues.get('registry_id', 'companies!A2:F')).thenAnswer((_) async => sheets.ValueRange(values: []));

      final companies = await t.getCompanies('root123');
      expect(companies, isEmpty);
    });

    test('updateCompany updates registry and renames drive folder', () async {
      t.onGetFileId = (_, __) async => 'registry_id';
      when(() => mockValues.get('registry_id', 'companies!A2:F')).thenAnswer((_) async => sheets.ValueRange(values: [
        ['c1', 'Old Name', 'f1']
      ]));

      when(() => mockValues.update(any(), any(), any(), valueInputOption: any(named: 'valueInputOption')))
          .thenAnswer((_) async => sheets.UpdateValuesResponse());
      
      when(() => mockFiles.update(any(), any())).thenAnswer((_) async => drive.File());

      final company = Company(id: 'c1', name: 'New Name', folderId: 'f1', userAccessFolderId: 'ua_f1');
      await t.updateCompany('root123', company);

      verify(() => mockValues.update(any(), 'registry_id', 'companies!A2:F2', valueInputOption: 'RAW')).called(1);
      verify(() => mockFiles.update(any(), 'f1')).called(1);
    });

    test('createUserAccessSpreadsheet creates spreadsheet and initializes it', () async {
      when(() => mockFiles.create(any(), supportsAllDrives: any(named: 'supportsAllDrives')))
          .thenAnswer((_) async => drive.File()..id = 'new_user_sheet_id');
      when(() => mockSpreadsheets.batchUpdate(any(), any())).thenAnswer((_) async => sheets.BatchUpdateSpreadsheetResponse());
      
      // For the registration part
      when(() => mockFiles.get(any(), $fields: any(named: r'$fields'), supportsAllDrives: any(named: 'supportsAllDrives')))
          .thenAnswer((_) async => drive.File(parents: ['comp_folder_id']));
      t.onCheckRootFolder = () async => 'root_id';
      t.onGetFileId = (_, __) async => 'registry_id';
      when(() => mockValues.get('registry_id', 'user_access!A2:C')).thenAnswer((_) async => sheets.ValueRange(values: []));
      when(() => mockValues.append(any(), any(), any(), valueInputOption: any(named: 'valueInputOption'), insertDataOption: any(named: 'insertDataOption')))
          .thenAnswer((_) async => sheets.AppendValuesResponse());

      final id = await t.createUserAccessSpreadsheet('ua_folder_id', 'user@test.com');

      expect(id, 'new_user_sheet_id');
      verify(() => mockFiles.create(any(), supportsAllDrives: true)).called(1);
      verify(() => mockSpreadsheets.batchUpdate(any(), 'new_user_sheet_id')).called(1);
    });

    test('removeUserAccessModule deletes row when sheetId is found', () async {
      when(() => mockSpreadsheets.get('file123')).thenAnswer((_) async => sheets.Spreadsheet(
        sheets: [sheets.Sheet(properties: sheets.SheetProperties(title: 'modules', sheetId: 123))]
      ));
      when(() => mockValues.get('file123', 'modules!A2:Z')).thenAnswer((_) async => sheets.ValueRange(
        values: [['mod1'], ['mod2']]
      ));
      when(() => mockSpreadsheets.batchUpdate(any(), 'file123')).thenAnswer((_) async => sheets.BatchUpdateSpreadsheetResponse());

      await t.removeUserAccessModule('file123', 'mod2');

      verify(() => mockSpreadsheets.batchUpdate(any(), 'file123')).called(1);
    });

    test('terminateCompany deletes folder and cleans up registry', () async {
       t.onGetFileId = (_, __) async => 'registry_id';
       t.onDeleteFile = (id) async {};

       when(() => mockSpreadsheets.get('registry_id')).thenAnswer((_) async => sheets.Spreadsheet(
         sheets: [
           sheets.Sheet(properties: sheets.SheetProperties(title: 'companies', sheetId: 1)),
           sheets.Sheet(properties: sheets.SheetProperties(title: 'user_access', sheetId: 2)),
         ]
       ));

       when(() => mockValues.get('registry_id', 'companies!A2:Z')).thenAnswer((_) async => sheets.ValueRange(
         values: [['c1', 'Name', 'folder123']]
       ));
       when(() => mockValues.get('registry_id', 'user_access!A2:Z')).thenAnswer((_) async => sheets.ValueRange(
         values: [['folder123', 'user@test.com', 'sheet1']]
       ));

       when(() => mockSpreadsheets.batchUpdate(any(), 'registry_id')).thenAnswer((_) async => sheets.BatchUpdateSpreadsheetResponse());

       await t.terminateCompany('root123', 'folder123');

       verify(() => mockSpreadsheets.batchUpdate(any(), 'registry_id')).called(2); // One for companies, one for user_access
    });
  });
}
