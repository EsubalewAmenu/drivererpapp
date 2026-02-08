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
  /// Returns a map of the created spreadsheet IDs: {'settings': id, 'dashboard': id, 'tabs': id}.
  Future<Map<String, String>> createModuleConfig(String folderId, String fileName, Map<String, dynamic> config) async {
    try {
      // We'll create three separate spreadsheets: settings, dashboard, and tabs.
      final settingsTitle = '${fileName}_settings';
      final dashboardTitle = '${fileName}_dashboard';
      final tabsTitle = '${fileName}_tabs';

      // 1. Settings spreadsheet directly in target folder
      final settingsFile = drive.File()
        ..name = settingsTitle
        ..mimeType = 'application/vnd.google-apps.spreadsheet'
        ..parents = [folderId];
      final createdSettings = await retryOp(() => driveApi.files.create(settingsFile, supportsAllDrives: true));
      final settingsId = createdSettings.id!;

      await retryOp(() => sheetsApi.spreadsheets.batchUpdate(
        sheets.BatchUpdateSpreadsheetRequest(
          requests: [
            sheets.Request(updateSheetProperties: sheets.UpdateSheetPropertiesRequest(
              properties: sheets.SheetProperties(sheetId: 0, title: 'settings'),
              fields: 'title',
            )),
          ],
        ),
        settingsId,
      ));

      // 2. Dashboard spreadsheet directly in target folder
      final dashboardFile = drive.File()
        ..name = dashboardTitle
        ..mimeType = 'application/vnd.google-apps.spreadsheet'
        ..parents = [folderId];
      final createdDashboard = await retryOp(() => driveApi.files.create(dashboardFile, supportsAllDrives: true));
      final dashboardId = createdDashboard.id!;

      await retryOp(() => sheetsApi.spreadsheets.batchUpdate(
        sheets.BatchUpdateSpreadsheetRequest(
          requests: [
            sheets.Request(updateSheetProperties: sheets.UpdateSheetPropertiesRequest(
              properties: sheets.SheetProperties(sheetId: 0, title: 'cards'),
              fields: 'title',
            )),
          ],
        ),
        dashboardId,
      ));

      // 3. Tabs spreadsheet directly in target folder
      final tabsFile = drive.File()
        ..name = tabsTitle
        ..mimeType = 'application/vnd.google-apps.spreadsheet'
        ..parents = [folderId];
      final createdTabs = await retryOp(() => driveApi.files.create(tabsFile, supportsAllDrives: true));
      final tabsId = createdTabs.id!;

      final tabsList = (config['tabs'] as List? ?? []).cast<dynamic>();
      final List<sheets.Request> tabRequests = [];
      
      if (tabsList.isNotEmpty) {
        // Rename default Sheet1
        final tid0 = (tabsList[0] is Map && tabsList[0]['id'] != null) ? tabsList[0]['id'].toString() : 'Sheet1';
        tabRequests.add(sheets.Request(updateSheetProperties: sheets.UpdateSheetPropertiesRequest(
          properties: sheets.SheetProperties(sheetId: 0, title: tid0),
          fields: 'title',
        )));
        
        // Add other tabs
        for (var i = 1; i < tabsList.length; i++) {
          final tid = (tabsList[i] is Map && tabsList[i]['id'] != null) ? tabsList[i]['id'].toString() : null;
          if (tid != null) {
            tabRequests.add(sheets.Request(addSheet: sheets.AddSheetRequest(properties: sheets.SheetProperties(title: tid))));
          }
        }
      } else {
        tabRequests.add(sheets.Request(updateSheetProperties: sheets.UpdateSheetPropertiesRequest(
          properties: sheets.SheetProperties(sheetId: 0, title: 'tabs'),
          fields: 'title',
        )));
      }

      await retryOp(() => sheetsApi.spreadsheets.batchUpdate(
        sheets.BatchUpdateSpreadsheetRequest(requests: tabRequests),
        tabsId,
      ));

      debugPrint('Created settings: $settingsTitle ($settingsId)');
      debugPrint('Created dashboard: $dashboardTitle ($dashboardId)');
      debugPrint('Created tabs: $tabsTitle ($tabsId)');

      // Write initial content
      await _writeMapToSheet(settingsId, 'settings', config['settings'] ?? {});

      // Dashboard cards: treat as list of maps; write each card as a row (A1 JSON)
      if (config.containsKey('dashboard')) {
        final cards = config['dashboard'];
        if (cards is Map) {
          // previous format might be map; convert to rows
          await _writeMapToSheet(dashboardId, 'cards', cards as Map<String, dynamic>);
        } else if (cards is List) {
          // write as rows of JSON
          final rows = (cards).map((c) => [jsonEncode(c)]).toList();
          await retryOp(() => sheetsApi.spreadsheets.values.update(sheets.ValueRange(values: rows), dashboardId, 'cards!A1', valueInputOption: 'RAW'));
        }
      }

      // Tabs: write tabs as A:B key/value rows (JSON values)
      if (config.containsKey('tabs')) {
        final tabs = (config['tabs'] as List? ?? []).cast<dynamic>();
        if (tabs.isNotEmpty) {
          await writeTabsById(tabsId, tabs);
        }
      }

      return {
        'settings': settingsId,
        'dashboard': dashboardId,
        'tabs': tabsId,
      };
    } catch (e) {
      debugPrint('Error creating module config: $e');
      rethrow;
    }
  }

  /// Updates the module configuration in the spreadsheet.
  Future<void> updateModuleConfig(String fileId, Map<String, dynamic> config) async {
    // fileId is settings spreadsheet id. 
    try {
      if (config.containsKey('settings')) {
        await _writeMapToSheet(fileId, 'settings', config['settings'] ?? {});
      }
    } catch (e) {
      debugPrint('Error updating module config: $e');
    }
  }

  /// Read only the `settings` sheet from a settings spreadsheet id.
  /// Returns a map of settingKey -> decoded value, or null on error/empty.
  Future<Map<String, dynamic>?> readSettingsById(String settingsId) async {
    try {
      final map = await _readMapFromSheet(settingsId, 'settings');
      if (map.isEmpty) return null;
      final res = <String, dynamic>{};
      map.forEach((k, v) {
        try {
          res[k] = jsonDecode(v);
        } catch (_) {
          res[k] = v;
        }
      });
      return res;
    } catch (e) {
      debugPrint('Error reading settings by id $settingsId: $e');
      return null;
    }
  }

  /// Read only the dashboard (cards) spreadsheet by id.
  /// Returns either a List (row JSON list) or a Map (key->value map) or null.
  Future<dynamic> readDashboardById(String dashboardId) async {
    try {
      // Try rows-as-JSON first
      try {
        final resp = await retryOp(() => sheetsApi.spreadsheets.values.get(dashboardId, 'cards!A1:Z'));
        if (resp.values != null && resp.values!.isNotEmpty) {
          final firstRow = resp.values!.first;
          if (firstRow.isNotEmpty && firstRow.first is String && (firstRow.first as String).trim().startsWith('{')) {
            return resp.values!.map((r) => jsonDecode(r.first as String)).toList();
          }
        }
      } catch (e) {
        // fallthrough to map fallback
      }

      // Fallback to A:B map representation
      try {
        final map = await _readMapFromSheet(dashboardId, 'cards');
        if (map.isNotEmpty) {
          final decoded = <String, dynamic>{};
          map.forEach((k, v) {
            try {
              decoded[k] = jsonDecode(v);
            } catch (_) {
              decoded[k] = v;
            }
          });
          return decoded;
        }
      } catch (_) {}

      return null;
    } catch (e) {
      debugPrint('Error reading dashboard by id $dashboardId: $e');
      return null;
    }
  }

  /// Read tabs spreadsheet by id. Returns a List of decoded tab objects or null.
  Future<List<dynamic>?> readTabsById(String tabsId) async {
    try {
      final ss = await retryOp(() => sheetsApi.spreadsheets.get(tabsId));
      final sheetTitles = ss.sheets?.map((s) => s.properties?.title ?? '').where((t) => t.isNotEmpty).toList() ?? [];
      final tabs = <dynamic>[];
      for (var title in sheetTitles) {
        // Read tab as key/value rows in A:B — values are JSON-encoded.
        try {
          final map = await _readMapFromSheet(tabsId, title);
          if (map.isNotEmpty) {
            final decoded = <String, dynamic>{};
            map.forEach((k, v) {
              final key = k.toString();
              final raw = (v ?? '').toString();
              if (raw.trim().isEmpty || raw.trim() == 'null') {
                decoded[key] = null;
                return;
              }
              try {
                decoded[key] = jsonDecode(raw);
              } catch (_) {
                decoded[key] = raw;
              }
            });
            // Ensure required fields exist so callers (TabConfig.fromJson) don't crash
            if (decoded['id'] == null || (decoded['id'] is String && (decoded['id'] as String).trim().isEmpty)) {
              decoded['id'] = title;
            }
            if (decoded['label'] == null || (decoded['label'] is String && (decoded['label'] as String).trim().isEmpty)) {
              decoded['label'] = title;
            }
            tabs.add(decoded);
            continue;
          }
          // If map is empty, still add an empty map to preserve sheet order
          tabs.add(<String, dynamic>{'id': title, 'label': title});
        } catch (e) {
          debugPrint('Error reading tab sheet $title in $tabsId: $e');
          // Add empty placeholder to keep behavior predictable
          tabs.add(<String, dynamic>{'id': title, 'label': title});
        }
      }
      if (tabs.isEmpty) return null;
      return tabs;
    } catch (e) {
      debugPrint('Error reading tabs by id $tabsId: $e');
      return null;
    }
  }


  Future<void> _writeMapToSheet(String fileId, String sheetTitle, Map<String, dynamic> data) async {
    try {
      // Clear first to avoid stale data. Use quoted sheet title for robustness.
      await sheetsApi.spreadsheets.values.clear(sheets.ClearValuesRequest(), fileId, "'$sheetTitle'!A:B");
      
      debugPrint('DriveSheetMixin: writing ${data.length} entries to $sheetTitle in $fileId');
      final rows = data.entries.map((e) => [e.key, jsonEncode(e.value)]).toList();
      final valueRange = sheets.ValueRange(values: rows);
      
      await sheetsApi.spreadsheets.values.update(
        valueRange,
        fileId,
        "'$sheetTitle'!A1",
        valueInputOption: 'RAW',
      );
    } catch (e) {
      debugPrint('Error writing to sheet $sheetTitle: $e');
      // Don't rethrow, try to continue
    }
  }

  Future<Map<String, String>> _readMapFromSheet(String fileId, String sheetTitle) async {
    try {
      // Use quoted sheet title for robustness.
      final response = await sheetsApi.spreadsheets.values.get(fileId, "'$sheetTitle'!A:B");
      final map = <String, String>{};
      if (response.values != null) {
        for (var row in response.values!) {
          if (row.length < 2) continue;
          final key = row[0].toString().trim();
          if (key.isEmpty) continue;
          final val = row[1] == null ? '' : row[1].toString();
          map[key] = val;
        }
      }
      return map;
    } catch (e) {
      debugPrint('Error reading sheet $sheetTitle: $e');
      return {};
    }
  }

  /// Write the settings map into a settings spreadsheet (sheet 'settings').
  Future<void> writeSettingsById(String settingsId, Map<String, dynamic> settings) async {
    try {
      await _writeMapToSheet(settingsId, 'settings', settings);
    } catch (e) {
      debugPrint('Error writing settings to $settingsId: $e');
      rethrow;
    }
  }

  /// Write dashboard cards to a dashboard spreadsheet id.
  Future<void> writeDashboardById(String dashboardId, dynamic dashboard) async {
    try {
      if (dashboard is Map) {
        await _writeMapToSheet(dashboardId, 'cards', dashboard as Map<String, dynamic>);
      } else if (dashboard is List) {
        final rows = (dashboard).map((c) => [jsonEncode(c)]).toList();
        await retryOp(() => sheetsApi.spreadsheets.values.update(sheets.ValueRange(values: rows), dashboardId, 'cards!A1', valueInputOption: 'RAW'));
      }
    } catch (e) {
      debugPrint('Error writing dashboard to $dashboardId: $e');
      rethrow;
    }
  }

  /// Write tabs (each tab as a sheet with JSON in A1) to a tabs spreadsheet id.
  Future<void> writeTabsById(String tabsId, List<dynamic> tabs) async {
    try {
      // Fetch existing sheet titles once to avoid attempting to create duplicates
      final ss = await retryOp(() => sheetsApi.spreadsheets.get(tabsId));
      final existingTitles = ss.sheets?.map((s) => s.properties?.title ?? '').where((t) => t.isNotEmpty).toSet() ?? <String>{};

      for (var t in tabs) {
        final tid = (t is Map && t['id'] != null) ? t['id'].toString() : DateTime.now().microsecondsSinceEpoch.toString();

        if (!existingTitles.contains(tid)) {
          try {
            // Attempt to add sheet; if it fails because it already exists, skip gracefully
            await sheetsApi.spreadsheets.batchUpdate(
              sheets.BatchUpdateSpreadsheetRequest(requests: [
                sheets.Request(addSheet: sheets.AddSheetRequest(properties: sheets.SheetProperties(title: tid)))
              ]),
              tabsId,
            );
            existingTitles.add(tid);
          } catch (e) {
            final msg = e.toString().toLowerCase();
            if (msg.contains('already exists') || msg.contains('a sheet with the name')) {
              debugPrint('Sheet $tid already exists in $tabsId; skipping creation.');
            } else {
              rethrow;
            }
          }
        }

        // Always store tab as key/value rows in A:B. If the tab object is not
        // a Map, store it under key 'raw'. Values are stored JSON-encoded.
        try {
          await retryOp(() => sheetsApi.spreadsheets.values.clear(sheets.ClearValuesRequest(), tabsId, '$tid!A:B'));

          final rows = <List<Object>>[];
          if (t is Map) {
            for (var entry in (t).entries) {
              rows.add([entry.key.toString(), jsonEncode(entry.value)]);
            }
          } else {
            rows.add(['raw', jsonEncode(t)]);
          }

          if (rows.isNotEmpty) {
            await retryOp(() => sheetsApi.spreadsheets.values.update(sheets.ValueRange(values: rows), tabsId, '$tid!A1', valueInputOption: 'RAW'));
          }
        } catch (e) {
          debugPrint('Error writing tab $tid as key/value rows: $e');
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('Error writing tabs to $tabsId: $e');
      rethrow;
    }
  }

  Future<String> createSpreadsheetInFolder(String folderId, String title) async {
    try {
      final driveFile = drive.File()
        ..name = title
        ..mimeType = 'application/vnd.google-apps.spreadsheet'
        ..parents = [folderId];

      final created = await retryOp(() => driveApi.files.create(driveFile, supportsAllDrives: true));
      final spreadsheetId = created.id!;
      debugPrint('Created spreadsheet $title directly in folder: $spreadsheetId');

      // Initialize renaming Sheet1 to the title
      final batchReq = sheets.BatchUpdateSpreadsheetRequest(
        requests: [
          sheets.Request(
            updateSheetProperties: sheets.UpdateSheetPropertiesRequest(
              properties: sheets.SheetProperties(
                sheetId: 0,
                title: title,
                gridProperties: sheets.GridProperties(frozenRowCount: 1),
              ),
              fields: 'title,gridProperties.frozenRowCount',
            ),
          ),
        ],
      );
      await retryOp(() => sheetsApi.spreadsheets.batchUpdate(batchReq, spreadsheetId));
      
      return spreadsheetId;
    } catch (e) {
      debugPrint('Error creating spreadsheet $title in folder $folderId: $e');
      rethrow;
    }
  }

  /// Updates a single key/value pair in a specific tab's sheet (A:B rows).
  Future<void> updateTabField(String tabsId, String tabId, String key, dynamic value) async {
    try {
      // 1. Fetch current rows to find the key
      final range = '$tabId!A:B';
      final response = await retryOp(() => sheetsApi.spreadsheets.values.get(tabsId, range));
      final rows = response.values ?? [];

      int foundIndex = -1;
      for (int i = 0; i < rows.length; i++) {
        if (rows[i].isNotEmpty && rows[i].first?.toString() == key) {
          foundIndex = i;
          break;
        }
      }

      final encodedValue = jsonEncode(value);

      if (foundIndex != -1) {
        // Update existing row. Columns are A (1) and B (2). Row is foundIndex + 1.
        final updateRange = '$tabId!B${foundIndex + 1}';
        await retryOp(() => sheetsApi.spreadsheets.values.update(
              sheets.ValueRange(values: [
                [encodedValue]
              ]),
              tabsId,
              updateRange,
              valueInputOption: 'RAW',
            ));
      } else {
        // Append new key/value row
        await retryOp(() => sheetsApi.spreadsheets.values.append(
              sheets.ValueRange(values: [
                [key, encodedValue]
              ]),
              tabsId,
              range,
              valueInputOption: 'RAW',
            ));
      }
      debugPrint('DriveSheetMixin: updated tab field $key in $tabId for spreadsheet $tabsId');
    } catch (e) {
      debugPrint('Error updating tab field $key in $tabId: $e');
      rethrow;
    }
  }

  /// Updates multiple key/value pairs in a specific tab's sheet (A:B rows).
  Future<void> updateTabFields(String tabsId, String tabId, Map<String, dynamic> fields) async {
    if (fields.isEmpty) return;
    try {
      // 1. Fetch current rows to find keys
      final range = '$tabId!A:B';
      final response = await retryOp(() => sheetsApi.spreadsheets.values.get(tabsId, range));
      final rows = response.values ?? [];

      final Map<String, int> keyToRowIndex = {};
      for (int i = 0; i < rows.length; i++) {
        if (rows[i].isNotEmpty) {
          keyToRowIndex[rows[i].first?.toString() ?? ''] = i;
        }
      }

      final List<List<Object>> toAppend = [];
      
      for (var entry in fields.entries) {
        final key = entry.key;
        final value = entry.value;
        final encodedValue = jsonEncode(value);

        if (keyToRowIndex.containsKey(key)) {
          // Update existing row
          final rowIndex = keyToRowIndex[key]!;
          final updateRange = '$tabId!B${rowIndex + 1}';
          await retryOp(() => sheetsApi.spreadsheets.values.update(
                sheets.ValueRange(values: [
                  [encodedValue]
                ]),
                tabsId,
                updateRange,
                valueInputOption: 'RAW',
              ));
        } else {
          // Add to append list
          toAppend.add([key, encodedValue]);
        }
      }

      if (toAppend.isNotEmpty) {
        await retryOp(() => sheetsApi.spreadsheets.values.append(
              sheets.ValueRange(values: toAppend),
              tabsId,
              range,
              valueInputOption: 'RAW',
            ));
      }
      debugPrint('DriveSheetMixin: updated ${fields.length} tab fields in $tabId for spreadsheet $tabsId');
    } catch (e) {
      debugPrint('Error updating tab fields in $tabId: $e');
      rethrow;
    }
  }

  Future<void> saveRecord(String moduleFolderId, String spreadsheetName, String sheetTitle, Map<String, dynamic> data) async {
    try {
      // 1. Find Spreadsheet
      // Use sheetTitle as the spreadsheet name to save each tab in a separate file
      String targetSpreadsheetName = sheetTitle;
      String? spreadsheetId = await getFileId(moduleFolderId, targetSpreadsheetName);
      
      if (spreadsheetId == null) {
        throw Exception('Spreadsheet $targetSpreadsheetName not found in module folder $moduleFolderId. Development or provisioning error.');
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

  /// Save a record directly to a known spreadsheet id (fileId).
  Future<void> saveRecordBySpreadsheetId(String spreadsheetId, String sheetTitle, Map<String, dynamic> data) async {
    try {
      // 1. Prepare Data with Technical Fields
      final recordId = data['record_id'] ?? DateTime.now().microsecondsSinceEpoch.toString();
      final finalData = Map<String, dynamic>.from(data);
      finalData['record_id'] = recordId;
      if (finalData['created_at'] == null) {
        finalData['created_at'] = DateTime.now().toIso8601String();
      }

      // 2. Extract Nested Lists (Tables)
      final nestedTables = <String, List<dynamic>>{};
      final keysToRemove = <String>[];
      final keysToEncode = <String>[];
      
      finalData.forEach((key, value) {
        if (value is List) {
          final isNestedTable = value.isNotEmpty && value.first is Map;
          if (isNestedTable) {
            nestedTables[key] = value;
            keysToRemove.add(key);
          } else {
            keysToEncode.add(key);
          }
        }
      });

      for (var key in keysToEncode) {
        finalData[key] = jsonEncode(finalData[key]);
      }

      for (var key in keysToRemove) {
        finalData.remove(key);
      }

      // 3. Save Main Record
      await _saveToSheet(spreadsheetId, sheetTitle, finalData);

      // 4. Save Nested Tables
      for (var entry in nestedTables.entries) {
        final subSheetTitle = '$sheetTitle.${entry.key}';
        for (var item in entry.value) {
          if (item is Map) {
            final itemData = Map<String, dynamic>.from(item);
            itemData['parent_record_id'] = recordId;
            if (itemData['sub_record_id'] == null) {
              itemData['sub_record_id'] = DateTime.now().microsecondsSinceEpoch.toString();
            }
            await _saveToSheet(spreadsheetId, subSheetTitle, itemData);
          }
        }
      }
    } catch (e) {
      debugPrint('Error saving record by spreadsheetId $spreadsheetId: $e');
      rethrow;
    }
  }

  /// Save multiple records in one batch to reduce API calls (used for initial seeding).
  Future<void> saveRecordsBatchBySpreadsheetId(String spreadsheetId, String sheetTitle, List<Map<String, dynamic>> records) async {
    if (records.isEmpty) return;
    try {
      // 1. Ensure sheet exists
      final spreadsheet = await retryOp(() => sheetsApi.spreadsheets.get(spreadsheetId));
      bool sheetExists = spreadsheet.sheets?.any((s) => s.properties?.title == sheetTitle) ?? false;
      if (!sheetExists) {
        await retryOp(() => sheetsApi.spreadsheets.batchUpdate(
          sheets.BatchUpdateSpreadsheetRequest(
            requests: [
              sheets.Request(
                addSheet: sheets.AddSheetRequest(
                  properties: sheets.SheetProperties(
                    title: sheetTitle,
                    gridProperties: sheets.GridProperties(frozenRowCount: 1),
                  ),
                ),
              ),
            ],
          ),
          spreadsheetId,
        ));
        debugPrint('Created sheet for batch: $sheetTitle');
      }

      // 2. Read existing headers. Use quotes and trimming for robustness.
      final headerResponse = await retryOp(() => sheetsApi.spreadsheets.values.get(spreadsheetId, "'$sheetTitle'!A1:ZZ1"));
      List<String> headers = [];
      if (headerResponse.values != null && headerResponse.values!.isNotEmpty) {
        headers = headerResponse.values!.first.map((e) => e.toString().trim()).toList();
      }

      // 3. Prepare main records and extract nested sub-tables
      final mainRecords = <Map<String, dynamic>>[];
      final nestedByIndex = <int, Map<String, List<Map<String, dynamic>>>>{};

      for (var i = 0; i < records.length; i++) {
        final orig = records[i];
        final record = Map<String, dynamic>.from(orig);
        if (record['record_id'] == null) record['record_id'] = DateTime.now().microsecondsSinceEpoch.toString();
        if (record['created_at'] == null) record['created_at'] = DateTime.now().toIso8601String();

        final nested = <String, List<Map<String, dynamic>>>{};
        final keys = record.keys.toList();
        for (var k in keys) {
          final v = record[k];
          if (v is List && v.isNotEmpty && v.first is Map) {
            nested[k] = v.cast<Map<String, dynamic>>();
            record.remove(k);
          } else if (v is List && v.isNotEmpty && v.first is! Map) {
            record[k] = jsonEncode(v);
          }
        }

        mainRecords.add(record);
        nestedByIndex[i] = nested;
      }

      // 4. Build union of headers from mainRecords only
      final unionHeaders = Set<String>.from(headers);
      for (var r in mainRecords) {
        for (var k in r.keys) {
          unionHeaders.add(k.toString());
        }
      }
      // Ensure technical fields present
      unionHeaders.add('record_id');
      unionHeaders.add('created_at');
      final finalHeaders = unionHeaders.toList();

      // 5. Update headers only if they changed
      if (headers.isEmpty) {
        await retryOp(() => sheetsApi.spreadsheets.values.append(
          sheets.ValueRange(values: [finalHeaders]),
          spreadsheetId,
          "'$sheetTitle'!A1",
          valueInputOption: 'RAW',
        ));
        headers = finalHeaders;
      } else {
        final newKeys = finalHeaders.where((k) => !headers.contains(k)).toList();
        if (newKeys.isNotEmpty) {
          headers = List<String>.from(headers)..addAll(newKeys);
          await retryOp(() => sheetsApi.spreadsheets.values.update(
            sheets.ValueRange(values: [headers]),
            spreadsheetId,
            "'$sheetTitle'!A1",
            valueInputOption: 'RAW',
          ));
        }
      }

      // 6. Prepare main rows aligned to headers
      final rows = <List<String>>[];
      for (var r in mainRecords) {
        final row = headers.map((h) => r[h]?.toString() ?? '').toList();
        rows.add(row);
      }

      // 7. Append all main rows in one call
      if (rows.isNotEmpty) {
        await retryOp(() => sheetsApi.spreadsheets.values.append(
          sheets.ValueRange(values: rows),
          spreadsheetId,
          '$sheetTitle!A1',
          valueInputOption: 'RAW',
          insertDataOption: 'INSERT_ROWS',
        ));
        debugPrint('Batch appended ${rows.length} rows to $sheetTitle in $spreadsheetId');
      }

      // 8. Handle nested tables: collect sub-rows grouped by sub-sheet
      final subHeadersMap = <String, List<String>>{};
      final subRowsMap = <String, List<List<String>>>{};

      for (var i = 0; i < records.length; i++) {
        final parent = mainRecords[i];
        final parentId = parent['record_id']?.toString();
        final nested = nestedByIndex[i] ?? {};
        for (var entryKey in nested.keys) {
          final subSheet = '$sheetTitle.$entryKey';
          final entries = nested[entryKey]!;
          final existing = subHeadersMap[subSheet] ?? <String>[];
          // ensure technical fields
          if (!existing.contains('sub_record_id')) existing.add('sub_record_id');
          if (!existing.contains('parent_record_id')) existing.add('parent_record_id');
          // collect all keys
          for (var e in entries) {
            for (var key in e.keys) {
              if (!existing.contains(key)) existing.add(key.toString());
            }
          }
          subHeadersMap[subSheet] = existing;
          subRowsMap[subSheet] = subRowsMap[subSheet] ?? [];
          for (var e in entries) {
            final mapE = Map<String, dynamic>.from(e);
            mapE['parent_record_id'] = parentId;
            if (mapE['sub_record_id'] == null) mapE['sub_record_id'] = DateTime.now().microsecondsSinceEpoch.toString();
            final row = existing.map((h) => mapE[h]?.toString() ?? '').toList();
            subRowsMap[subSheet]!.add(row);
          }
        }
      }

      // 9. Append sub-sheet rows (one call per sub-sheet)
      for (var subSheet in subHeadersMap.keys) {
        final subHeaders = subHeadersMap[subSheet]!;
        final subRows = subRowsMap[subSheet] ?? [];
        if (subRows.isEmpty) continue;

        // ensure sub-sheet exists
        final sheetMeta = await retryOp(() => sheetsApi.spreadsheets.get(spreadsheetId));
        final exists = sheetMeta.sheets?.any((s) => s.properties?.title == subSheet) ?? false;
        if (!exists) {
          await retryOp(() => sheetsApi.spreadsheets.batchUpdate(
            sheets.BatchUpdateSpreadsheetRequest(
              requests: [
                sheets.Request(
                  addSheet: sheets.AddSheetRequest(
                    properties: sheets.SheetProperties(
                      title: subSheet,
                      gridProperties: sheets.GridProperties(frozenRowCount: 1),
                    ),
                  ),
                )
              ],
            ),
            spreadsheetId,
          ));
        }

        // update headers for sub-sheet
        final subHeaderResp = await retryOp(() => sheetsApi.spreadsheets.values.get(spreadsheetId, '$subSheet!1:1'));
        List<String> existingHeaders = [];
        if (subHeaderResp.values != null && subHeaderResp.values!.isNotEmpty) {
          existingHeaders = subHeaderResp.values!.first.map((e) => e.toString()).toList();
        }
        if (existingHeaders.isEmpty) {
          await retryOp(() => sheetsApi.spreadsheets.values.append(
            sheets.ValueRange(values: [subHeaders]),
            spreadsheetId,
            '$subSheet!A1',
            valueInputOption: 'RAW',
          ));
        } else {
          final addKeys = subHeaders.where((k) => !existingHeaders.contains(k)).toList();
          if (addKeys.isNotEmpty) {
            existingHeaders.addAll(addKeys);
            await retryOp(() => sheetsApi.spreadsheets.values.update(
              sheets.ValueRange(values: [existingHeaders]),
              spreadsheetId,
              '$subSheet!1:1',
              valueInputOption: 'RAW',
            ));
          }
        }

        await retryOp(() => sheetsApi.spreadsheets.values.append(
          sheets.ValueRange(values: subRows),
          spreadsheetId,
          '$subSheet!A1',
          valueInputOption: 'RAW',
          insertDataOption: 'INSERT_ROWS',
        ));
        debugPrint('Batch appended ${subRows.length} rows to $subSheet');
      }
    } catch (e) {
      debugPrint('Error in saveRecordsBatchBySpreadsheetId: $e');
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
      final sheet = spreadsheet.sheets?.firstWhere(
        (s) => s.properties?.title == sheetTitle,
        orElse: () => spreadsheet.sheets!.first,
      );
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
                  endIndex: (rowIndex) + 1,
                ),
              ),
            ),
          ],
        ),
        spreadsheetId,
      ));

      debugPrint('Deleted record $recordId from $sheetTitle at row ${(rowIndex) + 1}');

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

  Future<void> deleteRecordBySpreadsheetId(String spreadsheetId, String sheetTitle, String recordId) async {
    try {
      // 1. Identify Row Index
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

      // 2. Get Sheet ID (GID)
      final spreadsheet = await retryOp(() => sheetsApi.spreadsheets.get(spreadsheetId));
      final sheet = spreadsheet.sheets?.firstWhere(
        (s) => s.properties?.title == sheetTitle,
        orElse: () => spreadsheet.sheets!.first,
      );
      final int? gid = sheet?.properties?.sheetId;

      if (gid == null) throw Exception("Sheet GID not found");

      // 3. Delete Row
      final request = sheets.BatchUpdateSpreadsheetRequest(
        requests: [
          sheets.Request(
            deleteDimension: sheets.DeleteDimensionRequest(
              range: sheets.DimensionRange(
                sheetId: gid,
                dimension: 'ROWS',
                startIndex: rowIndex,
                endIndex: rowIndex + 1,
              ),
            ),
          ),
        ],
      );

      await retryOp(() => sheetsApi.spreadsheets.batchUpdate(request, spreadsheetId));
    } catch (e) {
      debugPrint('Error deleting record by id: $e');
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
                properties: sheets.SheetProperties(
                  title: sheetTitle,
                  gridProperties: sheets.GridProperties(frozenRowCount: 1),
                ),
              ),
            ),
          ],
        ),
        spreadsheetId,
      ));
      debugPrint('Created sheet: $sheetTitle');
    }

    // 2. Handle Headers. Use quotes and trimming for robustness.
    final headerResponse = await retryOp(() => sheetsApi.spreadsheets.values.get(spreadsheetId, "'$sheetTitle'!A1:ZZ1"));
    List<String> headers = [];
    
    if (headerResponse.values != null && headerResponse.values!.isNotEmpty) {
      headers = headerResponse.values!.first.map((e) => e.toString().trim()).toList();
    }

    if (headers.isEmpty) {
      headers = data.keys.toList();
      await retryOp(() => sheetsApi.spreadsheets.values.append(
        sheets.ValueRange(values: [headers]),
        spreadsheetId,
        "'$sheetTitle'!A1",
        valueInputOption: 'RAW',
      ));
    } else {
      final newKeys = data.keys.where((k) => !headers.contains(k)).toList();
      if (newKeys.isNotEmpty) {
        headers.addAll(newKeys);
        await retryOp(() => sheetsApi.spreadsheets.values.update(
          sheets.ValueRange(values: [headers]),
          spreadsheetId,
          "'$sheetTitle'!A1",
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
        final idColResponse = await retryOp(() => sheetsApi.spreadsheets.values.get(spreadsheetId, "'$sheetTitle'!$colLetter:$colLetter"));
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
        "'$sheetTitle'!$recordRowIndex:$recordRowIndex",
        valueInputOption: 'RAW',
      ));
      debugPrint('Updated data in $sheetTitle at row $recordRowIndex');
    } else {
      await retryOp(() => sheetsApi.spreadsheets.values.append(
        sheets.ValueRange(values: [row]),
        spreadsheetId,
        "'$sheetTitle'!A1",
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
      debugPrint('fetchRecords: moduleFolderId=$moduleFolderId spreadsheetName=$spreadsheetName sheetTitle=$sheetTitle offset=$offset limit=$limit search=${searchQuery!=null}');
      // 1. Find Spreadsheet. Try spreadsheetName first, then fallback to sheetTitle.
      String? spreadsheetId = await getFileId(moduleFolderId, spreadsheetName);
      if (spreadsheetId == null && spreadsheetName != sheetTitle) {
        spreadsheetId = await getFileId(moduleFolderId, sheetTitle);
      }
      
      if (spreadsheetId == null) {
        debugPrint('fetchRecords: no spreadsheet found for "$spreadsheetName" (or fallback "$sheetTitle") in $moduleFolderId');
        return [];
      }
      debugPrint('fetchRecords: resolved spreadsheetId=$spreadsheetId');
      final sid = spreadsheetId!; // Non-null alias for stability

      // 2. Fetch Spreadsheet Metadata (to get sheet ID and titles)
      final spreadsheet = await retryOp(() => sheetsApi.spreadsheets.get(sid));
      final allSheetTitles = spreadsheet.sheets?.map((s) => s.properties?.title ?? '').toList() ?? [];
      final targetSheet = spreadsheet.sheets?.firstWhere(
        (s) => s.properties?.title == sheetTitle,
        orElse: () => spreadsheet.sheets!.first,
      );
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
      debugPrint(' _fetchSheetData: spreadsheetId=$spreadsheetId sheetTitle=$sheetTitle offset=$offset limit=$limit');
      // Always fetch headers first (Row 1). Use A1:ZZ1 with sheet name in quotes for robustness.
      final headerResponse = await retryOp(() => sheetsApi.spreadsheets.values.get(spreadsheetId, "'$sheetTitle'!A1:ZZ1"));
      final headerValues = headerResponse.values;
      if (headerValues == null || headerValues.isEmpty) return [];
      
      // Trim headers to avoid key mismatches due to trailing spaces
      final headers = headerValues.first.map((e) => e.toString().trim()).toList();

      // Calculate Data Range
      String range;
      final startRow = 2 + offset;
      if (limit != null) {
        final endRow = startRow + limit - 1;
        range = "'$sheetTitle'!A$startRow:ZZ$endRow";
      } else {
        range = "'$sheetTitle'!A$startRow:ZZ";
      }

      final response = await retryOp(() => sheetsApi.spreadsheets.values.get(spreadsheetId, range));
      final values = response.values;
      debugPrint(' _fetchSheetData: fetched rows=${values?.length ?? 0} for range=$range');

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
          final table = decoded['table'];
          if (table != null && table['cols'] != null) {
            final cols = table['cols'] as List;
            final types = cols.map((c) => (c as Map)['type']?.toString() ?? 'string').toList();
            _columnTypesCache[cacheKey] = types;
            return types;
          }
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
      // 1. Get raw headers from Row 1 for query building and fallback
      final headerResponse = await retryOp(() => sheetsApi.spreadsheets.values.get(spreadsheetId, "'$sheetTitle'!A1:ZZ1"));
      final rawHeaders = headerResponse.values?.first.map((e) => e.toString().trim()).toList() ?? [];
      if (rawHeaders.isEmpty) return [];

      // 2. Build Query
      String tq = "SELECT *";
      final whereClauses = <String>[];
      
      // Handle Search Query
      if (query != null && query.isNotEmpty) {
        final searchParts = <String>[];
        // Limit to first 50 columns to keep query string manageable
        final searchLimit = rawHeaders.length > 50 ? 50 : rawHeaders.length;
        
        // Try to get actual column types from Gviz metadata
        final actualTypes = await _getSheetColumnTypes(spreadsheetId, gid);
        
        // Fallback keywords for columns that are strictly numeric or non-text (dates, booleans).
        final strictlyNonText = [
          'qty', 'quantity', 'price', 'amount', 'total', 'cost', 
          'tax', 'discount', 'date', 'time', 'lat', 'long', 'zip', 'postcode', 
          'balance', 'ledger', 'credit', 'debit', 'value', 'count', 'score', 'percent',
          'is_', 'has_', 'can_', 'are_', 'was_', 'phone', 'mobile', 'tel'
        ];

        for (var i = 0; i < searchLimit; i++) {
          final col = _indexToColumn(i);
          final header = rawHeaders[i].toLowerCase();
          
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
            searchParts.add("lower($col) contains '${query.toLowerCase().replaceAll("'", "''")}'");
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
        
        final fieldIndex = rawHeaders.indexOf(field);
        if (fieldIndex != -1) {
          final col = _indexToColumn(fieldIndex);
          String? clause;
          
          // Try to get actual column type from Gviz metadata if available
          final actualTypes = await _getSheetColumnTypes(spreadsheetId, gid);
          bool isNumericCol = false;
          if (actualTypes.length > fieldIndex) {
            final typeStr = actualTypes[fieldIndex].toLowerCase();
            isNumericCol = typeStr == 'number' || typeStr == 'boolean';
          }

          // Stringify value for Gviz
          String gvizVal = val.toString();
          // Use heuristic if metadata didn't definitely say it's numeric
          bool isNumericVal = num.tryParse(gvizVal) != null;
          bool isBoolVal = gvizVal.toLowerCase() == 'true' || gvizVal.toLowerCase() == 'false';
          String escapedVal = gvizVal.replaceAll("'", "''");
          
          // If the column is definitely numeric OR (no metadata AND looks numeric), omit quotes
          bool useNoQuotes = isNumericCol || (actualTypes.isEmpty && (isNumericVal || isBoolVal));

          if (op == '==' || op == '=') {
            if (useNoQuotes) {
              clause = "$col = $gvizVal";
            } else {
              clause = "$col = '$escapedVal'";
            }
          } else if (op == '!=') {
            if (useNoQuotes) {
              clause = "$col != $gvizVal";
            } else {
              clause = "$col != '$escapedVal'";
            }
          } else if (op == 'contains') {
            clause = "lower($col) contains '${escapedVal.toLowerCase()}'";
          } else if (op == '>' || op == '>=' || op == '<' || op == '<=') {
            clause = useNoQuotes ? "$col $op $gvizVal" : "$col $op '$escapedVal'";
          } else if (op == 'startsWith') {
            clause = "lower($col) starts with '${escapedVal.toLowerCase()}'";
          } else if (op == 'endsWith') {
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
      
      // Case-insensitive record_id lookup in rawHeaders
      final ridIdx = rawHeaders.indexWhere((h) => h.toLowerCase() == 'record_id');
      if (ridIdx != -1) {
        tq += " ORDER BY ${_indexToColumn(ridIdx)} ${descending ? 'DESC' : 'ASC'}";
      }

      tq += " LIMIT $limit OFFSET $offset";

      // 3. Request from Google Vis API
      final url = 'https://docs.google.com/spreadsheets/d/$spreadsheetId/gviz/tq?tqx=out:json&tq=${Uri.encodeComponent(tq)}${gid != null ? '&gid=$gid' : ''}&headers=1';
      debugPrint('GViz Search URL: $url');
      
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

      final List<dynamic> gvizCols = table['cols'] ?? [];
      final List<String> effectiveHeaders = [];
      
      // Robustly align headers even if GViz skips columns or Sheets API response starts at non-A1
      for (int i = 0; i < gvizCols.length; i++) {
        String label = (gvizCols[i]['label']?.toString() ?? '').trim();
        // If GViz label is generic or missing, and we have a raw header for this physical index, use it
        if ((label.isEmpty || label.length == 1) && i < rawHeaders.length) {
          effectiveHeaders.add(rawHeaders[i]);
        } else if (label.isNotEmpty) {
          effectiveHeaders.add(label);
        } else {
          effectiveHeaders.add('col_$i');
        }
      }

      final List<Map<String, dynamic>> results = [];
      final rows = table['rows'] as List;

      for (var row in rows) {
        final cells = row['c'] as List;
        final record = <String, dynamic>{};
        bool isEmptyRow = true;
        for (var i = 0; i < effectiveHeaders.length; i++) {
          if (i < cells.length && cells[i] != null) {
            final cell = cells[i] is Map ? cells[i] as Map : {};
            // v is raw value, f is formatted string (fallback if v is null for objects)
            final val = cell['v'] ?? cell['f'];
            record[effectiveHeaders[i]] = val;
            if (val != null && val.toString().trim().isNotEmpty) isEmptyRow = false;
          } else {
            record[effectiveHeaders[i]] = null;
          }
        }
        if (!isEmptyRow) {
          results.add(record);
        }
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

  /// Fetch records when you already have the spreadsheetId (fileId).
  Future<List<Map<String, dynamic>>> fetchRecordsBySpreadsheetId(
    String spreadsheetId,
    String sheetTitle, {
      int offset = 0,
      int? limit,
      bool fetchSubTables = true,
      bool descending = false,
      String? searchQuery,
      Map<String, dynamic>? quickFilter,
  }) async {
    try {
      debugPrint('fetchRecordsBySpreadsheetId: spreadsheetId=$spreadsheetId sheetTitle=$sheetTitle offset=$offset limit=$limit search=${searchQuery!=null}');
      // 1. Fetch Spreadsheet Metadata
      final spreadsheet = await retryOp(() => sheetsApi.spreadsheets.get(spreadsheetId));
      final allSheetTitles = spreadsheet.sheets?.map((s) => s.properties?.title ?? '').toList() ?? [];
      
      // Find the specific sheet by title. 
      // Do NOT default to the first sheet if a specific title was requested but not found.
      final targetSheet = spreadsheet.sheets?.firstWhere(
        (s) => s.properties?.title == sheetTitle,
        orElse: () => throw Exception('Sheet with title "$sheetTitle" not found in spreadsheet $spreadsheetId'),
      );
      final int? gid = targetSheet?.properties?.sheetId;

      // 2. Fetch sub-tables if requested
      List<String> subTableSheets = [];
      if (fetchSubTables) {
        subTableSheets = allSheetTitles.where((t) => t.startsWith('$sheetTitle.')).toList();
      }

      // 3. Fetch Records (reuse server-side search when appropriate)
      bool isSearch = searchQuery != null && searchQuery.length >= 2;
      bool hasQuickFilter = quickFilter != null && quickFilter['field'] != null && quickFilter['operator'] != null;

      List<Map<String, dynamic>> finalRecords;
      if (isSearch || descending || hasQuickFilter) {
        try {
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
          debugPrint('Server-side search/filter/sort failed for spreadsheetId $spreadsheetId: $e. Falling back to local fetch...');
          finalRecords = await _fetchSheetData(spreadsheetId, sheetTitle, offset: offset, limit: limit);

          if (isSearch) {
            finalRecords = finalRecords.where((item) => item.values.any((val) => val.toString().toLowerCase().contains(searchQuery.toLowerCase()))).toList();
          }

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
        }
      } else {
        finalRecords = await _fetchSheetData(spreadsheetId, sheetTitle, offset: offset, limit: limit);
      }

      // 4. If requested, fetch and attach nested sub-tables
      if (fetchSubTables && finalRecords.isNotEmpty) {
        for (var sub in subTableSheets) {
          try {
            // Build a map of parent record_id -> list of subs for THIS sub-sheet ONLY
            final subTables = <String, List<Map<String, dynamic>>>{};
            final subRecords = await _fetchSheetData(spreadsheetId, sub);
            
            // Derive field name from sub-sheet title: sheet.subname -> subname
            final parts = sub.split('.');
            final fieldName = parts.length > 1 ? parts.sublist(1).join('.') : 'sub';

            for (var s in subRecords) {
              final parentId = s['parent_record_id']?.toString() ?? s['parent_record']?.toString() ?? s['parent_id']?.toString();
              if (parentId != null) {
                subTables[parentId] = subTables[parentId] ?? [];
                subTables[parentId]!.add(s);
              }
            }

            // Attach to main records
            for (var main in finalRecords) {
              final recordId = main['record_id']?.toString() ?? main['id']?.toString();
              if (recordId != null) {
                main[fieldName] = subTables[recordId] ?? [];
              }
            }
          } catch (e) {
            debugPrint('Error fetching sub-table $sub for spreadsheetId $spreadsheetId: $e');
          }
        }
      }

      return finalRecords;
    } catch (e) {
      debugPrint('Error fetching records by spreadsheetId $spreadsheetId: $e');
      rethrow;
    }
  }
}
