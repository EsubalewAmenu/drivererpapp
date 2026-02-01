import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;

import 'package:drivererpapp/services/drive/drive_company_mixin.dart';
import 'package:drivererpapp/models/company_model.dart';

class MockDriveApi extends Mock implements drive.DriveApi {}
class MockFilesResource extends Mock implements drive.FilesResource {}
class MockPermissionsResource extends Mock implements drive.PermissionsResource {}
class MockSheetsApi extends Mock implements sheets.SheetsApi {}
class MockSpreadsheetsResource extends Mock implements sheets.SpreadsheetsResource {}
class MockValuesResource extends Mock implements sheets.SpreadsheetsValuesResource {}

// Fake types for mocktail fallbacks
class SpreadsheetFake extends Fake implements sheets.Spreadsheet {}
class ValueRangeFake extends Fake implements sheets.ValueRange {}
class FileFake extends Fake implements drive.File {}
class BatchUpdateSpreadsheetRequestFake extends Fake implements sheets.BatchUpdateSpreadsheetRequest {}
class BatchUpdateValuesRequestFake extends Fake implements sheets.BatchUpdateValuesRequest {}

class TestDriveCompanyService with DriveCompanyMixin {
  final drive.DriveApi _driveApi;
  final sheets.SheetsApi _sheetsApi;

  // injectable behavior for helpers
  Future<String?> Function(String, String)? onGetFileId;
  Future<String> Function(String, String)? onGetOrCreateSubFolder;
  Future<String?> Function()? onCheckRootFolder;
  Future<String> Function(String, String, List<int>, {String? mimeType})? onUploadFile;
  Future<void> Function(String)? onDeleteFile;

  TestDriveCompanyService(this._driveApi, this._sheetsApi);

  @override
  drive.DriveApi get driveApi => _driveApi;

  @override
  sheets.SheetsApi get sheetsApi => _sheetsApi;

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
  Future<T> retryOp<T>(Future<T> Function() action, {int retries = 3}) async {
    return await action();
  }

  @override
  Future<String> uploadFile(String folderId, String fileName, List<int> bytes, {String? mimeType}) {
    if (onUploadFile != null) return onUploadFile!(folderId, fileName, bytes, mimeType: mimeType);
    return Future.value('uploadedId');
  }

  @override
  Future<void> deleteFile(String fileId) {
    if (onDeleteFile != null) return onDeleteFile!(fileId);
    return Future.value();
  }

  // allow overriding upsertCompanyUserAccess to capture calls
  String? lastUpsertCompany;
  String? lastUpsertUser;
  String? lastUpsertSpreadsheet;

  @override
  Future<void> upsertCompanyUserAccess(String rootFolderId, String companyFolderId, String userEmail, String spreadsheetId) async {
    lastUpsertCompany = companyFolderId;
    lastUpsertUser = userEmail;
    lastUpsertSpreadsheet = spreadsheetId;
    return;
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(SpreadsheetFake());
    registerFallbackValue(ValueRangeFake());
    registerFallbackValue(FileFake());
    registerFallbackValue(BatchUpdateSpreadsheetRequestFake());
    registerFallbackValue(BatchUpdateValuesRequestFake());
  });
  late MockDriveApi mockDriveApi;
  late MockFilesResource mockFiles;
  late MockPermissionsResource mockPerms;
  late MockSheetsApi mockSheetsApi;
  late MockSpreadsheetsResource mockSps;
  late MockValuesResource mockValues;
  late TestDriveCompanyService svc;

  setUp(() {
    mockDriveApi = MockDriveApi();
    mockFiles = MockFilesResource();
    mockPerms = MockPermissionsResource();
    mockSheetsApi = MockSheetsApi();
    mockSps = MockSpreadsheetsResource();
    mockValues = MockValuesResource();

    when(() => mockDriveApi.files).thenReturn(mockFiles);
    when(() => mockDriveApi.permissions).thenReturn(mockPerms);
    when(() => mockSheetsApi.spreadsheets).thenReturn(mockSps);
    when(() => mockSps.values).thenReturn(mockValues);

    svc = TestDriveCompanyService(mockDriveApi, mockSheetsApi);
  });

  test('ensureCompanyRegistry creates when missing', () async {
    // getFileId returns null
    svc.onGetFileId = (folderId, name) async => null;

    // files.create returns a File with id
    when(() => mockFiles.create(any(), supportsAllDrives: any(named: 'supportsAllDrives')))
        .thenAnswer((_) async => drive.File()..id = 'sheet123');

    // batchUpdate ok
    when(() => mockSps.batchUpdate(any(), any())).thenAnswer((_) async => sheets.BatchUpdateSpreadsheetResponse());

    // values.batchUpdate ok
    when(() => mockValues.batchUpdate(any(), any())).thenAnswer((_) async => sheets.BatchUpdateValuesResponse());

    final fid = await svc.ensureCompanyRegistry('root1');
    expect(fid, 'sheet123');
    verify(() => mockFiles.create(any(), supportsAllDrives: true)).called(1);
    verify(() => mockSps.batchUpdate(any(), 'sheet123')).called(1);
    verify(() => mockValues.batchUpdate(any(), 'sheet123')).called(1);
  });

  test('getCompanies returns parsed companies', () async {
    svc.onGetFileId = (root, name) async => 'sheet123';

    // sheets.values.get returns rows
    final resp = sheets.ValueRange(values: [
      ['c1', 'Acme', 'f1', 'http://logo', 'owner'],
      ['c2', 'Beta', 'f2'],
    ]);
    when(() => mockValues.get('sheet123', 'companies!A2:E')).thenAnswer((_) async => resp);

    final list = await svc.getCompanies('root1');
    expect(list.length, 2);
    expect(list[0].id, 'c1');
    expect(list[0].name, 'Acme');
    expect(list[0].logoUrl, 'http://logo');
    expect(list[1].id, 'c2');
  });
}
