import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:drivererpapp/services/drive/drive_sheet_mixin.dart';
import 'package:drivererpapp/models/schema_models.dart';

class MockDriveApi extends Mock implements drive.DriveApi {}
class MockFilesResource extends Mock implements drive.FilesResource {}
class MockSheetsApi extends Mock implements sheets.SheetsApi {}
class MockSpreadsheetsResource extends Mock implements sheets.SpreadsheetsResource {}
class MockValuesResource extends Mock implements sheets.SpreadsheetsValuesResource {}
class MockHttpClient extends Mock implements http.Client {}

class TestDriveService with DriveSheetMixin {
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
}

class TestDriveService2 with DriveSheetMixin {
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
    when(() => mockSpreadsheets.get(any())).thenAnswer((_) async => sheets.Spreadsheet(
      sheets: [
        sheets.Sheet(properties: sheets.SheetProperties(title: 'Main', sheetId: 0)),
        sheets.Sheet(properties: sheets.SheetProperties(title: 'Sheet1', sheetId: 1)),
      ],
    ));

    registerFallbackValue(sheets.ClearValuesRequest());
    registerFallbackValue(sheets.ValueRange());
    registerFallbackValue(sheets.Spreadsheet());
    registerFallbackValue(sheets.BatchUpdateSpreadsheetRequest());
    registerFallbackValue(sheets.Request());
    registerFallbackValue(drive.File());
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  group('DriveSheetMixin', () {
    test('readModuleConfig reads from sheets', () async {
      when(() => mockValues.get(any(), any())).thenAnswer((_) async => sheets.ValueRange(
        values: [['key1', '"value1"']]
      ));

      final config = await service.readModuleConfig('fileId');

      expect(config!['settings'], contains('key1'));
      expect(config['settings']['key1'], 'value1');
    });

    test('updateModuleConfig writes to sheets', () async {
      when(() => mockValues.clear(any(), any(), any())).thenAnswer((_) async => sheets.ClearValuesResponse());
      when(() => mockValues.update(any(), any(), any(), valueInputOption: any(named: 'valueInputOption')))
          .thenAnswer((_) async => sheets.UpdateValuesResponse());

      await service.updateModuleConfig('fileId', {
        'settings': {'s1': 'v1'},
        'dashboard': {'cards': []},
        'tabs': [{'id': 't1', 'label': 'T1', 'columns': []}],
      });

      verify(() => mockValues.update(any(), any(), any(), valueInputOption: 'RAW')).called(3);
    });

    test('createModuleConfig handles spreadsheet creation and moving', () async {
      when(() => mockSpreadsheets.create(any())).thenAnswer((_) async => sheets.Spreadsheet(spreadsheetId: 'new_sid'));
      when(() => mockFiles.get(any(), $fields: any(named: '\$fields'))).thenAnswer((_) async => drive.File(parents: ['p1']));
      when(() => mockFiles.update(any(), any(), addParents: any(named: 'addParents'), removeParents: any(named: 'removeParents'), $fields: any(named: '\$fields')))
          .thenAnswer((_) async => drive.File());
      
      when(() => mockValues.clear(any(), any(), any())).thenAnswer((_) async => sheets.ClearValuesResponse());
      when(() => mockValues.update(any(), any(), any(), valueInputOption: any(named: 'valueInputOption')))
          .thenAnswer((_) async => sheets.UpdateValuesResponse());

      final id = await service.createModuleConfig('folderId', 'fileName', {});
      
      expect(id, 'new_sid');
      verify(() => mockSpreadsheets.create(any())).called(1);
      verify(() => mockFiles.update(any(), 'new_sid', addParents: 'folderId', removeParents: 'p1', $fields: any(named: '\$fields'))).called(1);
    });

    test('saveRecord handles nested tables and Prima data', () async {
       when(() => mockValues.get(any(), any())).thenAnswer((_) async => sheets.ValueRange());
       when(() => mockValues.append(any(), any(), any(), valueInputOption: any(named: 'valueInputOption')))
          .thenAnswer((_) async => sheets.AppendValuesResponse());
       when(() => mockSpreadsheets.get(any())).thenAnswer((_) async => sheets.Spreadsheet(
         sheets: [sheets.Sheet(properties: sheets.SheetProperties(title: 'Sheet1'))]
       ));
       when(() => mockSpreadsheets.batchUpdate(any(), any())).thenAnswer((_) async => sheets.BatchUpdateSpreadsheetResponse());

       await service.saveRecord('folderId', 'spreadsheetName', 'Sheet1', {
         'field1': 'val1',
         'nested': [{'col1': 'v1'}], // Nested table
         'list': ['a', 'b'], // List field
       });

       // Should call append for main record AND nested table
       verify(() => mockValues.append(any(), any(), any(), valueInputOption: 'RAW')).called(greaterThan(1));
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

       await service.saveRecord('folderId', 'spreadsheetName', 'Sheet1', {
         'field1': 'val1',
         'field2': 'val2', // New column
       });

       verify(() => mockValues.update(any(), any(), any(), valueInputOption: 'RAW')).called(1);
    });

    test('readModuleConfig parses settings and tabs', () async {
      when(() => mockValues.get(any(), any())).thenAnswer((_) async => sheets.ValueRange(
        values: [['key', '"val"'], ['key2', '123']]
      ));

      final result = await service.readModuleConfig('file_id');
      expect(result!['settings'], isNotNull);
      expect(result['tabs'], isNotNull);
    });

    test('updateModuleConfig writes to sheets', () async {
      when(() => mockValues.clear(any(), any(), any())).thenAnswer((_) async => sheets.ClearValuesResponse());
      when(() => mockValues.update(any(), any(), any(), valueInputOption: any(named: 'valueInputOption')))
          .thenAnswer((_) async => sheets.UpdateValuesResponse());

      await service.updateModuleConfig('file_id', {
        'settings': <String, dynamic>{'a': 1},
        'tabs': <dynamic>[], 
        'dashboard': <String, dynamic>{},
        'metadata': <String, dynamic>{}
      });
      verify(() => mockValues.update(any(), any(), any(), valueInputOption: 'RAW')).called(greaterThan(0));
    });

    test('saveRecord creates new spreadsheet if not exists', () async {
      // Create a service that returns null for getFileId
      final mockDriveApi2 = MockDriveApi();
      final mockFiles2 = MockFilesResource();
      final mockSheetsApi2 = MockSheetsApi();
      final mockSpreadsheets2 = MockSpreadsheetsResource();
      final mockValues2 = MockValuesResource();
      
      when(() => mockDriveApi2.files).thenReturn(mockFiles2);
      when(() => mockSheetsApi2.spreadsheets).thenReturn(mockSpreadsheets2);
      when(() => mockSpreadsheets2.values).thenReturn(mockValues2);

      final service2 = TestDriveService2(mockDriveApi2, mockSheetsApi2, mockHttpClient);

      when(() => mockSpreadsheets2.create(any())).thenAnswer((_) async => sheets.Spreadsheet(spreadsheetId: 'new_sid'));
      when(() => mockFiles2.get(any(), $fields: any(named: '\$fields'))).thenAnswer((_) async => drive.File(id: 'new_sid', parents: []));
      when(() => mockFiles2.update(any(), any(), addParents: any(named: 'addParents'), removeParents: any(named: 'removeParents'), $fields: any(named: '\$fields')))
          .thenAnswer((_) async => drive.File());
      // For appendDataToSheet
      when(() => mockSpreadsheets2.get(any())).thenAnswer((_) async => sheets.Spreadsheet(sheets: []));
      when(() => mockSpreadsheets2.batchUpdate(any(), any())).thenAnswer((_) async => sheets.BatchUpdateSpreadsheetResponse());
      when(() => mockValues2.get(any(), any())).thenAnswer((_) async => sheets.ValueRange(values: []));
      when(() => mockValues2.append(any(), any(), any(), valueInputOption: any(named: 'valueInputOption')))
          .thenAnswer((_) async => sheets.AppendValuesResponse());

      await service2.saveRecord('folderId', 'spreadsheetName', 'Sheet1', {'a': 1});

      verify(() => mockSpreadsheets2.create(any())).called(1);
      verify(() => mockFiles2.update(any(), 'new_sid', addParents: 'folderId', $fields: any(named: '\$fields'))).called(1);
    });

    test('fetchRecords handles descending sort and pagination', () async {
      when(() => mockSpreadsheets.get(any())).thenAnswer((_) async => sheets.Spreadsheet(
        sheets: [sheets.Sheet(properties: sheets.SheetProperties(title: 'Main'))]
      ));

      when(() => mockValues.get(any(), any())).thenAnswer((inv) async {
        final range = inv.positionalArguments[1] as String;
        if (range.contains('1:1')) return sheets.ValueRange(values: [['record_id', 'val']]);
        return sheets.ValueRange(values: [
          ['100', 'v100'],
          ['101', 'v101'],
          ['102', 'v102'],
        ]);
      });

      // Gviz metadata mock (for column types)
      final gvizMeta = '/*-google-javascript-data-lite-*/google.visualization.Query.setResponse({"status":"ok","table":{"cols":[{"id":"A","label":"record_id","type":"string"},{"id":"B","label":"h2","type":"string"}],"rows":[]}});';
      
      // Gviz data mock for paginated result (LIMIT 1 OFFSET 1 on 102, 101, 100)
      final gvizData = '/*-google-javascript-data-lite-*/google.visualization.Query.setResponse({"status":"ok","table":{"cols":[{"id":"A","label":"record_id","type":"string"},{"id":"B","label":"h2","type":"string"}],"rows":[{"c":[{"v":"101"},{"v":"v101"}]}]}});';

      when(() => mockHttpClient.get(any())).thenAnswer((inv) async {
         final url = (inv.positionalArguments[0] as Uri).toString();
         if (url.contains('SELECT%20*%20LIMIT%200')) {
           return http.Response(gvizMeta, 200);
         }
         return http.Response(gvizData, 200);
      });

      // Descending should sort by record_id (strings)
      final results = await service.fetchRecords('folderId', 'Spreadsheet', 'Main', descending: true, offset: 1, limit: 1);
      
      expect(results.length, 1);
      expect(results.first['record_id'], '101'); // 102, 101, 100 -> skip 1 -> 101
    });

    test('_fetchSheetData handles empty rows and mismatched columns', () async {
      when(() => mockValues.get(any(), any())).thenAnswer((inv) async {
        final range = inv.positionalArguments[1] as String;
        if (range.contains('1:1')) return sheets.ValueRange(values: [['h1', 'h2']]);
        return sheets.ValueRange(values: [
          ['v1', 'v2'],
          ['v3'], // missing column
          ['', ''], // empty row
        ]);
      });

      final results = await service.fetchRecords('folderId', 'Spreadsheet', 'Main', fetchSubTables: false);
      expect(results.length, 2);
      expect(results[1]['h2'], isNull);
    });

    test('_readMapFromSheet handles various row lengths and errors', () async {
      when(() => mockValues.get(any(), any())).thenAnswer((_) async => sheets.ValueRange(
        values: [
          ['key1', '"val1"'],
          ['key2'], // too short
          ['key3', '"val3"', 'extra'] 
        ]
      ));

      final config = await service.readModuleConfig('fileId');
      // key2 should be ignored because it has < 2 elements
      expect(config!['settings'].length, 2); 
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
      final gvizMeta = '/*-google-javascript-data-lite-*/google.visualization.Query.setResponse({"status":"ok","table":{"cols":[{"id":"A","label":"name","type":"string"},{"id":"B","label":"age","type":"number"}],"rows":[]}});';
      
      // Mock data response
      final gvizData = '/*-google-javascript-data-lite-*/google.visualization.Query.setResponse({"status":"ok","table":{"cols":[{"id":"A","label":"name","type":"string"}],"rows":[{"c":[{"v":"Alice"}]}]}});';

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
        if (range.contains('1:1')) return sheets.ValueRange(values: [['name', 'age']]);
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
        if (range.contains('1:1')) return sheets.ValueRange(values: [['name']]);
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

        final gvizMeta = '/*-google-javascript-data-lite-*/google.visualization.Query.setResponse({"status":"ok","table":{"cols":[{"id":"A","label":"email","type":"string"}],"rows":[]}});';
        final gvizData = '/*-google-javascript-data-lite-*/google.visualization.Query.setResponse({"status":"ok","table":{"cols":[{"id":"A","label":"email","type":"string"}],"rows":[]}});';

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
      when(() => mockValues.get(any(), 'Sheet1!1:1'))
          .thenAnswer((_) async => sheets.ValueRange(values: [['record_id', 'name']]));
      
      // Mock finding the record ID in the sheet
      // Headers are at row 1. record_id 'r1' is at row 2.
      when(() => mockValues.get(any(), 'Sheet1!A:A'))
          .thenAnswer((_) async => sheets.ValueRange(values: [['record_id'], ['r1']]));

      when(() => mockValues.update(any(), any(), any(), valueInputOption: 'RAW'))
          .thenAnswer((_) async => sheets.UpdateValuesResponse());

      final data = {'record_id': 'r1', 'name': 'Updated Name'};
      
      await service.saveRecord('f1', 's1', 'Sheet1', data);

      // Verify update was called instead of append
      verify(() => mockValues.update(
        any(), 
        any(), 
        'Sheet1!2:2', 
        valueInputOption: 'RAW'
      )).called(1);
      
      verifyNever(() => mockValues.append(any(), any(), any(), valueInputOption: 'RAW'));
    });

    test('DriveSheetMixin deleteRecord calls batchUpdate with deleteDimension', () async {
      // Mock headers
      when(() => mockValues.get(any(), 'Sheet1!1:1'))
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

      await service.deleteRecord('f1', 's1', 'Sheet1', 'r2');

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
