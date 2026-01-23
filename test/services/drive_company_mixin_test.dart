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

    // sheets.spreadsheets.create returns spreadsheet with id
    final created = sheets.Spreadsheet(spreadsheetId: 'sheet123');
    when(() => mockSps.create(any())).thenAnswer((_) async => created);

    // files.get returns a File with no parents
    final file = drive.File()..parents = [];
    when(() => mockFiles.get('sheet123', $fields: any(named: r'$fields'), supportsAllDrives: any(named: 'supportsAllDrives')))
        .thenAnswer((_) async => file);

    // files.update ok
    when(() => mockFiles.update(any(), 'sheet123', addParents: any(named: 'addParents'), removeParents: any(named: 'removeParents'), $fields: any(named: r'$fields')))
        .thenAnswer((_) async => drive.File());

    // values.update ok
    when(() => mockValues.update(any(), 'sheet123', any(), valueInputOption: any(named: 'valueInputOption')))
        .thenAnswer((_) async => sheets.UpdateValuesResponse());

    final fid = await svc.ensureCompanyRegistry('root1');
    expect(fid, 'sheet123');
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

  test('registerCompany appends and ensures user_access folder', () async {
    svc.onGetFileId = (root, name) async => 'sheet123';
    when(() => mockValues.append(any(), 'sheet123', 'companies!A1', valueInputOption: any(named: 'valueInputOption'), insertDataOption: any(named: 'insertDataOption')))
        .thenAnswer((_) async => sheets.AppendValuesResponse());

    // ensureUserAccessFolder uses getOrCreateSubFolder - default returns sub_user_access
    final company = Company(id: 'cid', name: 'CName', folderId: 'f_comp');
    when(() => mockSps.values).thenReturn(mockValues);

    await svc.registerCompany('root1', company);
    // no exception, success
  });

  test('ensureUserAccessSpreadsheet returns existing and upserts registry', () async {
    // Simulate existing file
    svc.onGetFileId = (folderId, name) async => 'ua_file_1';

    // files.get for userAccessFolder should return a File with parents containing company folder
    final folderFile = drive.File();
    folderFile.parents = ['company_folder_1'];
    when(() => mockFiles.get('ua_folder', $fields: any(named: r'$fields'), supportsAllDrives: any(named: 'supportsAllDrives')))
        .thenAnswer((_) async => folderFile);

    // checkRootFolder returns root id
    svc.onCheckRootFolder = () async => 'rootX';

    svc.onGetFileId = (folderId, name) async {
      if (folderId == 'ua_folder') return 'ua_file_1';
      return null;
    };

    // Call and expect existing id returned and upsert recorded
    final res = await svc.ensureUserAccessSpreadsheet('ua_folder', 'user@example.com');
    expect(res, 'ua_file_1');
    expect(svc.lastUpsertCompany, 'company_folder_1');
    expect(svc.lastUpsertUser, 'user@example.com');
  });
}
