import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:drivererpapp/services/drive/drive_sheet_mixin.dart';

class MockDriveApi extends Mock implements drive.DriveApi {}
class MockFilesResource extends Mock implements drive.FilesResource {}
class MockSheetsApi extends Mock implements sheets.SheetsApi {}
class MockSpreadsheetsResource extends Mock implements sheets.SpreadsheetsResource {}
class MockValuesResource extends Mock implements sheets.SpreadsheetsValuesResource {}

class TestDriveService with DriveSheetMixin {
  @override
  final drive.DriveApi driveApi;
  @override
  final sheets.SheetsApi sheetsApi;
  
  TestDriveService(this.driveApi, this.sheetsApi);

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
  
  TestDriveService2(this.driveApi, this.sheetsApi);

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
  late TestDriveService service;

  setUp(() {
    mockDriveApi = MockDriveApi();
    mockFiles = MockFilesResource();
    mockSheetsApi = MockSheetsApi();
    mockSpreadsheets = MockSpreadsheetsResource();
    mockValues = MockValuesResource();
    service = TestDriveService(mockDriveApi, mockSheetsApi);

    when(() => mockDriveApi.files).thenReturn(mockFiles);
    when(() => mockSheetsApi.spreadsheets).thenReturn(mockSpreadsheets);
    when(() => mockSpreadsheets.values).thenReturn(mockValues);

    registerFallbackValue(sheets.ClearValuesRequest());
    registerFallbackValue(sheets.ValueRange());
    registerFallbackValue(sheets.Spreadsheet());
    registerFallbackValue(sheets.BatchUpdateSpreadsheetRequest());
    registerFallbackValue(sheets.Request());
    registerFallbackValue(drive.File());
  });

  group('DriveSheetMixin', () {
    test('readModuleConfig reads from sheets', () async {
      when(() => mockValues.get(any(), any())).thenAnswer((_) async => sheets.ValueRange(
        values: [['key1', '"value1"']]
      ));

      final config = await service.readModuleConfig('fileId');

      expect(config['settings'], contains('key1'));
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
      expect(result['settings'], isNotNull);
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

      final service2 = TestDriveService2(mockDriveApi2, mockSheetsApi2);

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
      expect(config['settings'].length, 2); 
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
  });
}
