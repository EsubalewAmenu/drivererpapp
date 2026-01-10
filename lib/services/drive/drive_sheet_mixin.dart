import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;

import 'package:http/http.dart' as http;

mixin DriveSheetMixin {
  drive.DriveApi get driveApi;
  sheets.SheetsApi get sheetsApi;
  http.Client get authClient;
  Future<T> retryOp<T>(Future<T> Function() action, {int retries = 3});
  Future<String?> getFileId(String folderId, String fileName);

  /// Executes a raw Google Visualization API Query (tq).
  /// Returns the first cell of the first row if scalar, or list of rows.
  Future<dynamic> executeGvizQuery(
    String moduleFolderId, 
    String sheetName, // The name of the spreadsheet file (== Tab ID usually)
    String query,     // "SELECT sum(C)"
  ) async {
    try {
      // 1. Find Spreadsheet ID
      final spreadsheetId = await getFileId(moduleFolderId, sheetName);
      if (spreadsheetId == null) {
        debugPrint('Spreadsheet $sheetName not found in $moduleFolderId');
        return null;
      }
      
      // 2. Get GID (assuming first sheet for now, or we can fetch metadata)
      // For now, let's assume the main data is on the first sheet (gid=0 usually)
      // or we can fetch metadata to be safe.
      // Copy logic from fetchRecords:
      final spreadsheet = await retryOp(() => sheetsApi.spreadsheets.get(spreadsheetId));
      
      // Look for a tab with the exact name, or default to the first used tab
      // This fixes issues where the data is on a specific tab (e.g. 'Stocks') but 'Sheet1' is the first tab
      int gid = 0;
      if (spreadsheet.sheets != null && spreadsheet.sheets!.isNotEmpty) {
        final exactMatch = spreadsheet.sheets!.firstWhere(
          (s) => s.properties?.title == sheetName,
          orElse: () => spreadsheet.sheets!.first,
        );
        gid = exactMatch.properties?.sheetId ?? 0;
      }

      // 3. Construct URL
      final url = 'https://docs.google.com/spreadsheets/d/$spreadsheetId/gviz/tq?tqx=out:json&tq=${Uri.encodeComponent(query)}&headers=0&gid=$gid';
      
      final response = await authClient.get(Uri.parse(url));
      if (response.statusCode != 200) {
        debugPrint('Gviz query failed: ${response.statusCode} for $url');
        return null;
      }

      // 4. Parse Response
      final body = response.body;
      final start = body.indexOf('{');
      final end = body.lastIndexOf('}');
      if (start == -1 || end == -1) return null;

      final jsonStr = body.substring(start, end + 1);
      final decoded = jsonDecode(jsonStr);
      
      if (decoded['status'] == 'error') {
        debugPrint('Gviz Error: ${decoded['errors']}');
        return null;
      }

      final table = decoded['table'];
      final rows = table['rows'] as List;
      if (rows.isEmpty) return null;

      // Return the value of the first cell of the first row (common for aggregations)
      // rows[0]['c'][0]['v']
      final firstRow = rows[0];
      final cells = firstRow['c'] as List;
      if (cells.isNotEmpty && cells[0] != null) {
        return cells[0]['v'];
      }
      return null;
    } catch (e) {
      debugPrint('Error executing Gviz query: $e');
      return null;
    }
  }

  /// Executes a Gviz query expecting a table result (for Charts).
  /// Returns List<Map<String, dynamic>> where keys are column labels (or index if no label).
  Future<List<Map<String, dynamic>>?> executeGvizTableQuery(
    String moduleFolderId, 
    String sheetName,
    String query
  ) async {
    try {
      final spreadsheetId = await getFileId(moduleFolderId, sheetName);
      if (spreadsheetId == null) return null;
      
      final spreadsheet = await retryOp(() => sheetsApi.spreadsheets.get(spreadsheetId));
      int gid = 0;
      if (spreadsheet.sheets != null && spreadsheet.sheets!.isNotEmpty) {
        final exactMatch = spreadsheet.sheets!.firstWhere(
          (s) => s.properties?.title == sheetName,
          orElse: () => spreadsheet.sheets!.first,
        );
        gid = exactMatch.properties?.sheetId ?? 0;
      }

      final url = 'https://docs.google.com/spreadsheets/d/$spreadsheetId/gviz/tq?tqx=out:json&tq=${Uri.encodeComponent(query)}&headers=0&gid=$gid';
      final response = await authClient.get(Uri.parse(url));
      
      if (response.statusCode != 200) return null;

      final body = response.body;
      final start = body.indexOf('{');
      final end = body.lastIndexOf('}');
      if (start == -1 || end == -1) return null;

      final jsonStr = body.substring(start, end + 1);
      final decoded = jsonDecode(jsonStr);
      
      if (decoded['status'] == 'error') return null;

      final table = decoded['table'];
      final cols = table['cols'] as List;
      final rows = table['rows'] as List;
      
      List<Map<String, dynamic>> result = [];
      
      for (var row in rows) {
        final cells = row['c'] as List;
        final rowData = <String, dynamic>{};
        
        for (int i = 0; i < cols.length; i++) {
          final colLabel = cols[i]['label']?.toString().isNotEmpty == true 
              ? cols[i]['label'] 
              : 'col_$i';
          
          if (i < cells.length && cells[i] != null) {
            rowData[colLabel] = cells[i]['v'];
            // Also store formatted value for tooltips if available
            if (cells[i]['f'] != null) {
               rowData['${colLabel}_f'] = cells[i]['f'];
            }
          } else {
            rowData[colLabel] = null;
          }
        }
        result.add(rowData);
      }
      
      return result;

    } catch (e) {
      debugPrint('Error executing Gviz table query: $e');
      return null;
    }
  }

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
  Future<Map<String, dynamic>?> readModuleConfig(String fileId) async {
    final config = <String, dynamic>{};
    
    try {
      // Read settings
      final settingsMap = await _readMapFromSheet(fileId, 'settings');
      if (settingsMap.isEmpty) {
        debugPrint('Settings sheet is empty or missing for $fileId');
      } else {
        config['settings'] = settingsMap.map((k, v) => MapEntry(k, jsonDecode(v)));
      }
      
      // Read dashboard
      final dashboardMap = await _readMapFromSheet(fileId, 'dashboard');
      if (dashboardMap.isNotEmpty) {
        config['dashboard'] = dashboardMap.map((k, v) => MapEntry(k, jsonDecode(v)));
      }
      
      // Read tabs
      final tabsMap = await _readMapFromSheet(fileId, 'tabs');
      if (tabsMap.isNotEmpty) {
        config['tabs'] = tabsMap.values.map((v) => jsonDecode(v)).toList();
      }

      // If we have nothing significant, return null to allow fallback
      if (config.isEmpty || (config['settings'] == null && config['tabs'] == null)) {
        return null;
      }
      
      return config;
    } catch (e) {
      debugPrint('Error reading module config: $e');
      return null;
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
      // Use sheetTitle as the spreadsheet name to save each tab in a separate file
      String targetSpreadsheetName = sheetTitle;
      String? spreadsheetId = await getFileId(moduleFolderId, targetSpreadsheetName);
      
      if (spreadsheetId == null) {
        // Create new spreadsheet
        final spreadsheet = sheets.Spreadsheet(
          properties: sheets.SpreadsheetProperties(title: targetSpreadsheetName),
        );
        final created = await retryOp(() => sheetsApi.spreadsheets.create(spreadsheet));
        spreadsheetId = created.spreadsheetId!;
        
        // Move to folder
        final file = await retryOp(() async {
           final result = await driveApi.files.get(spreadsheetId!, $fields: 'id, parents');
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
        debugPrint('Created data spreadsheet: $targetSpreadsheetName ($spreadsheetId)');
      }

      // 2. Prepare Data with Technical Fields
      final recordId = data['record_id'] ?? DateTime.now().microsecondsSinceEpoch.toString();
      final finalData = Map<String, dynamic>.from(data);
      finalData['record_id'] = recordId;
      if (finalData['created_at'] == null) {
        finalData['created_at'] = DateTime.now().toIso8601String();
      }

      // 3. Extract Nested Lists (Tables)
      final nestedTables = <String, List<dynamic>>{};
      final keysToRemove = <String>[];
      final keysToEncode = <String>[];
      
      finalData.forEach((key, value) {
        if (value is List) {
          // Check if list contains Maps (nested table) or primitives (list field)
          final isNestedTable = value.isNotEmpty && value.first is Map;
          
          if (isNestedTable) {
            nestedTables[key] = value;
            keysToRemove.add(key);
          } else {
            // Simple list (e.g. variants, tags) - keep in main record as JSON string
            keysToEncode.add(key);
          }
        }
      });

      // Encode simple lists directly in the data
      for (var key in keysToEncode) {
        finalData[key] = jsonEncode(finalData[key]);
      }

      // Remove nested lists from the main record to normalize
      // We keep a reference or just remove them as they will be in separate sheets
      for (var key in keysToRemove) {
        finalData.remove(key);
      }

      // 4. Save Main Record
      await _saveToSheet(spreadsheetId, sheetTitle, finalData);

      // 5. Save Nested Tables
      for (var entry in nestedTables.entries) {
        final subSheetTitle = '$sheetTitle.${entry.key}';
        
        // If updating a record, we should probably clear existing sub-items or handle carefully
        // For simplicity, we search for each sub-item by sub_record_id and update or append.
        // If the user deleted an item from the list UI, it stays in the Sheet!
        // To handle deletions, we'd need to fetch all sub-items with parent_record_id and compare.
        // For now, let's at least ensure editing existing items works.
        
        for (var item in entry.value) {
          if (item is Map) {
            final itemData = Map<String, dynamic>.from(item);
            itemData['parent_record_id'] = recordId;
            // Add a unique ID for the sub-item if it doesn't have one
            if (itemData['sub_record_id'] == null) {
              itemData['sub_record_id'] = DateTime.now().microsecondsSinceEpoch.toString();
            }
            await _saveToSheet(spreadsheetId, subSheetTitle, itemData);
          }
        }
      }
      
    } catch (e) {
      debugPrint('Error saving record: $e');
      rethrow;
    }
  }

  Future<void> deleteRecord(String moduleFolderId, String spreadsheetName, String sheetTitle, String recordId) async {
    try {
      // 1. Find Spreadsheet
      String? spreadsheetId = await getFileId(moduleFolderId, sheetTitle);
      if (spreadsheetId == null) throw Exception("Spreadsheet not found");

      // 2. Identify Row Index
      final headerResponse = await retryOp(() => sheetsApi.spreadsheets.values.get(spreadsheetId, '$sheetTitle!1:1'));
      if (headerResponse.values == null || headerResponse.values!.isEmpty) throw Exception("Sheet is empty");
      
      final headers = headerResponse.values!.first.map((e) => e.toString()).toList();
      final idColIndex = headers.indexOf('record_id');
      if (idColIndex == -1) throw Exception("record_id column not found");

      final colLetter = _getColLetter(idColIndex);
      final idColResponse = await retryOp(() => sheetsApi.spreadsheets.values.get(spreadsheetId, '$sheetTitle!$colLetter:$colLetter'));
      final idValues = idColResponse.values;
      
      int? rowIndex;
      if (idValues != null) {
        for (int i = 0; i < idValues.length; i++) {
          if (idValues[i].isNotEmpty && idValues[i].first.toString() == recordId) {
            rowIndex = i; // 0-indexed for deleteDimension
            break;
          }
        }
      }

      if (rowIndex == null) throw Exception("Record not found in sheet");

      // 3. Get Sheet ID (GID)
      final spreadsheet = await retryOp(() => sheetsApi.spreadsheets.get(spreadsheetId));
      final sheet = spreadsheet.sheets?.firstWhere((s) => s.properties?.title == sheetTitle);
      final int? gid = sheet?.properties?.sheetId;
      if (gid == null) throw Exception("Could not find sheet GID");

      // 4. Delete the Row
      await retryOp(() => sheetsApi.spreadsheets.batchUpdate(
        sheets.BatchUpdateSpreadsheetRequest(
          requests: [
            sheets.Request(
              deleteDimension: sheets.DeleteDimensionRequest(
                range: sheets.DimensionRange(
                  sheetId: gid,
                  dimension: 'ROWS',
                  startIndex: rowIndex as int,
                  endIndex: (rowIndex as int) + 1,
                ),
              ),
            ),
          ],
        ),
        spreadsheetId,
      ));

      debugPrint('Deleted record $recordId from $sheetTitle at row ${(rowIndex as int) + 1}');

      // 5. Delete associated sub-table records (optional but good for cleanliness)
      final subTableSheets = spreadsheet.sheets
          ?.where((s) => s.properties?.title?.startsWith('$sheetTitle.') ?? false)
          .toList() ?? [];

      if (subTableSheets.isNotEmpty) {
        debugPrint('Found ${subTableSheets.length} potential sub-sheets for cleanup...');
      }

      for (var subSheet in subTableSheets) {
        final title = subSheet.properties!.title!;
        final subGid = subSheet.properties!.sheetId!;
        
        debugPrint('Checking sub-sheet: $title');
        // Find indices of rows with matching parent_record_id
        final subHeadersRes = await retryOp(() => sheetsApi.spreadsheets.values.get(spreadsheetId, '$title!1:1'));
        if (subHeadersRes.values == null || subHeadersRes.values!.isEmpty) continue;
        
        final subHeaders = subHeadersRes.values!.first.map((e) => e.toString()).toList();
        final pIdIndex = subHeaders.indexOf('parent_record_id');
        if (pIdIndex == -1) continue;

        final pColLetter = _getColLetter(pIdIndex);
        final pColData = await retryOp(() => sheetsApi.spreadsheets.values.get(spreadsheetId, '$title!$pColLetter:$pColLetter'));
        final pValues = pColData.values;

        if (pValues != null) {
          // Collect indices to delete (skip header at index 0)
          List<int> toDelete = [];
          for (int i = 1; i < pValues.length; i++) {
            if (pValues[i].isNotEmpty && pValues[i].first.toString() == recordId) {
              toDelete.add(i);
            }
          }

          if (toDelete.isNotEmpty) {
            debugPrint('Found ${toDelete.length} linked records in $title to delete');
            // Delete in reverse order to keep indices valid during sequential deletion
            toDelete.sort((a, b) => b.compareTo(a));
            
            final requests = toDelete.map((idx) => sheets.Request(
              deleteDimension: sheets.DeleteDimensionRequest(
                range: sheets.DimensionRange(
                  sheetId: subGid,
                  dimension: 'ROWS',
                  startIndex: idx,
                  endIndex: idx + 1,
                ),
              ),
            )).toList();

            await retryOp(() => sheetsApi.spreadsheets.batchUpdate(
              sheets.BatchUpdateSpreadsheetRequest(requests: requests),
              spreadsheetId,
            ));
            debugPrint('Cleaned up ${toDelete.length} sub-records from $title');
          }
        }
      }
      debugPrint('deleteRecord completed fully for $recordId');
    } catch (e) {
      debugPrint('Error deleting record: $e');
      rethrow;
    }
  }

  Future<void> _saveToSheet(String spreadsheetId, String sheetTitle, Map<String, dynamic> data) async {
    // 1. Check/Create Sheet
    final spreadsheet = await retryOp(() => sheetsApi.spreadsheets.get(spreadsheetId));
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
        spreadsheetId,
      ));
      debugPrint('Created sheet: $sheetTitle');
    }

    // 2. Handle Headers
    final headerResponse = await retryOp(() => sheetsApi.spreadsheets.values.get(spreadsheetId, '$sheetTitle!1:1'));
    List<String> headers = [];
    
    if (headerResponse.values != null && headerResponse.values!.isNotEmpty) {
      headers = headerResponse.values!.first.map((e) => e.toString()).toList();
    }

    if (headers.isEmpty) {
      headers = data.keys.toList();
      await retryOp(() => sheetsApi.spreadsheets.values.append(
        sheets.ValueRange(values: [headers]),
        spreadsheetId,
        '$sheetTitle!A1',
        valueInputOption: 'RAW',
      ));
    } else {
      final newKeys = data.keys.where((k) => !headers.contains(k)).toList();
      if (newKeys.isNotEmpty) {
        headers.addAll(newKeys);
        await retryOp(() => sheetsApi.spreadsheets.values.update(
          sheets.ValueRange(values: [headers]),
          spreadsheetId,
          '$sheetTitle!1:1',
          valueInputOption: 'RAW',
        ));
      }
    }

    // 3. Check for Update vs Append
    final recordId = data['record_id']?.toString() ?? data['sub_record_id']?.toString();
    final idKey = data.containsKey('record_id') ? 'record_id' : (data.containsKey('sub_record_id') ? 'sub_record_id' : null);
    
    int? recordRowIndex;
    if (recordId != null && idKey != null) {
      final idColIndex = headers.indexOf(idKey);
      if (idColIndex != -1) {
        final colLetter = _getColLetter(idColIndex);
        final idColResponse = await retryOp(() => sheetsApi.spreadsheets.values.get(spreadsheetId, '$sheetTitle!$colLetter:$colLetter'));
        final idValues = idColResponse.values;
        if (idValues != null) {
          for (int i = 0; i < idValues.length; i++) {
            if (idValues[i].isNotEmpty && idValues[i].first.toString() == recordId) {
              recordRowIndex = i + 1; // 1-indexed
              break;
            }
          }
        }
      }
    }

    final row = headers.map((h) => data[h]?.toString() ?? '').toList();
    
    if (recordRowIndex != null) {
      await retryOp(() => sheetsApi.spreadsheets.values.update(
        sheets.ValueRange(values: [row]),
        spreadsheetId,
        '$sheetTitle!$recordRowIndex:$recordRowIndex',
        valueInputOption: 'RAW',
      ));
      debugPrint('Updated data in $sheetTitle at row $recordRowIndex');
    } else {
      await retryOp(() => sheetsApi.spreadsheets.values.append(
        sheets.ValueRange(values: [row]),
        spreadsheetId,
        '$sheetTitle!A1',
        valueInputOption: 'RAW',
      ));
      debugPrint('Appended data to $sheetTitle');
    }
  }

  String _getColLetter(int colIndex) {
    String letter = "";
    while (colIndex >= 0) {
      letter = String.fromCharCode((colIndex % 26) + 65) + letter;
      colIndex = (colIndex / 26).floor() - 1;
    }
    return letter;
  }

  Future<List<Map<String, dynamic>>> fetchRecords(
    String moduleFolderId, 
    String spreadsheetName, 
    String sheetTitle, {
      int offset = 0,
      int? limit,
      bool fetchSubTables = true,
      bool descending = false,
      String? searchQuery,
      Map<String, dynamic>? quickFilter,
  }) async {
    try {
      // 1. Find Spreadsheet
      String targetSpreadsheetName = sheetTitle;
      String? spreadsheetId = await getFileId(moduleFolderId, targetSpreadsheetName);
      
      if (spreadsheetId == null) {
        return [];
      }

      // 2. Fetch Spreadsheet Metadata (to get sheet ID and titles)
      final spreadsheet = await retryOp(() => sheetsApi.spreadsheets.get(spreadsheetId));
      final allSheetTitles = spreadsheet.sheets?.map((s) => s.properties?.title ?? '').toList() ?? [];
      final targetSheet = spreadsheet.sheets?.firstWhere((s) => s.properties?.title == sheetTitle);
      final int? gid = targetSheet?.properties?.sheetId;

      // 3. Read All Sheets to Find Sub-tables (Only if fetching sub-tables)
      List<String> subTableSheets = [];
      if (fetchSubTables) {
        subTableSheets = allSheetTitles.where((t) => t.startsWith('$sheetTitle.')).toList();
      }

      // 4. Fetch Records
      List<Map<String, dynamic>> finalRecords;
      
      bool isSearch = searchQuery != null && searchQuery.length >= 2;
      bool hasQuickFilter = quickFilter != null && quickFilter['field'] != null && quickFilter['operator'] != null;
      
      if (isSearch || descending || hasQuickFilter) {
        try {
          // PERFORM SERVER-SIDE SEARCH, FILTER or SORT using Google Visualization API
          finalRecords = await _fetchSheetDataSearch(
            spreadsheetId, 
            sheetTitle, 
            gid: gid,
            query: isSearch ? searchQuery : null,
            filter: hasQuickFilter ? quickFilter : null,
            offset: offset,
            limit: limit ?? 20,
            descending: descending,
          );
        } catch (e) {
          debugPrint('Server-side search/filter/sort failed: $e. Falling back to local filter...');
          // Fallback to standard fetch
          finalRecords = await _fetchSheetData(
            spreadsheetId, 
            sheetTitle,
            offset: offset,
            limit: limit ?? 20,
          );
          
          // Apply local search if needed
          if (isSearch) {
             finalRecords = finalRecords.where((item) => 
               item.values.any((val) => 
                 val.toString().toLowerCase().contains(searchQuery.toLowerCase())
               )
             ).toList();
          }

          // Apply local quick filter if needed
          if (hasQuickFilter) {
            final field = quickFilter['field'] as String;
            final op = quickFilter['operator'] as String;
            final filterValue = quickFilter['value']?.toString().toLowerCase() ?? '';

            finalRecords = finalRecords.where((item) {
              final itemVal = item[field]?.toString().toLowerCase() ?? '';
              if (op == '==' || op == '=') return itemVal == filterValue;
              if (op == '!=') return itemVal != filterValue;
              if (op == 'contains') return itemVal.contains(filterValue);
              if (op == 'startsWith') return itemVal.startsWith(filterValue);
              
              final numItem = num.tryParse(itemVal);
              final numFilter = num.tryParse(filterValue);
              if (numItem != null && numFilter != null) {
                if (op == '>') return numItem > numFilter;
                if (op == '>=') return numItem >= numFilter;
                if (op == '<') return numItem < numFilter;
                if (op == '<=') return numItem <= numFilter;
              }
              return true;
            }).toList();
          }
          
          // Apply local sort if descending
          if (descending) {
            finalRecords.sort((a, b) {
              final aVal = a['record_id'];
              final bVal = b['record_id'];
              
              // Numeric sort if possible
              final aNum = num.tryParse(aVal?.toString() ?? '');
              final bNum = num.tryParse(bVal?.toString() ?? '');
              
              if (aNum != null && bNum != null) {
                return bNum.compareTo(aNum);
              }
              
              final aStr = aVal?.toString() ?? '';
              final bStr = bVal?.toString() ?? '';
              return bStr.compareTo(aStr);
            });
          }
        }
      } else {
        // Standard Paginated Fetch (Ascending or No Sort)
        finalRecords = await _fetchSheetData(
          spreadsheetId, 
          sheetTitle,
          offset: offset,
          limit: limit,
        );
      }

      if (finalRecords.isEmpty) return [];

      // 5. Fetch and Join Sub-tables
      if (fetchSubTables && subTableSheets.isNotEmpty) {
        for (var subSheet in subTableSheets) {
          final fieldName = subSheet.substring(sheetTitle.length + 1); // e.g., "items"
          final subRecords = await _fetchSheetData(spreadsheetId, subSheet);
          
          // Group sub-records by parent_record_id
          final groupedSubs = <String, List<Map<String, dynamic>>>{};
          for (var sub in subRecords) {
            final parentId = sub['parent_record_id']?.toString();
            if (parentId != null) {
              groupedSubs.putIfAbsent(parentId, () => []).add(sub);
            }
          }

          // Join to main records
          for (var main in finalRecords) {
            final recordId = main['record_id']?.toString();
            if (recordId != null) {
              main[fieldName] = groupedSubs[recordId] ?? [];
            }
          }
        }
      }

      return finalRecords;
    } catch (e) {
      debugPrint('Error fetching records: $e');
      // Rethrow to allow caller (UI) to handle specific errors like Offline
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchSheetData(
    String spreadsheetId, 
    String sheetTitle, {
    int offset = 0,
    int? limit,
  }) async {
    try {
      // Always fetch headers first (Row 1)
      final headerResponse = await retryOp(() => sheetsApi.spreadsheets.values.get(spreadsheetId, '$sheetTitle!1:1'));
      final headerValues = headerResponse.values;
      if (headerValues == null || headerValues.isEmpty) return [];
      
      final headers = headerValues.first.map((e) => e.toString()).toList();

      // Calculate Data Range
      String range;
      if (limit != null) {
        // Rows are 1-indexed. Header is 1. Data starts at 2.
        // offset 0 -> row 2
        // offset 20 -> row 22
        final startRow = 2 + offset;
        final endRow = startRow + limit - 1;
        range = '$sheetTitle!A$startRow:ZZ$endRow';
      } else {
        // Fetch remaining from offset
        final startRow = 2 + offset;
        range = '$sheetTitle!A$startRow:ZZ';
      }

      final response = await retryOp(() => sheetsApi.spreadsheets.values.get(spreadsheetId, range));
      final values = response.values;

      if (values == null || values.isEmpty) return [];

      final records = <Map<String, dynamic>>[];

      for (var row in values) {
        final record = <String, dynamic>{};
        bool isEmptyRow = true;
        for (var j = 0; j < headers.length; j++) {
          final val = (j < row.length) ? row[j] : null;
          if (val != null && val.toString().isNotEmpty) isEmptyRow = false;
          record[headers[j]] = val;
        }
        if (!isEmptyRow) {
          records.add(record);
        }
      }
      return records;
    } catch (e) {
      debugPrint('Error reading sheet $sheetTitle: $e');
      return [];
    }
  }

  // Cache for column types to avoid redundant metadata fetches
  static final Map<String, List<String>> _columnTypesCache = {};

  Future<List<String>> _getSheetColumnTypes(String spreadsheetId, int? gid) async {
    final cacheKey = '$spreadsheetId-${gid ?? 0}';
    if (_columnTypesCache.containsKey(cacheKey)) {
      return _columnTypesCache[cacheKey]!;
    }

    try {
      final url = 'https://docs.google.com/spreadsheets/d/$spreadsheetId/gviz/tq?tqx=out:json&tq=${Uri.encodeComponent("SELECT * LIMIT 0")}${gid != null ? '&gid=$gid' : ''}';
      final response = await authClient.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final body = response.body;
        final start = body.indexOf('{');
        final end = body.lastIndexOf('}');
        if (start != -1 && end != -1) {
          final jsonStr = body.substring(start, end + 1);
          final decoded = jsonDecode(jsonStr);
          final cols = decoded['table']['cols'] as List;
          final types = cols.map((c) => c['type'].toString()).toList();
          _columnTypesCache[cacheKey] = types;
          return types;
        }
      }
    } catch (e) {
      debugPrint('Error fetching column types: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> _fetchSheetDataSearch(
    String spreadsheetId, 
    String sheetTitle, {
    int? gid,
    String? query,
    Map<String, dynamic>? filter, // { field: String, operator: String, value: dynamic }
    int offset = 0,
    int limit = 20,
    bool descending = false,
  }) async {
    try {
      // 1. Get headers for column mapping
      final headerResponse = await retryOp(() => sheetsApi.spreadsheets.values.get(spreadsheetId, '$sheetTitle!1:1'));
      final headers = headerResponse.values?.first.map((e) => e.toString()).toList() ?? [];
      if (headers.isEmpty) return [];

      // 2. Build Query
      String tq = "SELECT *";
      final whereClauses = <String>[];
      
      // Handle Search Query
      if (query != null && query.isNotEmpty) {
        final searchParts = <String>[];
        // Limit to first 50 columns to keep query string manageable
        final searchLimit = headers.length > 50 ? 50 : headers.length;
        
        // Try to get actual column types from Gviz metadata
        final actualTypes = await _getSheetColumnTypes(spreadsheetId, gid);
        
        // Fallback keywords for columns that are strictly numeric or non-text (dates, booleans).
        final strictlyNonText = [
          'qty', 'quantity', 'price', 'amount', 'total', 'cost', 
          'tax', 'discount', 'date', 'time', 'lat', 'long', 'zip', 'postcode', 
          'balance', 'ledger', 'credit', 'debit', 'value', 'count', 'score', 'percent',
          'is_', 'has_', 'can_', 'are_', 'was_', 'is ', 'has ', 'can ', 'are ', 'was ', '?',
          'record_id', 'parent_record_id', 'sub_record_id', 'tin', 'phone', 'mobile'
        ];

        for (var i = 0; i < searchLimit; i++) {
          final col = _indexToColumn(i);
          final header = headers[i].toLowerCase();
          
          bool isText = true;
          if (actualTypes.length > i) {
            isText = actualTypes[i] == 'string';
          } else {
            // Fallback to heuristic if metadata fetch failed
            isText = !strictlyNonText.any((k) => header.contains(k));
          }
          
          if (!isText) {
            // Only search numeric columns if the query itself is a number.
            final numQuery = double.tryParse(query);
            if (numQuery != null) {
              searchParts.add("$col = $numQuery");
            }
          } else {
            // For text columns
            searchParts.add("lower($col) contains '${query.toLowerCase().replaceAll("'", "\\'")}'");
          }
        }
        if (searchParts.isNotEmpty) {
          whereClauses.add("(${searchParts.join(' OR ')})");
        }
      }

      // Handle Quick Filter
      if (filter != null) {
        final field = filter['field'] as String;
        final op = filter['operator'] as String;
        final val = filter['value'];
        
        final fieldIndex = headers.indexOf(field);
        if (fieldIndex != -1) {
          final col = _indexToColumn(fieldIndex);
          String? clause;
          
          // Stringify value for Gviz
          String gvizVal = val.toString();
          bool isNumeric = num.tryParse(gvizVal) != null;
          bool isBool = gvizVal.toLowerCase() == 'true' || gvizVal.toLowerCase() == 'false';
          String escapedVal = gvizVal.replaceAll("'", "\\'");
          
          if (op == '==' || op == '=') {
            if (isNumeric || isBool) {
              clause = "$col = $gvizVal";
            } else {
              clause = "$col = '$escapedVal'";
            }
          } else if (op == '!=') {
            if (isNumeric || isBool) {
              clause = "$col != $gvizVal";
            } else {
              clause = "$col != '$escapedVal'";
            }
          } else if (op == 'contains') {
            clause = "lower($col) contains '${escapedVal.toLowerCase()}'";
          } else if (op == '>' || op == '>=' || op == '<' || op == '<=') {
            clause = isNumeric ? "$col $op $gvizVal" : "$col $op '$escapedVal'";
          } else if (op == 'startsWith' || op == 'startsWidth') {
            clause = "lower($col) starts with '${escapedVal.toLowerCase()}'";
          } else if (op == 'endsWith' || op == 'endsWidth') {
            clause = "lower($col) ends with '${escapedVal.toLowerCase()}'";
          }
          
          if (clause != null) {
            whereClauses.add(clause);
          }
        }
      }

      if (whereClauses.isNotEmpty) {
        tq += " WHERE ${whereClauses.join(' AND ')}";
      }
      
      final recordIdIndex = headers.indexOf('record_id');
      if (recordIdIndex != -1) {
        tq += " ORDER BY ${_indexToColumn(recordIdIndex)} ${descending ? 'DESC' : 'ASC'}";
      }

      tq += " LIMIT $limit OFFSET $offset";

      // 3. Request from Google Vis API
      final url = 'https://docs.google.com/spreadsheets/d/$spreadsheetId/gviz/tq?tqx=out:json&tq=${Uri.encodeComponent(tq)}${gid != null ? '&gid=$gid' : ''}&headers=1';
      
      final response = await authClient.get(Uri.parse(url));
      if (response.statusCode != 200) {
        debugPrint('Gviz request failed with status: ${response.statusCode}');
        return [];
      }

      // 4. Parse
      final body = response.body;
      final start = body.indexOf('{');
      final end = body.lastIndexOf('}');
      if (start == -1 || end == -1) return [];

      final jsonStr = body.substring(start, end + 1);
      final decoded = jsonDecode(jsonStr);
      
      if (decoded['status'] == 'error') {
        final error = (decoded['errors'] as List?)?.firstOrNull;
        final message = error?['detailed_message'] ?? error?['message'] ?? 'Unknown Gviz Error';
        throw Exception('Gviz Query Failed: $message');
      }

      final table = decoded['table'];
      if (table == null || table['rows'] == null) return [];

      final List<Map<String, dynamic>> results = [];
      final rows = table['rows'] as List;

      for (var row in rows) {
        final cells = row['c'] as List;
        final record = <String, dynamic>{};
        for (var i = 0; i < headers.length; i++) {
          if (i < cells.length && cells[i] != null) {
            final cell = cells[i] as Map<String, dynamic>;
            record[headers[i]] = cell['v'];
          } else {
            record[headers[i]] = null;
          }
        }
        results.add(record);
      }
      return results;
    } catch (e) {
      debugPrint('Error in server-side search: $e');
      rethrow;
    }
  }

  String _indexToColumn(int index) {
    String res = '';
    int n = index + 1;
    while (n > 0) {
      int m = (n - 1) % 26;
      res = String.fromCharCode(65 + m) + res;
      n = ((n - m) ~/ 26);
    }
    return res;
  }
}
