import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:drivererpapp/services/drive/drive_sheet/mixin.dart';
import 'package:drivererpapp/services/drive/drive_sheet/fetch.dart';
import 'package:drivererpapp/services/drive/drive_sheet/crud.dart';
import 'package:drivererpapp/services/drive/drive_sheet/config.dart';
import 'package:drivererpapp/services/drive/drive_sheet/gviz.dart';
import 'package:drivererpapp/models/schema_models.dart';

class MockDriveApi extends Mock implements drive.DriveApi {}
class MockFilesResource extends Mock implements drive.FilesResource {}
class MockSheetsApi extends Mock implements sheets.SheetsApi {}
class MockSpreadsheetsResource extends Mock implements sheets.SpreadsheetsResource {}
class MockValuesResource extends Mock implements sheets.SpreadsheetsValuesResource {}
class MockHttpClient extends Mock implements http.Client {}

class TestDriveService with DriveSheetMixin, DriveSheetGviz, DriveSheetFetch, DriveSheetCrud, DriveSheetConfig {
  @override
  final drive.DriveApi driveApi;
  @override
  final sheets.SheetsApi sheetsApi;
  @override
  final http.Client authClient;
  
  TestDriveService(this.driveApi, this.sheetsApi, this.authClient);

  @override
  Future<T> retryOp<T>(Future<T> Function() action, {int retries = 3}) async {
    int attempts = 0;
    while (attempts <= retries) {
      try {
        return await action();
      } catch (e) {
        attempts++;
        if (attempts > retries) rethrow;
      }
    }
    throw Exception('failed');
  }

  @override
  Future<String?> getFileId(String folderId, String fileName) async => 'mock_file_id';

  // Helper for tests that used the old private version
  String getColLetter(int index) => indexToColumn(index);
}

class TestDriveService2 with DriveSheetMixin, DriveSheetGviz, DriveSheetFetch, DriveSheetCrud, DriveSheetConfig {
  @override
  final drive.DriveApi driveApi;
  @override
  final sheets.SheetsApi sheetsApi;
  @override
  final http.Client authClient;
  
  TestDriveService2(this.driveApi, this.sheetsApi, this.authClient);

  @override
  Future<T> retryOp<T>(Future<T> Function() action, {int retries = 3}) async => await action();

  @override
  Future<String?> getFileId(String folderId, String fileName) async => null;

  // Helper for tests that used the old private version
  String getColLetter(int index) => indexToColumn(index);
}

