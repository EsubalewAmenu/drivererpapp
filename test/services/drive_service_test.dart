import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/models/company_model.dart';

class MockHttpClient extends Mock implements http.Client {}
class MockDriveApi extends Mock implements drive.DriveApi {}
class MockSheetsApi extends Mock implements sheets.SheetsApi {}

// Mock Resources
class MockDriveFilesResource extends Mock implements drive.FilesResource {}
class MockDriveRevisionsResource extends Mock implements drive.RevisionsResource {}
class MockPermissionsResource extends Mock implements drive.PermissionsResource {}
class MockSpreadsheetsResource extends Mock implements sheets.SpreadsheetsResource {}
class MockSpreadsheetsValuesResource extends Mock implements sheets.SpreadsheetsValuesResource {}

void main() {
  late DriveService driveService;
  late MockHttpClient mockHttpClient;
  late MockDriveApi mockDriveApi;
  late MockSheetsApi mockSheetsApi;
  late MockDriveFilesResource mockFilesResource;
  late MockDriveRevisionsResource mockRevisionsResource;
  late MockPermissionsResource mockPermissionsResource;
  late MockSpreadsheetsResource mockSpreadsheetsResource;
  late MockSpreadsheetsValuesResource mockValuesResource;

  setUpAll(() {
    registerFallbackValue(drive.File());
    registerFallbackValue(sheets.Spreadsheet());
    registerFallbackValue(sheets.ValueRange());
    registerFallbackValue(sheets.ClearValuesRequest());
    registerFallbackValue(drive.Media(Stream.empty(), 0));
    registerFallbackValue(sheets.BatchUpdateSpreadsheetRequest());
    registerFallbackValue(Uri());
    registerFallbackValue(drive.Permission());
  });

  setUp(() {
    mockHttpClient = MockHttpClient();
    mockDriveApi = MockDriveApi();
    mockSheetsApi = MockSheetsApi();
    
    mockFilesResource = MockDriveFilesResource();
    mockRevisionsResource = MockDriveRevisionsResource();
    mockPermissionsResource = MockPermissionsResource();
    mockSpreadsheetsResource = MockSpreadsheetsResource();
    mockValuesResource = MockSpreadsheetsValuesResource();

    // Hook up resources
    when(() => mockDriveApi.files).thenReturn(mockFilesResource);
    when(() => mockDriveApi.revisions).thenReturn(mockRevisionsResource);
    when(() => mockDriveApi.permissions).thenReturn(mockPermissionsResource);
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

    test('getOrCreateSubFolder returns existing folder id if found', () async {
       final fileList = drive.FileList(files: [
        drive.File()..id = 'found_id'
      ]);
      
      when(() => mockFilesResource.list(q: any(named: 'q'), $fields: any(named: r'$fields')))
          .thenAnswer((_) async => fileList);

      final result = await driveService.getOrCreateSubFolder('parentId', 'FolderName');

      expect(result, 'found_id');
      verifyNever(() => mockFilesResource.create(any(), $fields: any(named: r'$fields')));
    });

    test('getOrCreateSubFolder creates new folder if not found', () async {
      when(() => mockFilesResource.list(q: any(named: 'q'), $fields: any(named: r'$fields')))
          .thenAnswer((_) async => drive.FileList(files: []));
      
      when(() => mockFilesResource.create(any(), $fields: any(named: r'$fields')))
          .thenAnswer((_) async => drive.File()..id = 'created_id');

      final result = await driveService.getOrCreateSubFolder('parentId', 'FolderName');

      expect(result, 'created_id');
      verify(() => mockFilesResource.create(any(), $fields: any(named: r'$fields'))).called(1);
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

      expect(config!['settings'], isMap);
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
       // Mock spreadsheet lookup
       when(() => mockFilesResource.list(q: any(named: 'q'), $fields: any(named: '\$fields')))
          .thenAnswer((_) async => drive.FileList(files: [drive.File()..id = 'sheet123'..name = 'tab1']));

      when(() => mockSpreadsheetsResource.get(any())).thenAnswer((_) async => sheets.Spreadsheet(
        sheets: [sheets.Sheet(properties: sheets.SheetProperties(title: 'tab1', sheetId: 0))],
      ));

      // Header (Gviz also needs headers)
      when(() => mockValuesResource.get(any(), 'tab1!1:1')).thenAnswer((_) async => sheets.ValueRange(
        values: [['col1', 'record_id']],
      ));

      // Gviz Mock Result (Two records, newest first as requested by DESC)
      final gvizResponse = '/*-google-javascript-data-lite-*/google.visualization.Query.setResponse({"status":"ok","table":{"rows":[{"c":[{"v":"rec2"},{"v":"200"}]},{"c":[{"v":"rec1"},{"v":"100"}]}]}});';
      when(() => mockHttpClient.get(any())).thenAnswer((_) async => http.Response(gvizResponse, 200));

      final results = await driveService.fetchRecords('mod1', 'MyModule', 'tab1', descending: true);

      expect(results.length, 2);
      expect(results.first['record_id'], '200'); // Newest first
      expect(results.last['record_id'], '100');
    });

    test('fetchRecords handles search with mixed numeric columns (Gviz)', () async {
       when(() => mockFilesResource.list(q: any(named: 'q'), $fields: any(named: '\$fields')))
          .thenAnswer((_) async => drive.FileList(files: [drive.File()..id = 'sheet123'..name = 'contacts']));

      when(() => mockSpreadsheetsResource.get(any())).thenAnswer((_) async => sheets.Spreadsheet(
        sheets: [sheets.Sheet(properties: sheets.SheetProperties(title: 'contacts', sheetId: 101))],
      ));

      // Header: Name and Phone (numeric keyword)
      when(() => mockValuesResource.get(any(), 'contacts!1:1')).thenAnswer((_) async => sheets.ValueRange(
        values: [['Name', 'Phone']],
      ));

      final gvizResponse = '/*-google-javascript-data-lite-*/google.visualization.Query.setResponse({"status":"ok","table":{"rows":[{"c":[{"v":"Dawit"},{"v":12345}]}]}});';
      when(() => mockHttpClient.get(any(that: predicate((Uri uri) {
        final tq = uri.queryParameters['tq'] ?? '';
        // Should use lower() for Name (A). 
        // Phone (B) is in strictlyNonText, so it should be skipped if query is "Dawit".
        return tq.contains('lower(A)') && !tq.contains('B');
      })))).thenAnswer((_) async => http.Response(gvizResponse, 200));

      final results = await driveService.fetchRecords('mod1', 'MyModule', 'contacts', searchQuery: 'Dawit');

      expect(results.length, 1);
      expect(results.first['Name'], 'Dawit');
    });

    test('fetchRecords with sub-tables', () async {
       // Mock folder/file lookup
      when(() => mockFilesResource.list(q: any(named: 'q'), $fields: any(named: '\$fields')))
          .thenAnswer((_) async => drive.FileList(files: [drive.File()..id = 'sheet123'..name = 'tab1']));

      // Mock spreadsheet get to show sub-sheets
      when(() => mockSpreadsheetsResource.get('sheet123')).thenAnswer((_) async => sheets.Spreadsheet(
        sheets: [
          sheets.Sheet(properties: sheets.SheetProperties(title: 'tab1')),
          sheets.Sheet(properties: sheets.SheetProperties(title: 'tab1.items')),
        ],
      ));

      // Mock Headings & Data for main tab
      when(() => mockValuesResource.get('sheet123', 'tab1!1:1')).thenAnswer((_) async => sheets.ValueRange(values: [['record_id', 'name']]));
      when(() => mockValuesResource.get('sheet123', 'tab1!A2:ZZ')).thenAnswer((_) async => sheets.ValueRange(values: [['r1', 'Record 1']]));

      // Mock Headings & Data for sub-tab
      when(() => mockValuesResource.get('sheet123', 'tab1.items!1:1')).thenAnswer((_) async => sheets.ValueRange(values: [['parent_record_id', 'item_name']]));
      when(() => mockValuesResource.get('sheet123', 'tab1.items!A2:ZZ')).thenAnswer((_) async => sheets.ValueRange(values: [['r1', 'Sub Item 1']]));

      final results = await driveService.fetchRecords('mod1', 'MyModule', 'tab1', fetchSubTables: true);

      expect(results.length, 1);
      final record = results[0];
      expect(record['items'], isA<List>());
      expect((record['items'] as List).length, 1);
      expect((record['items'] as List)[0]['item_name'], 'Sub Item 1');
    });
  });

  group('DriveCompanyMixin', () {
    test('ensureCompanyRegistry returns existing ID if found', () async {
      when(() => mockFilesResource.list(q: any(named: 'q'), $fields: any(named: '\$fields')))
          .thenAnswer((_) async => drive.FileList(files: [drive.File()..id = 'reg123'..name = 'companies']));

      final result = await driveService.ensureCompanyRegistry('root123');

      expect(result, 'reg123');
      verify(() => mockFilesResource.list(q: any(named: 'q'), $fields: any(named: '\$fields'))).called(1);
    });

    test('ensureCompanyRegistry creates new registry when not found', () async {
      // 1. Not found
      when(() => mockFilesResource.list(q: any(named: 'q'), $fields: any(named: '\$fields')))
          .thenAnswer((_) async => drive.FileList(files: []));

      // 2. Create spreadsheet
      when(() => mockSpreadsheetsResource.create(any()))
          .thenAnswer((_) async => sheets.Spreadsheet(spreadsheetId: 'new_reg_id'));

      // 3. Move to root (get then update)
      when(() => mockFilesResource.get(any(), $fields: any(named: '\$fields')))
          .thenAnswer((_) async => drive.File()..id = 'new_reg_id'..parents = ['old_parent']);
      
      when(() => mockFilesResource.update(any(), any(), addParents: any(named: 'addParents'), removeParents: any(named: 'removeParents'), $fields: any(named: '\$fields')))
          .thenAnswer((_) async => drive.File());

      // 4. Update headers
      when(() => mockValuesResource.update(any(), any(), any(), valueInputOption: any(named: 'valueInputOption')))
          .thenAnswer((_) async => sheets.UpdateValuesResponse());

      final result = await driveService.ensureCompanyRegistry('root123');

      expect(result, 'new_reg_id');
      
      verify(() => mockSpreadsheetsResource.create(any(that: isA<sheets.Spreadsheet>().having((s) => s.properties?.title, 'title', 'companies')))).called(1);
      verify(() => mockFilesResource.update(any(), 'new_reg_id', addParents: 'root123', removeParents: 'old_parent', $fields: 'id, parents')).called(1);
      verify(() => mockValuesResource.update(
        any(that: isA<sheets.ValueRange>().having((v) => v.values?.first, 'headers', ['id', 'name', 'folderId', 'logoUrl', 'role'])),
        'new_reg_id',
        'companies!A1',
        valueInputOption: 'RAW',
      )).called(1);
    });

    test('getCompanies returns empty list if registry file not found', () async {
      when(() => mockFilesResource.list(q: any(named: 'q'), $fields: any(named: '\$fields')))
          .thenAnswer((_) async => drive.FileList(files: []));

      final result = await driveService.getCompanies('root123');

      expect(result, isEmpty);
    });

    test('getCompanies handles various row lengths correctly', () async {
      when(() => mockFilesResource.list(q: any(named: 'q'), $fields: any(named: '\$fields')))
          .thenAnswer((_) async => drive.FileList(files: [drive.File()..id = 'sheet123'..name = 'companies']));

      when(() => mockValuesResource.get('sheet123', 'companies!A2:E'))
          .thenAnswer((_) async => sheets.ValueRange(values: [
            ['c1', 'Company 1', 'f1', 'logo1', 'owner'], // Full row
            ['c2', 'Company 2', 'f2'],                  // Partial row
            ['c3'],                                     // Very partial row
          ]));

      final result = await driveService.getCompanies('root123');

      expect(result.length, 3);
      
      expect(result[0].id, 'c1');
      expect(result[0].logoUrl, 'logo1');
      expect(result[0].role, 'owner');

      expect(result[1].id, 'c2');
      expect(result[1].logoUrl, isNull);
      expect(result[1].role, isNull);

      expect(result[2].id, 'c3');
      expect(result[2].name, '');
      expect(result[2].folderId, '');
    });

    test('registerCompany ensures registry and appends row', () async {
      // Stub ensureCompanyRegistry (which uses getFileId -> list)
      when(() => mockFilesResource.list(q: any(named: 'q'), $fields: any(named: '\$fields')))
          .thenAnswer((_) async => drive.FileList(files: [drive.File()..id = 'sheet123'..name = 'companies']));

      when(() => mockValuesResource.append(any(), any(), any(), valueInputOption: any(named: 'valueInputOption'), insertDataOption: any(named: 'insertDataOption')))
          .thenAnswer((_) async => sheets.AppendValuesResponse());

      final company = Company(id: 'new_id', name: 'New Co', folderId: 'folder_abc', logoUrl: 'logo_url', role: 'admin');
      await driveService.registerCompany('root123', company);

      verify(() => mockValuesResource.append(
        any(that: isA<sheets.ValueRange>().having((v) => v.values?.first, 'values', ['new_id', 'New Co', 'folder_abc', 'logo_url', 'admin'])),
        'sheet123',
        'companies!A1',
        valueInputOption: 'RAW',
        insertDataOption: 'INSERT_ROWS',
      )).called(1);
    });

    test('updateCompany updates row in registry and renames folder', () async {
      // 1. Find registry ID
      when(() => mockFilesResource.list(q: any(named: 'q'), $fields: any(named: '\$fields')))
          .thenAnswer((_) async => drive.FileList(files: [drive.File()..id = 'sheet123'..name = 'companies']));

      // 2. Mock finding the row
      when(() => mockValuesResource.get('sheet123', 'companies!A2:E'))
          .thenAnswer((_) async => sheets.ValueRange(values: [['target_id', 'Old Name', 'folder123']]));

      // 3. Mock update row
      when(() => mockValuesResource.update(any(), any(), any(), valueInputOption: any(named: 'valueInputOption')))
          .thenAnswer((_) async => sheets.UpdateValuesResponse());

      // 4. Mock folder rename
      when(() => mockFilesResource.update(any(), any(), $fields: any(named: '\$fields')))
          .thenAnswer((_) async => drive.File());

      final updated = Company(id: 'target_id', name: 'Updated Co', folderId: 'folder123');
      await driveService.updateCompany('root123', updated);

      // Verify spreadsheet update at target row (index 0 -> row 2)
      verify(() => mockValuesResource.update(
        any(that: isA<sheets.ValueRange>().having((v) => v.values?.first[1], 'name', 'Updated Co')),
        'sheet123',
        'companies!A2:E2',
        valueInputOption: 'RAW',
      )).called(1);

      // Verify folder rename
      verify(() => mockFilesResource.update(
        any(that: isA<drive.File>().having((f) => f.name, 'name', 'Updated Co')),
        'folder123',
      )).called(1);
    });

    test('updateCompanyLogo uploads, deletes old, and updates registry', () async {
      final oldLogoId = 'old_logo_id';
      final newLogoId = 'new_logo_id';
      final rootId = 'root123';
      final companyId = 'c1';
      final folderId = 'f1';

      // 1. Mock getCompanies (to find folder and old logo)
      when(() => mockFilesResource.list(q: any(named: 'q'), $fields: any(named: '\$fields')))
          .thenAnswer((_) async => drive.FileList(files: [drive.File()..id = 'sheet123'..name = 'companies']));
      when(() => mockValuesResource.get('sheet123', 'companies!A2:E')) // From getCompanies
          .thenAnswer((_) async => sheets.ValueRange(values: [
            [companyId, 'My Co', folderId, 'https://drive.google.com/uc?export=view&id=$oldLogoId', 'owner']
          ]));

      // 2. Mock delete old logo
      when(() => mockFilesResource.delete(oldLogoId)).thenAnswer((_) async => null);

      // 3. Mock upload new logo
      when(() => mockFilesResource.create(any(), uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async => drive.File()..id = newLogoId..name = 'logo.png');

      // 4. Mock permissions
      when(() => mockPermissionsResource.create(any(), any())).thenAnswer((_) async => drive.Permission());

      // 5. Mock registry update (search then update)
      when(() => mockValuesResource.get('sheet123', 'companies!A2:E')) // Both getCompanies and updateCompany search
          .thenAnswer((_) async => sheets.ValueRange(values: [
            [companyId, 'My Co', folderId, 'https://drive.google.com/uc?export=view&id=$oldLogoId', 'owner']
          ]));
      when(() => mockValuesResource.update(any(), any(), any(), valueInputOption: any(named: 'valueInputOption')))
          .thenAnswer((_) async => sheets.UpdateValuesResponse());
      
      // 6. Mock folder rename (inside updateCompany)
      when(() => mockFilesResource.update(any(), any(), $fields: any(named: '\$fields')))
          .thenAnswer((_) async => drive.File());

      final newUrl = await driveService.updateCompanyLogo(rootId, companyId, [1, 2, 3], 'png');

      expect(newUrl, contains(newLogoId));
      verify(() => mockFilesResource.delete(any())).called(1);
      verify(() => mockFilesResource.create(any(), uploadMedia: any(named: 'uploadMedia'))).called(1);
      verify(() => mockPermissionsResource.create(any(), any())).called(1);
      
      // Verify registry update contains new URL
      verify(() => mockValuesResource.update(
        any(that: isA<sheets.ValueRange>().having((v) => v.values?.first[3], 'logoUrl', newUrl)),
        'sheet123',
        'companies!A2:E2',
        valueInputOption: 'RAW',
      )).called(1);
    });
  });
}
