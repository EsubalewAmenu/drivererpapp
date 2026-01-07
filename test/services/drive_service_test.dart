import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import 'package:drivererpapp/services/drive_service.dart';

class MockHttpClient extends Mock implements http.Client {}
class MockDriveApi extends Mock implements drive.DriveApi {}
class MockSheetsApi extends Mock implements sheets.SheetsApi {}

// Mock Resources
class MockDriveFilesResource extends Mock implements drive.FilesResource {}
class MockSpreadsheetsResource extends Mock implements sheets.SpreadsheetsResource {}
class MockSpreadsheetsValuesResource extends Mock implements sheets.SpreadsheetsValuesResource {}

void main() {
  late DriveService driveService;
  late MockHttpClient mockHttpClient;
  late MockDriveApi mockDriveApi;
  late MockSheetsApi mockSheetsApi;
  late MockDriveFilesResource mockFilesResource;
  late MockSpreadsheetsResource mockSpreadsheetsResource;
  late MockSpreadsheetsValuesResource mockValuesResource;

  setUp(() {
    mockHttpClient = MockHttpClient();
    mockDriveApi = MockDriveApi();
    mockSheetsApi = MockSheetsApi();
    
    mockFilesResource = MockDriveFilesResource();
    mockSpreadsheetsResource = MockSpreadsheetsResource();
    mockValuesResource = MockSpreadsheetsValuesResource();

    // Hook up resources
    when(() => mockDriveApi.files).thenReturn(mockFilesResource);
    when(() => mockSheetsApi.spreadsheets).thenReturn(mockSpreadsheetsResource);
    when(() => mockSpreadsheetsResource.values).thenReturn(mockValuesResource);

    driveService = DriveService(
      mockHttpClient,
      driveApi: mockDriveApi,
      sheetsApi: mockSheetsApi,
    );
     registerFallbackValue(drive.File());
     registerFallbackValue(sheets.BatchUpdateSpreadsheetRequest());
  });

  group('DriveFolderMixin', () {
    test('checkRootFolder returns existing folder id', () async {
      final fileList = drive.FileList(files: [
        drive.File()..id = 'root123'..name = 'DriveERP_Data'
      ]);

      when(() => mockFilesResource.list(q: any(named: 'q'), $fields: any(named: '\$fields')))
          .thenAnswer((_) async => fileList);

      final result = await driveService.checkRootFolder();

      expect(result, 'root123');
      verify(() => mockFilesResource.list(
        q: "mimeType = 'application/vnd.google-apps.folder' and name = 'DriveERP_Data' and trashed = false",
        $fields: "files(id, name)",
      )).called(1);
    });

    test('checkRootFolder returns null if not exists', () async {
      when(() => mockFilesResource.list(q: any(named: 'q'), $fields: any(named: '\$fields')))
          .thenAnswer((_) async => drive.FileList(files: []));

      final result = await driveService.checkRootFolder();

      expect(result, isNull);
    });

    test('createRootFolder creates new folder', () async {
      when(() => mockFilesResource.create(any(), $fields: any(named: '\$fields')))
          .thenAnswer((_) async => drive.File()..id = 'new_root');

      final result = await driveService.createRootFolder();

      expect(result, 'new_root');
      verify(() => mockFilesResource.create(
        any(that: isA<drive.File>().having((f) => f.name, 'name', 'DriveERP_Data')), 
        $fields: any(named: '\$fields')
      )).called(1);
    });

    test('listWorkspaces returns list of folders', () async {
      final fileList = drive.FileList(files: [
        drive.File()..id = 'ws1'..name = 'Workspace 1'
      ]);

      when(() => mockFilesResource.list(q: any(named: 'q'), $fields: any(named: '\$fields')))
          .thenAnswer((_) async => fileList);

      final result = await driveService.listWorkspaces('root123');

      expect(result.length, 1);
      expect(result.first.name, 'Workspace 1');
    });

    test('createWorkspace creates folder with parent', () async {
      when(() => mockFilesResource.create(any(), $fields: any(named: '\$fields')))
          .thenAnswer((_) async => drive.File()..id = 'new_ws'..name = 'My Workspace');

      final result = await driveService.createWorkspace('root123', 'My Workspace');

      expect(result.id, 'new_ws');
      expect(result.name, 'My Workspace');
      
      verify(() => mockFilesResource.create(
        any(that: isA<drive.File>()
          .having((f) => f.name, 'name', 'My Workspace')
          .having((f) => f.parents, 'parents', contains('root123'))
        ),
        $fields: any(named: '\$fields'),
      )).called(1);
    });

    test('listModules returns list of folders in workspace', () async {
      final fileList = drive.FileList(files: [
        drive.File()..id = 'mod1'..name = 'Module 1'
      ]);

      when(() => mockFilesResource.list(q: any(named: 'q'), $fields: any(named: '\$fields')))
          .thenAnswer((_) async => fileList);

      final result = await driveService.listModules('ws123');

      expect(result.length, 1);
      expect(result.first.id, 'mod1');
    });
  });
}