void main() {
  late MockDriveApi mockDriveApi;
  late MockFilesResource mockFiles;
  late MockSheetsApi mockSheetsApi;
  late MockSpreadsheetsResource mockSpreadsheets;
  late MockValuesResource mockValues;
  late MockHttpClient mockHttpClient;
  late TestDriveService service;

  setUp(() {
    registerFallbackValue(sheets.ClearValuesRequest());
    registerFallbackValue(sheets.ValueRange());
    registerFallbackValue(sheets.Spreadsheet());
    registerFallbackValue(sheets.BatchUpdateSpreadsheetRequest());
    registerFallbackValue(sheets.BatchUpdateSpreadsheetResponse());
    registerFallbackValue(sheets.Request());
    registerFallbackValue(drive.File());
    registerFallbackValue(drive.DownloadOptions.fullMedia);
    registerFallbackValue(drive.Media(const Stream.empty(), 0));
    registerFallbackValue(Uri.parse('https://example.com'));

    mockDriveApi = MockDriveApi();
    mockFiles = MockFilesResource();
    mockSheetsApi = MockSheetsApi();
    mockSpreadsheets = MockSpreadsheetsResource();
    mockValues = MockValuesResource();
    mockHttpClient = MockHttpClient();
    
    service = TestDriveService(mockDriveApi, mockSheetsApi, mockHttpClient);

    when(() => mockDriveApi.files).thenReturn(mockFiles);
    when(() => mockSheetsApi.spreadsheets).thenReturn(mockSpreadsheets);
    when(() => mockSpreadsheets.values).thenReturn(mockValues);
    
    // Default metadata mock
    when(() => mockSpreadsheets.get(any(), ranges: any(named: 'ranges'), includeGridData: any(named: 'includeGridData')))
      .thenAnswer((_) async => sheets.Spreadsheet(
      sheets: [
        sheets.Sheet(properties: sheets.SheetProperties(title: 'Main', sheetId: 0)),
        sheets.Sheet(properties: sheets.SheetProperties(title: 'Sheet1', sheetId: 1)),
        sheets.Sheet(properties: sheets.SheetProperties(title: 'settings', sheetId: 2)),
        sheets.Sheet(properties: sheets.SheetProperties(title: 'meta', sheetId: 3)),
        sheets.Sheet(properties: sheets.SheetProperties(title: 'cards', sheetId: 4)),
      ],
    ));

    // Stub batchUpdate
    when(() => mockSpreadsheets.batchUpdate(any(), any())).thenAnswer((_) async => sheets.BatchUpdateSpreadsheetResponse());

    // Stub drive files update (for moving files/parents)
    when(() => mockFiles.update(any(), any(), 
      addParents: any(named: 'addParents'), 
      removeParents: any(named: 'removeParents'),
      enforceSingleParent: any(named: 'enforceSingleParent'),
      $fields: any(named: r'$fields'),
    )).thenAnswer((_) async => drive.File(id: 'updated_id'));

    // Stub drive files get (for parents)
    when(() => mockFiles.get(any(), $fields: any(named: r'$fields'), supportsAllDrives: any(named: 'supportsAllDrives')))
      .thenAnswer((_) async => drive.File(id: 'file_id', parents: ['root']));

    // Stub values get (default empty)
    when(() => mockValues.get(any(), any())).thenAnswer((_) async => sheets.ValueRange(values: []));
    when(() => mockValues.update(any(), any(), any(), valueInputOption: any(named: 'valueInputOption')))
      .thenAnswer((_) async => sheets.UpdateValuesResponse());
  });

  group('DriveSheetMixin', () {
    test('readSettingsById reads from sheets', () async {
      when(() => mockValues.get(any(), any())).thenAnswer((_) async => sheets.ValueRange(
        values: [['key1', '"value1"']]
      ));

      final settings = await service.readSettingsById('fileId');

      expect(settings, contains('key1'));
      expect(settings!['key1'], 'value1');
    });

    test('updateModuleConfig writes to settings sheet', () async {
      when(() => mockValues.clear(any(), any(), any())).thenAnswer((_) async => sheets.ClearValuesResponse());
      when(() => mockValues.update(any(), any(), any(), valueInputOption: any(named: 'valueInputOption')))
          .thenAnswer((_) async => sheets.UpdateValuesResponse());

      await service.updateModuleConfig('fileId', {
        'settings': {'s1': 'v1'},
      });

      // Expect one update for settings
      verify(() => mockValues.update(any(), any(), any(), valueInputOption: 'RAW')).called(1);
    });

    test('readTabsById parses tab configs from sheets', () async {
      when(() => mockSpreadsheets.get('tabs123')).thenAnswer((_) async => sheets.Spreadsheet(
        sheets: [sheets.Sheet(properties: sheets.SheetProperties(title: 'tabs'))]
      ));
      when(() => mockValues.get('tabs123', "'tabs'!A:B")).thenAnswer((_) async => sheets.ValueRange(
        values: [
          ['id', '"t1"'],
          ['label', '"Orders"'],
          ['columns', '[{"key":"name"}]']
        ]
      ));

      final tabs = await service.readTabsById('tabs123');

      expect(tabs, isNotNull);
      expect(tabs!.length, 1);
      expect(tabs[0]['id'], 't1');
    });

    test('readDashboardById parses cards from list format', () async {
      when(() => mockValues.get('db123', 'cards!A1:Z')).thenAnswer((_) async => sheets.ValueRange(
        values: [
          ['{"label":"KPI", "formula":"sum(A)"}']
        ]
      ));

      final result = await service.readDashboardById('db123');
      expect(result, isA<List>());
      final cards = result as List;
      expect(cards.length, 1);
      expect(cards[0]['label'], 'KPI');
    });

    test('writeTabsById updates tabs sheet', () async {
      when(() => mockSpreadsheets.get(any())).thenAnswer((_) async => sheets.Spreadsheet(
        sheets: [sheets.Sheet(properties: sheets.SheetProperties(title: 't1'))]
      ));
      when(() => mockValues.clear(any(), any(), any())).thenAnswer((_) async => sheets.ClearValuesResponse());
      when(() => mockValues.update(any(), any(), any(), valueInputOption: any(named: 'valueInputOption')))
          .thenAnswer((_) async => sheets.UpdateValuesResponse());

      final tabs = [
        TabConfig(id: 't1', label: 'T1', columns: [ColumnConfig(key: 'k1', label: 'L1', type: 'text')]).toJson()
      ];

      await service.writeTabsById('tabs123', tabs);

      verify(() => mockValues.update(any(), 'tabs123', 't1!A1', valueInputOption: 'RAW')).called(1);
    });

    test('createSpreadsheetInFolder creates and initializes a sheet', () async {
      when(() => mockFiles.create(any(), supportsAllDrives: any(named: 'supportsAllDrives')))
          .thenAnswer((_) async => drive.File()..id = 'new_sid');
      when(() => mockSpreadsheets.batchUpdate(any(), 'new_sid')).thenAnswer((_) async => sheets.BatchUpdateSpreadsheetResponse());

      final id = await service.createSpreadsheetInFolder('folder123', 'New Spreadsheet');

      expect(id, 'new_sid');
      verify(() => mockFiles.create(any(), supportsAllDrives: true)).called(1);
      verify(() => mockSpreadsheets.batchUpdate(any(), 'new_sid')).called(1);
    });

    test('createModuleConfig handles spreadsheet creation directly in folder', () async {
      when(() => mockFiles.create(any(), supportsAllDrives: any(named: 'supportsAllDrives')))
          .thenAnswer((_) async => drive.File()..id = 'new_sid');
      
      when(() => mockSpreadsheets.batchUpdate(any(), any())).thenAnswer((_) async => sheets.BatchUpdateSpreadsheetResponse());

      when(() => mockValues.clear(any(), any(), any())).thenAnswer((_) async => sheets.ClearValuesResponse());
      when(() => mockValues.update(any(), any(), any(), valueInputOption: any(named: 'valueInputOption')))
          .thenAnswer((_) async => sheets.UpdateValuesResponse());

      final ids = await service.createModuleConfig('folderId', 'fileName', {});

      expect(ids['settings'], 'new_sid');
      expect(ids['dashboard'], 'new_sid');
      expect(ids['tabs'], 'new_sid');
      // Should call driveApi.files.create for each of the 3 spreadsheets (settings, dashboard, tabs)
      verify(() => mockFiles.create(any(), supportsAllDrives: true)).called(3);
    });

    test('saveRecord handles nested tables and Prima data', () async {
       when(() => mockValues.get(any(), any())).thenAnswer((_) async => sheets.ValueRange());
       when(() => mockValues.append(any(), any(), any(), valueInputOption: any(named: 'valueInputOption')))
          .thenAnswer((_) async => sheets.AppendValuesResponse());
       when(() => mockSpreadsheets.get(any())).thenAnswer((_) async => sheets.Spreadsheet(
         sheets: [sheets.Sheet(properties: sheets.SheetProperties(title: 'Sheet1'))]
       ));
       when(() => mockSpreadsheets.batchUpdate(any(), any())).thenAnswer((_) async => sheets.BatchUpdateSpreadsheetResponse());

       await service.saveRecordBySpreadsheetId('mock_file_id', 'Sheet1', {
         'field1': 'val1',
         'nested': [{'col1': 'v1'}], // Nested table
         'list': ['a', 'b'], // List field
       });

       // Should call append for main record AND nested table
       verify(() => mockValues.append(any(), any(), any(), valueInputOption: 'RAW')).called(greaterThan(1));
    });

    test('saveRecordBySpreadsheetId adds new columns when data has extra keys', () async {
      when(() => mockValues.get(any(), "'Sheet1'!A1:ZZ1"))
          .thenAnswer((_) async => sheets.ValueRange(values: [['record_id']]));
      when(() => mockValues.get(any(), any(that: contains('A:A'))))
          .thenAnswer((_) async => sheets.ValueRange(values: [['record_id']]));
      when(() => mockValues.update(any(), any(), any(), valueInputOption: any(named: 'valueInputOption')))
          .thenAnswer((_) async => sheets.UpdateValuesResponse());
      when(() => mockValues.append(any(), any(), any(), valueInputOption: any(named: 'valueInputOption'), insertDataOption: any(named: 'insertDataOption')))
          .thenAnswer((_) async => sheets.AppendValuesResponse());

      final data = {'record_id': 'r_new', 'new_col': 'val'};
      await service.saveRecordBySpreadsheetId('mock_file_id', 'Sheet1', data);

      verify(() => mockValues.update(any(), 'mock_file_id', "'Sheet1'!A1", valueInputOption: 'RAW')).called(1);
    });

    test('fetchRecords handles sub-tables and joining', () async {
       when(() => mockSpreadsheets.get(any())).thenAnswer((_) async => sheets.Spreadsheet(
         sheets: [
           sheets.Sheet(properties: sheets.SheetProperties(title: 'Main')),
           sheets.Sheet(properties: sheets.SheetProperties(title: 'Main.subs')),
         ]
       ));

       when(() => mockValues.get(any(), any())).thenAnswer((inv) async {
         final range = inv.positionalArguments[1] as String;
         if (range.contains('Main.subs')) {
           if (range.contains('1:1')) return sheets.ValueRange(values: [['parent_record_id', 'sub_field']]);
           return sheets.ValueRange(values: [['parent_record_id', 'sub_field'], ['r1', 'sub_val']]);
         } else {
           if (range.contains('1:1')) return sheets.ValueRange(values: [['record_id', 'field1']]);
           return sheets.ValueRange(values: [['record_id', 'field1'], ['r1', 'val1']]);
         }
       });

       final results = await service.fetchRecords('folderId', 'Spreadsheet', 'Main');
       expect(results, isNotEmpty);
       expect(results.first.containsKey('subs'), isTrue);
    });

    test('fetchRecords falls back to local fetch if Gviz/search fails', () async {
      // Stub metadata
      when(() => mockSpreadsheets.get(any())).thenAnswer((_) async => sheets.Spreadsheet(
        sheets: [sheets.Sheet(properties: sheets.SheetProperties(title: 'Main'))]
      ));

      // Mock value range for local fetch
      when(() => mockValues.get(any(), any())).thenAnswer((inv) async {
         final range = inv.positionalArguments[1] as String;
         if (range.contains('1:1')) return sheets.ValueRange(values: [['record_id', 'name']]);
         return sheets.ValueRange(values: [['record_id', 'name'], ['r1', 'Match'], ['r2', 'Other']]);
      });

      // DriveSheetGviz should fail (mocked by not providing a valid response for http client)
      when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
          .thenThrow(Exception('Gviz failed'));

      // Fetch with search query
      final results = await service.fetchRecords(
        'folder', 'Spreadsheet', 'Main', 
        searchQuery: 'Match', 
        fetchSubTables: false
      );

      expect(results.length, 1);
      expect(results.first['name'], 'Match');
    });

    test('saveRecord adds new columns when data has extra keys', () async {
       when(() => mockValues.get(any(), any())).thenAnswer((_) async => sheets.ValueRange(
         values: [['field1']]
       ));
       when(() => mockValues.update(any(), any(), any(), valueInputOption: any(named: 'valueInputOption')))
          .thenAnswer((_) async => sheets.UpdateValuesResponse());
       when(() => mockValues.append(any(), any(), any(), valueInputOption: any(named: 'valueInputOption')))
          .thenAnswer((_) async => sheets.AppendValuesResponse());
       when(() => mockSpreadsheets.get(any())).thenAnswer((_) async => sheets.Spreadsheet(
         sheets: [sheets.Sheet(properties: sheets.SheetProperties(title: 'Sheet1'))]
       ));

       await service.saveRecordBySpreadsheetId('mock_file_id', 'Sheet1', {
         'field1': 'val1',
         'field2': 'val2', // New column
       });

       verify(() => mockValues.update(any(), any(), any(), valueInputOption: 'RAW')).called(1);
    });

    test('_readMapFromSheet handles various row lengths and errors', () async {
      when(() => mockValues.get(any(), any())).thenAnswer((_) async => sheets.ValueRange(
        values: [
          ['key1', '"val1"'],
          ['key2'], // too short
          ['key3', '"val3"', 'extra'] 
        ]
      ));

      final settings = await service.readSettingsById('fileId');
      // key2 should be ignored because it has < 2 elements
      expect(settings!.length, 2); 
    });

    test('retryOp fails after retries', () async {
      int calls = 0;
      try {
        await service.retryOp(() async {
          calls++;
          throw Exception('fail');
        }, retries: 2);
      } catch (_) {}
      expect(calls, 3); // initial + 2 retries
    });

    test('fetchRecords handles search and quickFilter in Gviz', () async {
      // Mock headers fetch
      when(() => mockValues.get(any(), any())).thenAnswer((_) async => sheets.ValueRange(
        values: [['name', 'age']]
      ));

      // Mock metadata response (discovery)
      const gvizMeta = '/*-google-javascript-data-lite-*/google.visualization.Query.setResponse({"status":"ok","table":{"cols":[{"id":"A","label":"name","type":"string"},{"id":"B","label":"age","type":"number"}],"rows":[]}});';
      
      // Mock data response
      const gvizData = '/*-google-javascript-data-lite-*/google.visualization.Query.setResponse({"status":"ok","table":{"cols":[{"id":"A","label":"name","type":"string"}],"rows":[{"c":[{"v":"Alice"}]}]}});';

      String? capturedUrl;
      when(() => mockHttpClient.get(any())).thenAnswer((inv) async {
         capturedUrl = (inv.positionalArguments[0] as Uri).toString();
         if (capturedUrl!.contains('LIMIT%200')) return http.Response(gvizMeta, 200);
         return http.Response(gvizData, 200);
      });

      await service.fetchRecords(
        'f1', 's1', 'Main',
        searchQuery: 'ali',
        quickFilter: QuickFilter(label: 'Gold', key: 'g', field: 'age', operator: '>=', value: 30).toJson()
      );

      // Verify URL contains search and filter
      final decodedUrl = Uri.decodeFull(capturedUrl!);
      expect(decodedUrl, contains("lower(A) contains 'ali'"));
      expect(decodedUrl, contains("B >= 30"));
    });

    test('fetchRecords falls back to local filter if Gviz fails', () async {
      // Mock headers fetch
      when(() => mockValues.get(any(), any())).thenAnswer((inv) async {
        final range = inv.positionalArguments[1] as String;
        if (range.contains('A1:ZZ1')) return sheets.ValueRange(values: [['name', 'age']]);
        return sheets.ValueRange(values: [
          ['Alice', '30'],
          ['Bob', '25'],
        ]);
      });

      // Mock Gviz error response
      when(() => mockHttpClient.get(any())).thenAnswer((_) async => 
        http.Response('/*-google-javascript-data-lite-*/google.visualization.Query.setResponse({"status":"error","errors":[{"reason":"invalid_query"}]});', 200)
      );

      // Search for 'ali' should return Alice only
      final results = await service.fetchRecords('f1', 's1', 'Main', searchQuery: 'ali');
      
      expect(results.length, 1);
      expect(results.first['name'], 'Alice');
    });

    test('Gviz metadata discovery handles network error', () async {
      // Mock headers fetch
      when(() => mockValues.get(any(), any())).thenAnswer((inv) async {
        final range = inv.positionalArguments[1] as String;
        if (range.contains('A1:ZZ1')) return sheets.ValueRange(values: [['name']]);
        return sheets.ValueRange(values: [['Alice']]);
      });

      when(() => mockHttpClient.get(any())).thenThrow(Exception('Network error'));
      
      final results = await service.fetchRecords('f1', 's1', 'Main');
      expect(results.length, 1);
      expect(results.first['name'], 'Alice');
    });

    test('fetchRecords with endsWith operator', () async {
        // Mock headers fetch
        when(() => mockValues.get(any(), any())).thenAnswer((_) async => sheets.ValueRange(
          values: [['email']]
        ));

        const gvizMeta = '/*-google-javascript-data-lite-*/google.visualization.Query.setResponse({"status":"ok","table":{"cols":[{"id":"A","label":"email","type":"string"}],"rows":[]}});';
        const gvizData = '/*-google-javascript-data-lite-*/google.visualization.Query.setResponse({"status":"ok","table":{"cols":[{"id":"A","label":"email","type":"string"}],"rows":[]}});';

        String? capturedUrl;
        when(() => mockHttpClient.get(any())).thenAnswer((inv) async {
            capturedUrl = (inv.positionalArguments[0] as Uri).toString();
            if (capturedUrl!.contains('LIMIT%200')) return http.Response(gvizMeta, 200);
            return http.Response(gvizData, 200);
        });

        await service.fetchRecords(
            'f1', 's1', 'Main',
            quickFilter: QuickFilter(label: 'L', key: 'k', field: 'email', operator: 'endsWith', value: '@gmail.com').toJson()
        );

        final decodedUrl = Uri.decodeFull(capturedUrl!);
        expect(decodedUrl, contains("lower(A) ends with '@gmail.com'"));
    });

    test('DriveSheetMixin saveRecord updates existing record if record_id matches', () async {
      // Mock headers
      when(() => mockValues.get(any(), "'Sheet1'!A1:ZZ1"))
          .thenAnswer((_) async => sheets.ValueRange(values: [['record_id', 'name']]));
      
      // Mock finding the record ID in the sheet. 
      // The code calls 'Sheet1'!A:A (or similar for the id column)
      when(() => mockValues.get(any(), any(that: contains('A:A'))))
          .thenAnswer((_) async => sheets.ValueRange(values: [['record_id'], ['r1']]));

      when(() => mockValues.update(any(), any(), any(), valueInputOption: 'RAW'))
          .thenAnswer((_) async => sheets.UpdateValuesResponse());

      final data = {'record_id': 'r1', 'name': 'Updated Name'};
      
      await service.saveRecordBySpreadsheetId('mock_file_id', 'Sheet1', data);

      // Verify update was called instead of append
      verify(() => mockValues.update(
        any(), 
        any(), 
        "'Sheet1'!2:2", 
        valueInputOption: 'RAW'
      )).called(1);
      
      verifyNever(() => mockValues.append(any(), any(), any(), valueInputOption: 'RAW'));
    });

    test('saveRecordsBatchBySpreadsheetId appends multiple records', () async {
      when(() => mockSpreadsheets.get(any())).thenAnswer((_) async => sheets.Spreadsheet(
        sheets: [sheets.Sheet(properties: sheets.SheetProperties(title: 'Sheet1'))]
      ));
      
      when(() => mockValues.get(any(), any())).thenAnswer((_) async => sheets.ValueRange(values: [['record_id', 'name']]));
      
      when(() => mockValues.append(any(), any(), any(), 
        valueInputOption: any(named: 'valueInputOption'), 
        insertDataOption: any(named: 'insertDataOption')
      )).thenAnswer((_) async => sheets.AppendValuesResponse());

      final records = [
        {'name': 'R1'},
        {'name': 'R2'},
      ];

      await service.saveRecordsBatchBySpreadsheetId('mock_file_id', 'Sheet1', records);

      // Should call append once for main records
      verify(() => mockValues.append(
        any(that: predicate<sheets.ValueRange>((vr) => vr.values?.length == 2)), 
        'mock_file_id', 
        'Sheet1!A1', 
        valueInputOption: 'RAW', 
        insertDataOption: 'INSERT_ROWS'
      )).called(1);
    });

    test('DriveSheetMixin deleteRecord calls batchUpdate with deleteDimension', () async {
      // Mock headers
      when(() => mockValues.get(any(), "'Sheet1'!A1:ZZ1"))
          .thenAnswer((_) async => sheets.ValueRange(values: [['record_id']]));
      
      // Mock finding IDs
      when(() => mockValues.get(any(), any()))
          .thenAnswer((_) async => sheets.ValueRange(values: [['record_id'], ['r1'], ['r2']]));
      
      // Mock spreadsheet metadata for GID
      when(() => mockSpreadsheets.get(any())).thenAnswer((_) async => sheets.Spreadsheet(
        sheets: [
          sheets.Sheet(properties: sheets.SheetProperties(title: 'Sheet1', sheetId: 100))
        ]
      ));

      when(() => mockSpreadsheets.batchUpdate(any(), any()))
          .thenAnswer((_) async => sheets.BatchUpdateSpreadsheetResponse());

      await service.deleteRecordBySpreadsheetId('mock_file_id', 'Sheet1', 'r2');

      // Index for r2 is 2 (3rd row including header, but 0-indexed index for list is 2)
      verify(() => mockSpreadsheets.batchUpdate(
        any(that: predicate<sheets.BatchUpdateSpreadsheetRequest>((req) {
          final del = req.requests?.first.deleteDimension;
          return del?.range?.startIndex == 2 && del?.range?.endIndex == 3 && del?.range?.sheetId == 100;
        })), 
        any()
      )).called(1);
    });

    test('executeGvizQuery returns scalar value', () async {
      when(() => mockHttpClient.get(any())).thenAnswer((_) async {
        return http.Response(
            'google.visualization.Query.setResponse({"version":"0.6","status":"ok","table":{"cols":[{"id":"count","label":"count","type":"number"}],"rows":[{"c":[{"v":42.0}]}]}});', 
            200
        );
      });

      final result = await service.executeGvizQuery('folder', 'File', 'SELECT count(A)');
      
      expect(result, 42.0);
      
      verify(() => mockHttpClient.get(
        any(that: predicate<Uri>((uri) => uri.toString().contains('tq=SELECT%20count(A)')))
      )).called(1);
    });

    test('executeGvizQuery returns null on empty rows', () async {
      when(() => mockHttpClient.get(any())).thenAnswer((_) async {
        return http.Response(
            'google.visualization.Query.setResponse({"version":"0.6","status":"ok","table":{"cols":[],"rows":[]}});', 
            200
        );
      });

      final result = await service.executeGvizQuery('folder', 'File', 'SELECT count(A)');
      expect(result, isNull);
    });

    test('executeGvizTableQuery returns list of maps', () async {
      when(() => mockHttpClient.get(any())).thenAnswer((_) async {
        return http.Response(
            'google.visualization.Query.setResponse({"version":"0.6","status":"ok","table":{"cols":[{"label":"Date"},{"label":"Value"}],"rows":[{"c":[{"v":"Jan"},{"v":100}]},{"c":[{"v":"Feb"},{"v":200}]}]}});', 
            200
        );
      });

      final result = await service.executeGvizTableQuery('folder', 'File', 'SELECT A, B');
      
      expect(result, isNotNull);
      expect(result!.length, 2);
      expect(result[0]['Date'], 'Jan');
      expect(result[0]['Value'], 100);
      expect(result[1]['Value'], 200);
    });
  });
}
