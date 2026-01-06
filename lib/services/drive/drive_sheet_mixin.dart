import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;

mixin DriveSheetMixin {
  drive.DriveApi get driveApi;
  sheets.SheetsApi get sheetsApi;
  Future<T> retryOp<T>(Future<T> Function() action, {int retries = 3});
  Future<String?> getFileId(String folderId, String fileName);

  /// Creates a Google Sheet for configuration with multiple sheets.
  Future<String> createModuleConfig(String folderId, String fileName, Map<String, dynamic> config) async {
    try {
      // 1. Create Spreadsheet with specific sheets
      final spreadsheet = sheets.Spreadsheet(
        properties: sheets.SpreadsheetProperties(title: fileName),
        sheets: [
          sheets.Sheet(properties: sheets.SheetProperties(title: 'settings')),
          sheets.Sheet(properties: sheets.SheetProperties(title: 'dashboard')),
          sheets.Sheet(properties: sheets.SheetProperties(title: 'tabs')),
        ],
      );
      
      final created = await sheetsApi.spreadsheets.create(spreadsheet);
      final fileId = created.spreadsheetId!;
      debugPrint('Created spreadsheet: $fileName ($fileId)');

      // 2. Move to folder
      final file = await driveApi.files.get(fileId, $fields: 'parents') as drive.File;
      final previousParents = file.parents?.join(',') ?? '';
      
      await driveApi.files.update(
        drive.File(), 
        fileId, 
        addParents: folderId, 
        removeParents: previousParents,
        $fields: 'id, parents',
      );
      debugPrint('Moved spreadsheet to folder: $folderId');

      // 3. Write data
      await updateModuleConfig(fileId, config);
      
      return fileId;
    } catch (e) {
      debugPrint('Error creating module config: $e');
      rethrow;
    }
  }

  /// Updates the module configuration in the spreadsheet.
  Future<void> updateModuleConfig(String fileId, Map<String, dynamic> config) async {
     // Write settings
     if (config.containsKey('settings')) {
       await _writeMapToSheet(fileId, 'settings', config['settings']);
     }
     
     // Write dashboard
     if (config.containsKey('dashboard')) {
       await _writeMapToSheet(fileId, 'dashboard', config['dashboard']);
     }
     
     // Write tabs
     if (config.containsKey('tabs')) {
       final tabsList = config['tabs'] as List;
       // Map tabs by their ID for storage
       final tabsMap = {for (var t in tabsList) (t['id'] as String): t};
       await _writeMapToSheet(fileId, 'tabs', tabsMap);
     }
  }

  /// Reads the module configuration from the spreadsheet.
  Future<Map<String, dynamic>> readModuleConfig(String fileId) async {
    final config = <String, dynamic>{};
    
    try {
      // Read settings
      final settingsMap = await _readMapFromSheet(fileId, 'settings');
      config['settings'] = settingsMap.map((k, v) => MapEntry(k, jsonDecode(v)));
      
      // Read dashboard
      final dashboardMap = await _readMapFromSheet(fileId, 'dashboard');
      config['dashboard'] = dashboardMap.map((k, v) => MapEntry(k, jsonDecode(v)));
      
      // Read tabs
      final tabsMap = await _readMapFromSheet(fileId, 'tabs');
      config['tabs'] = tabsMap.values.map((v) => jsonDecode(v)).toList();
      
      return config;
    } catch (e) {
      debugPrint('Error reading module config: $e');
      return {};
    }
  }

  Future<void> _writeMapToSheet(String fileId, String sheetTitle, Map<String, dynamic> data) async {
    try {
      // Clear first to avoid stale data
      await sheetsApi.spreadsheets.values.clear(sheets.ClearValuesRequest(), fileId, '$sheetTitle!A:B');
      
      final rows = data.entries.map((e) => [e.key, jsonEncode(e.value)]).toList();
      final valueRange = sheets.ValueRange(values: rows);
      
      await sheetsApi.spreadsheets.values.update(
        valueRange,
        fileId,
        '$sheetTitle!A1',
        valueInputOption: 'RAW',
      );
    } catch (e) {
      debugPrint('Error writing to sheet $sheetTitle: $e');
      // Don't rethrow, try to continue
    }
  }

  Future<Map<String, String>> _readMapFromSheet(String fileId, String sheetTitle) async {
    try {
      final response = await sheetsApi.spreadsheets.values.get(fileId, '$sheetTitle!A:B');
      final map = <String, String>{};
      if (response.values != null) {
        for (var row in response.values!) {
          if (row.length >= 2) {
            map[row[0] as String] = row[1] as String;
          }
        }
      }
      return map;
    } catch (e) {
      debugPrint('Error reading sheet $sheetTitle: $e');
      return {};
    }
  }

  Future<void> saveRecord(String moduleFolderId, String spreadsheetName, String sheetTitle, Map<String, dynamic> data) async {
    try {
      // 1. Find or Create Spreadsheet
      String? spreadsheetId = await getFileId(moduleFolderId, spreadsheetName);
      
      if (spreadsheetId == null) {
        // Create new spreadsheet
        final spreadsheet = sheets.Spreadsheet(
          properties: sheets.SpreadsheetProperties(title: spreadsheetName),
        );
        final created = await retryOp(() => sheetsApi.spreadsheets.create(spreadsheet));
        spreadsheetId = created.spreadsheetId!;
        
        // Move to folder
        final file = await retryOp(() async {
           final result = await driveApi.files.get(spreadsheetId!, $fields: 'parents');
           return result as drive.File;
        });
        final previousParents = file.parents?.join(',') ?? '';
        
        if (previousParents.isNotEmpty) {
           await retryOp(() async {
             await driveApi.files.update(
              drive.File(), 
              spreadsheetId!, 
              addParents: moduleFolderId, 
              removeParents: previousParents,
              $fields: 'id, parents',
            );
           });
        } else {
           await retryOp(() async {
             await driveApi.files.update(
              drive.File(), 
              spreadsheetId!, 
              addParents: moduleFolderId,
              $fields: 'id, parents',
            );
           });
        }
        debugPrint('Created data spreadsheet: $spreadsheetName ($spreadsheetId)');
      }

      // 2. Check/Create Sheet (Tab)
      final spreadsheet = await retryOp(() => sheetsApi.spreadsheets.get(spreadsheetId!));
      bool sheetExists = spreadsheet.sheets?.any((s) => s.properties?.title == sheetTitle) ?? false;
      
      if (!sheetExists) {
        await retryOp(() => sheetsApi.spreadsheets.batchUpdate(
          sheets.BatchUpdateSpreadsheetRequest(
            requests: [
              sheets.Request(
                addSheet: sheets.AddSheetRequest(
                  properties: sheets.SheetProperties(title: sheetTitle),
                ),
              ),
            ],
          ),
          spreadsheetId!,
        ));
        debugPrint('Created sheet: $sheetTitle');
      }

      // 3. Handle Headers and Append
      // Read the first row to check headers
      final headerResponse = await retryOp(() => sheetsApi.spreadsheets.values.get(spreadsheetId!, '$sheetTitle!1:1'));
      List<String> headers = [];
      
      if (headerResponse.values != null && headerResponse.values!.isNotEmpty) {
        headers = headerResponse.values!.first.map((e) => e.toString()).toList();
      }

      // If no headers, write them from data keys
      if (headers.isEmpty) {
        headers = data.keys.toList();
        await retryOp(() => sheetsApi.spreadsheets.values.append(
          sheets.ValueRange(values: [headers]),
          spreadsheetId!,
          '$sheetTitle!A1',
          valueInputOption: 'RAW',
        ));
      } else {
        // Check if we have new keys in data that are not in headers
        final newKeys = data.keys.where((k) => !headers.contains(k)).toList();
        if (newKeys.isNotEmpty) {
          headers.addAll(newKeys);
          final valueRange = sheets.ValueRange(values: [headers]);
          await retryOp(() => sheetsApi.spreadsheets.values.update(
            valueRange,
            spreadsheetId!,
            '$sheetTitle!1:1',
            valueInputOption: 'RAW',
          ));
        }
      }

      // 4. Prepare Row Data
      final row = headers.map((h) => data[h]?.toString() ?? '').toList();
      
      // 5. Append Row
      await retryOp(() => sheetsApi.spreadsheets.values.append(
        sheets.ValueRange(values: [row]),
        spreadsheetId!,
        '$sheetTitle!A1',
        valueInputOption: 'RAW',
      ));
      debugPrint('Appended record to $sheetTitle');
      
    } catch (e) {
      debugPrint('Error saving record: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchRecords(String moduleFolderId, String spreadsheetName, String sheetTitle) async {
    try {
      // 1. Find Spreadsheet
      String? spreadsheetId = await getFileId(moduleFolderId, spreadsheetName);
      
      if (spreadsheetId == null) {
        return [];
      }

      // 2. Read Data
      final response = await retryOp(() => sheetsApi.spreadsheets.values.get(spreadsheetId, '$sheetTitle!A:ZZ'));
      final values = response.values;

      if (values == null || values.isEmpty) {
        return [];
      }

      // 3. Parse Headers
      final headers = values.first.map((e) => e.toString()).toList();
      final records = <Map<String, dynamic>>[];

      // 4. Parse Rows
      for (var i = 1; i < values.length; i++) {
        final row = values[i];
        final record = <String, dynamic>{};
        
        for (var j = 0; j < headers.length; j++) {
          if (j < row.length) {
            record[headers[j]] = row[j];
          } else {
            record[headers[j]] = null;
          }
        }
        records.add(record);
      }

      return records;
    } catch (e) {
      debugPrint('Error fetching records: $e');
      return [];
    }
  }
}
