import 'dart:convert';
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
class MockDriveRevisionsResource extends Mock implements drive.RevisionsResource {}
class MockSpreadsheetsResource extends Mock implements sheets.SpreadsheetsResource {}
class MockSpreadsheetsValuesResource extends Mock implements sheets.SpreadsheetsValuesResource {}

void main() {
  late DriveService driveService;
  late MockHttpClient mockHttpClient;
  late MockDriveApi mockDriveApi;
  late MockSheetsApi mockSheetsApi;
  late MockDriveFilesResource mockFilesResource;
  late MockDriveRevisionsResource mockRevisionsResource;
  late MockSpreadsheetsResource mockSpreadsheetsResource;
  late MockSpreadsheetsValuesResource mockValuesResource;

  setUpAll(() {
    registerFallbackValue(drive.File());
    registerFallbackValue(sheets.Spreadsheet());
    registerFallbackValue(sheets.ValueRange());
    registerFallbackValue(sheets.ClearValuesRequest());
    registerFallbackValue(drive.Media(Stream.empty(), 0));
    registerFallbackValue(sheets.BatchUpdateSpreadsheetRequest());
  });

  setUp(() {
    mockHttpClient = MockHttpClient();
    mockDriveApi = MockDriveApi();
    mockSheetsApi = MockSheetsApi();
    
    mockFilesResource = MockDriveFilesResource();
    mockRevisionsResource = MockDriveRevisionsResource();
    mockSpreadsheetsResource = MockSpreadsheetsResource();
    mockValuesResource = MockSpreadsheetsValuesResource();

    // Hook up resources
    when(() => mockDriveApi.files).thenReturn(mockFilesResource);
    when(() => mockDriveApi.revisions).thenReturn(mockRevisionsResource);
    when(() => mockSheetsApi.spreadsheets).thenReturn(mockSpreadsheetsResource);
    when(() => mockSpreadsheetsResource.values).thenReturn(mockValuesResource);

    driveService = DriveService(
      mockHttpClient,
      driveApi: mockDriveApi,
      sheetsApi: mockSheetsApi,
      delay: (_) async {}, // No delay for testing
    );
  });

  group('DriveFolderMixin', () {
    test('checkRootFolder returns valid ID', () async {
      final fileList = drive.FileList(files: [drive.File()..id = 'root123']);
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

  group('DriveFileMixin', () {
    test('getFileId returns id if file exists', () async {
      final fileList = drive.FileList(files: [
        drive.File()..id = 'f1'..name = 'config'
      ]);

      when(() => mockFilesResource.list(q: any(named: 'q'), $fields: any(named: '\$fields')))
          .thenAnswer((_) async => fileList);

      final result = await driveService.getFileId('mod1', 'config');

      expect(result, 'f1');
    });

    test('createFile creates file with media', () async {
      when(() => mockFilesResource.create(any(), $fields: any(named: '\$fields'), uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async => drive.File()..id = 'new_file'..name = 'data.json');

      final result = await driveService.createFile('mod1', 'data.json', '{"test": "data"}');

      expect(result, 'new_file');
      verify(() => mockFilesResource.create(
        any(that: isA<drive.File>().having((f) => f.name, 'name', 'data.json')),
        uploadMedia: any(named: 'uploadMedia'),
        $fields: any(named: '\$fields'),
      )).called(1);
    });

    test('getFileContent downloads and decodes string', () async {
      final content = 'hello world';
      final List<int> bytes = utf8.encode(content);
      final stream = Stream<List<int>>.value(bytes);
      final media = drive.Media(stream, bytes.length);

      when(() => mockFilesResource.get(any(), downloadOptions: drive.DownloadOptions.fullMedia))
          .thenAnswer((_) async => media);

      final result = await driveService.getFileContent('f123');

      expect(result, content);
    });

    test('getFileRevisions returns list', () async {
      final revisions = drive.RevisionList(revisions: [
        drive.Revision()..id = 'r1'
      ]);

      when(() => mockRevisionsResource.list(any(), $fields: any(named: '\$fields')))
          .thenAnswer((_) async => revisions);

      final result = await driveService.getFileRevisions('f123');

      expect(result.length, 1);
      expect(result.first.id, 'r1');
    });

    test('updateFile updates file with media', () async {
      when(() => mockFilesResource.update(
        any(), 
        'file123', 
        uploadMedia: any(named: 'uploadMedia'),
      )).thenAnswer((_) async => drive.File()..id = 'file123');

      await driveService.updateFile('file123', '{"updated": true}');
      
      verify(() => mockFilesResource.update(
        any(), 
        'file123', 
        uploadMedia: any(named: 'uploadMedia'),
      )).called(1);
    });

    test('getFileModifiedTime returns time', () async {
      final now = DateTime.now();
      when(() => mockFilesResource.get('file123', $fields: 'modifiedTime'))
          .thenAnswer((_) async => drive.File()..modifiedTime = now);

      final result = await driveService.getFileModifiedTime('file123');
      expect(result, now);
    });

    test('getFileModifiedTime returns null on error', () async {
      when(() => mockFilesResource.get('error_file', $fields: 'modifiedTime'))
          .thenThrow(Exception('API Error'));

      final result = await driveService.getFileModifiedTime('error_file');
      expect(result, isNull);
    });

    test('retryOp retries on failure', () async {
      int calls = 0;
      final result = await driveService.retryOp(() async {
        calls++;
        if (calls < 3) throw Exception('Temp Error');
        return 'success';
      });
      
      expect(result, 'success');
      expect(calls, 3);
    });

    test('retryOp fails after retries', () async {
      expect(
        () => driveService.retryOp(() async => throw Exception('Persistent Error'), retries: 2),
        throwsException,
      );
    });
  });

  group('DriveSheetMixin', () {

    test('createModuleConfig creates spreadsheet and updates config', () async {
      // 1. Create Spreadsheet
      when(() => mockSpreadsheetsResource.create(any()))
          .thenAnswer((_) async => sheets.Spreadsheet(spreadsheetId: 'new_sheet_id'));

      // 2. Move file (get parents, update)
      when(() => mockFilesResource.get('new_sheet_id', $fields: any(named: '\$fields')))
          .thenAnswer((_) async => drive.File()..parents = ['old_parent']);
      
      when(() => mockFilesResource.update(any(), 'new_sheet_id', addParents: 'folder123', removeParents: 'old_parent', $fields: any(named: '\$fields')))
          .thenAnswer((_) async => drive.File());

      // 3. Write data (Values.clear, Values.update)
      when(() => mockValuesResource.clear(any(), any(), any())).thenAnswer((_) async => sheets.ClearValuesResponse());
      when(() => mockValuesResource.update(any(), any(), any(), valueInputOption: any(named: 'valueInputOption')))
          .thenAnswer((_) async => sheets.UpdateValuesResponse());

      final config = {
        'settings': {'appName': 'Test'},
        'tabs': [{'id': 'tab1', 'label': 'Tab 1'}] // List of maps, not TabConfig objects for this raw map
      };

      final result = await driveService.createModuleConfig('folder123', 'mod_config.xlsx', config);
      expect(result, 'new_sheet_id');

      // Verify creation
      verify(() => mockSpreadsheetsResource.create(any())).called(1);
      
      // Verify updates for settings and tabs
      verify(() => mockValuesResource.update(any(), 'new_sheet_id', 'settings!A1', valueInputOption: 'RAW')).called(1);
      verify(() => mockValuesResource.update(any(), 'new_sheet_id', 'tabs!A1', valueInputOption: 'RAW')).called(1);
    });

    test('readModuleConfig reads and decodes config', () async {
      // Setup mock responses for settings, dashboard, tabs
      // settings
      when(() => mockValuesResource.get('sheet123', 'settings!A:B'))
          .thenAnswer((_) async => sheets.ValueRange(values: [
            ['appName', '"Test App"'], // Values are JSON encoded
            ['darkMode', 'true']
          ]));
      
      // dashboard
      when(() => mockValuesResource.get('sheet123', 'dashboard!A:B'))
          .thenAnswer((_) async => sheets.ValueRange(values: []));

      // tabs
      when(() => mockValuesResource.get('sheet123', 'tabs!A:B'))
          .thenAnswer((_) async => sheets.ValueRange(values: [
            ['tab1', '{"id":"tab1", "label":"Tab 1"}']
          ]));

      final config = await driveService.readModuleConfig('sheet123');

      expect(config['settings'], isMap);
      expect(config['settings']['appName'], 'Test App');
      expect(config['settings']['darkMode'], true);
      
      expect(config['tabs'], isList);
      expect(config['tabs'].first['id'], 'tab1');
    });

    test('saveRecord appends data to sheets', () async {
      when(() => mockFilesResource.list(q: any(named: 'q'), $fields: any(named: '\$fields')))
          .thenAnswer((_) async => drive.FileList(files: [drive.File()..id = 'sheet123'..name = 'tab1']));
      
      when(() => mockSpreadsheetsResource.get(any())).thenAnswer((_) async => sheets.Spreadsheet(
        sheets: [sheets.Sheet(properties: sheets.SheetProperties(title: 'tab1'))],
      ));

      when(() => mockValuesResource.get(any(), any())).thenAnswer((_) async => sheets.ValueRange(values: [['key1', 'key2']]));
      
      when(() => mockValuesResource.append(any(), any(), any(), valueInputOption: any(named: 'valueInputOption')))
          .thenAnswer((_) async => sheets.AppendValuesResponse());

      when(() => mockValuesResource.update(any(), any(), any(), valueInputOption: any(named: 'valueInputOption')))
          .thenAnswer((_) async => sheets.UpdateValuesResponse());

      final data = {'key1': 'val1', 'key2': 'val2'};
      await driveService.saveRecord('mod1', 'MyModule', 'tab1', data);

      verify(() => mockValuesResource.append(
        any(that: isA<sheets.ValueRange>().having((v) => v.values?.first, 'values', containsAll(['val1', 'val2']))),
        'sheet123',
        'tab1!A1',
        valueInputOption: 'RAW',
      )).called(1);
    });

    test('fetchRecords returns list of maps', () async {
      when(() => mockFilesResource.list(q: any(named: 'q'), $fields: any(named: '\$fields')))
          .thenAnswer((_) async => drive.FileList(files: [drive.File()..id = 'sheet123'..name = 'tab1']));

      when(() => mockSpreadsheetsResource.get(any())).thenAnswer((_) async => sheets.Spreadsheet(
        sheets: [sheets.Sheet(properties: sheets.SheetProperties(title: 'tab1'))],
      ));

      // Mock Header Call
      when(() => mockValuesResource.get(any(), 'tab1!1:1')).thenAnswer((_) async => sheets.ValueRange(
        values: [
          ['col1', 'col2'],
        ],
      ));

      // Mock Data Call (Initial fetch uses A2:ZZ)
      when(() => mockValuesResource.get(any(), 'tab1!A2:ZZ')).thenAnswer((_) async => sheets.ValueRange(
        values: [
          ['val1', 'val2'],
        ],
      ));

      final results = await driveService.fetchRecords('mod1', 'MyModule', 'tab1');

      expect(results.length, 1);
      expect(results.first['col1'], 'val1');
      expect(results.first['col2'], 'val2');
    });

    test('fetchRecords returns sorted list when descending is true', () async {
       // Mock two files
       when(() => mockFilesResource.list(q: any(named: 'q'), $fields: any(named: '\$fields')))
          .thenAnswer((_) async => drive.FileList(files: [drive.File()..id = 'sheet123'..name = 'tab1']));

      when(() => mockSpreadsheetsResource.get(any())).thenAnswer((_) async => sheets.Spreadsheet(
        sheets: [sheets.Sheet(properties: sheets.SheetProperties(title: 'tab1'))],
      ));

      // Header
      when(() => mockValuesResource.get(any(), 'tab1!1:1')).thenAnswer((_) async => sheets.ValueRange(
        values: [['col1', 'record_id']],
      ));

      // Data (Two records, oldest first in sheet)
      when(() => mockValuesResource.get(any(), 'tab1!A2:ZZ')).thenAnswer((_) async => sheets.ValueRange(
        values: [
          ['rec1', '100'],
          ['rec2', '200'],
        ],
      ));

      final results = await driveService.fetchRecords('mod1', 'MyModule', 'tab1', descending: true);

      expect(results.length, 2);
      expect(results.first['record_id'], '200'); // Newest first
      expect(results.last['record_id'], '100');
    });
  });
}
