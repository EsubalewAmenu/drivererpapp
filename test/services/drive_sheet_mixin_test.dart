import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis/sheets/v4.dart' as sheets;

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:drivererpapp/services/drive/drive_sheet/mixin.dart';
import 'package:drivererpapp/services/drive/drive_sheet/gviz.dart';

// Mocks
class MockSheetsApi extends Mock implements sheets.SheetsApi {}
class MockSpreadsheetsResourceApi extends Mock implements sheets.SpreadsheetsResource {}
class MockAuthClient extends Mock implements http.Client {}

// Minimal test implementation that mixes in DriveSheetMixin
class TestDriveSheetService with DriveSheetMixin, DriveSheetGviz {
  final MockSheetsApi sheetsApiImpl;
  final MockSpreadsheetsResourceApi spreadsheetsResource;
  final MockAuthClient authClientImpl;
  TestDriveSheetService(this.sheetsApiImpl, this.spreadsheetsResource, this.authClientImpl) {
    when(() => sheetsApiImpl.spreadsheets).thenReturn(spreadsheetsResource);
  }

  @override
  Future<T> retryOp<T>(Future<T> Function() action, {int retries = 3}) async {
    return action();
  }

  @override
  http.Client get authClient => authClientImpl;

  @override
  sheets.SheetsApi get sheetsApi => sheetsApiImpl;

  @override
  drive.DriveApi get driveApi => throw UnimplementedError();

  @override
  Future<String?> getFileId(String folderId, String fileName) async {
    // return a fixed spreadsheet id for tests
    if (folderId == 'folder' && fileName == 'sheet') return 'sp1';
    return null;
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });
  group('DriveSheetMixin - GViz', () {
    late MockSheetsApi mockSheetsApi;
    late MockSpreadsheetsResourceApi mockSpreadsheetsRes;
    late MockAuthClient mockAuth;
    late TestDriveSheetService svc;

    setUp(() {
      mockSheetsApi = MockSheetsApi();
      mockSpreadsheetsRes = MockSpreadsheetsResourceApi();
      mockAuth = MockAuthClient();
      svc = TestDriveSheetService(mockSheetsApi, mockSpreadsheetsRes, mockAuth);
    });

    test('executeGvizQuery returns first cell value', () async {
      // Arrange: spreadsheets.get should return a Sheets spreadsheet with one sheet
      final ss = sheets.Spreadsheet(
        sheets: [
          sheets.Sheet(properties: sheets.SheetProperties(title: 'sheet', sheetId: 0)),
        ],
      );

      when(() => mockSpreadsheetsRes.get('sp1')).thenAnswer((_) async => ss);

      // Build GViz response body with JSON wrapper
      final payload = jsonEncode({
        'table': {
          'rows': [
            {'c': [ {'v': 123} ]}
          ]
        }
      });
      final body = '/*Omit*/$payload/*End*/';

      when(() => mockAuth.get(any())).thenAnswer((_) async => http.Response(body, 200));

      // Act
      final res = await svc.executeGvizQuery('folder', 'sheet', 'SELECT 1');

      // Assert
      expect(res, 123);
    });

    test('executeGvizTableQuery returns parsed table rows', () async {
      final ss = sheets.Spreadsheet(
        sheets: [
          sheets.Sheet(properties: sheets.SheetProperties(title: 'sheet', sheetId: 0)),
        ],
      );
      when(() => mockSpreadsheetsRes.get('sp1')).thenAnswer((_) async => ss);

      final payload = jsonEncode({
        'table': {
          'cols': [ {'label': 'Name'}, {'label': 'Value'} ],
          'rows': [
            {'c': [ {'v': 'Alice', 'f': 'Alice'}, {'v': 10} ]},
            {'c': [ {'v': 'Bob'}, {'v': 20} ]}
          ]
        }
      });
      final body = 'XXX$payload';
      when(() => mockAuth.get(any())).thenAnswer((_) async => http.Response(body, 200));

      final res = await svc.executeGvizTableQuery('folder', 'sheet', 'SELECT *');
      expect(res, isNotNull);
      expect(res, isA<List<Map<String, dynamic>>>());
      expect(res!.length, 2);
      expect(res[0]['Name'], 'Alice');
      expect(res[0]['Value'], 10);
      expect(res[0]['Name_f'], 'Alice');
    });
  });
}
