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
      // We'll create three separate spreadsheets: settings, dashboard, and tabs.
      final settingsTitle = '${fileName}_settings';
      final dashboardTitle = '${fileName}_dashboard';
      final tabsTitle = '${fileName}_tabs';

      // Settings spreadsheet with a 'settings' and 'meta' sheet
      final settingsSpreadsheet = sheets.Spreadsheet(
        properties: sheets.SpreadsheetProperties(title: settingsTitle),
        sheets: [
          sheets.Sheet(properties: sheets.SheetProperties(title: 'settings')),
          sheets.Sheet(properties: sheets.SheetProperties(title: 'meta')),
        ],
      );
      final createdSettings = await retryOp(() => sheetsApi.spreadsheets.create(settingsSpreadsheet));
      final settingsId = createdSettings.spreadsheetId!;

      // Dashboard spreadsheet with a 'cards' sheet
      final dashboardSpreadsheet = sheets.Spreadsheet(
        properties: sheets.SpreadsheetProperties(title: dashboardTitle),
        sheets: [sheets.Sheet(properties: sheets.SheetProperties(title: 'cards'))],
      );
      final createdDashboard = await retryOp(() => sheetsApi.spreadsheets.create(dashboardSpreadsheet));
      final dashboardId = createdDashboard.spreadsheetId!;

      // Tabs spreadsheet: include sheets for each tab during creation to avoid 'Sheet1'
      final tabsList = (config['tabs'] as List? ?? []).cast<dynamic>();
      final List<sheets.Sheet> initialTabsSheets = [];
      for (var t in tabsList) {
        final tid = (t is Map && t['id'] != null) ? t['id'].toString() : null;
        if (tid != null) {
          initialTabsSheets.add(sheets.Sheet(properties: sheets.SheetProperties(title: tid)));
        }
      }

      final tabsSpreadsheet = sheets.Spreadsheet(
        properties: sheets.SpreadsheetProperties(title: tabsTitle),
        sheets: initialTabsSheets.isNotEmpty
            ? initialTabsSheets
            : [sheets.Sheet(properties: sheets.SheetProperties(title: 'meta'))],
      );
      final createdTabs = await retryOp(() => sheetsApi.spreadsheets.create(tabsSpreadsheet));
      final tabsId = createdTabs.spreadsheetId!;

      debugPrint('Created settings: $settingsTitle ($settingsId)');
      debugPrint('Created dashboard: $dashboardTitle ($dashboardId)');
      debugPrint('Created tabs: $tabsTitle ($tabsId)');

      // Move all files into the target folder
      Future<void> moveToFolder(String fid) async {
        try {
          final file = await retryOp(() => driveApi.files.get(fid, $fields: 'parents', supportsAllDrives: true)) as drive.File;
          final previousParents = file.parents?.join(',') ?? '';
          if (previousParents.isNotEmpty) {
            await retryOp(() => driveApi.files.update(drive.File(), fid, addParents: folderId, removeParents: previousParents, $fields: 'id, parents'));
          } else {
            await retryOp(() => driveApi.files.update(drive.File(), fid, addParents: folderId, $fields: 'id, parents'));
          }
        } catch (e) {
          debugPrint('Moving $fid to folder failed: $e');
        }
      }

      await moveToFolder(settingsId);
      await moveToFolder(dashboardId);
      await moveToFolder(tabsId);

      // Store references to dashboard and tabs in settings.meta sheet for later lookup
      final metaMap = {'dashboard_id': dashboardId, 'tabs_id': tabsId};
      await _writeMapToSheet(settingsId, 'meta', metaMap);

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
          final rows = (cards as List).map((c) => [jsonEncode(c)]).toList();
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

      return settingsId;
    } catch (e) {
      debugPrint('Error creating module config: $e');
      rethrow;
    }
  }

  /// Updates the module configuration in the spreadsheet.
  Future<void> updateModuleConfig(String fileId, Map<String, dynamic> config) async {
    // fileId is settings spreadsheet id. Lookup meta to find dashboard and tabs sheets
    try {
      if (config.containsKey('settings')) {
        await _writeMapToSheet(fileId, 'settings', config['settings'] ?? {});
      }

      final meta = await _readMapFromSheet(fileId, 'meta');
      final dashboardId = meta['dashboard_id'];
      final tabsId = meta['tabs_id'];

      if (config.containsKey('dashboard') && dashboardId != null) {
        final cards = config['dashboard'];
        if (cards is Map) {
          await _writeMapToSheet(dashboardId, 'cards', cards as Map<String, dynamic>);
        } else if (cards is List) {
          final rows = (cards as List).map((c) => [jsonEncode(c)]).toList();
          await retryOp(() => sheetsApi.spreadsheets.values.update(sheets.ValueRange(values: rows), dashboardId, 'cards!A1', valueInputOption: 'RAW'));
        }
      }

      if (config.containsKey('tabs') && tabsId != null) {
        final tabs = (config['tabs'] as List).cast<dynamic>();
        if (tabs.isNotEmpty) {
          await writeTabsById(tabsId, tabs);
        }
      }
    } catch (e) {
      debugPrint('Error updating module config: $e');
    }
  }

  /// Reads the module configuration from the spreadsheet.
  Future<Map<String, dynamic>?> readModuleConfig(String fileId) async {
    final config = <String, dynamic>{};
    try {
      // Settings are stored in this spreadsheet (fileId)
      final settingsMap = await _readMapFromSheet(fileId, 'settings');
      if (settingsMap.isEmpty) {
        debugPrint('Settings sheet is empty or missing for $fileId');
      } else {
        config['settings'] = settingsMap.map((k, v) => MapEntry(k, jsonDecode(v)));
      }

      // Read meta to get dashboard and tabs spreadsheet IDs
      final meta = await _readMapFromSheet(fileId, 'meta');
      final dashboardId = meta['dashboard_id'];
      final tabsId = meta['tabs_id'];

      if (dashboardId != null) {
        // Read cards sheet; prefer A1 JSON rows or A:B map
        try {
          final resp = await retryOp(() => sheetsApi.spreadsheets.values.get(dashboardId, 'cards!A1:Z'));
          if (resp.values != null && resp.values!.isNotEmpty) {
            final firstRow = resp.values!.first;
            // decide if rows contain JSON strings
            if (firstRow.isNotEmpty && firstRow.first is String && (firstRow.first as String).trim().startsWith('{')) {
              config['dashboard'] = resp.values!.map((r) => jsonDecode(r.first as String)).toList();
            } else {
              // fallback: map form
              final map = await _readMapFromSheet(dashboardId, 'cards');
              if (map.isNotEmpty) config['dashboard'] = map.map((k, v) => MapEntry(k, jsonDecode(v)));
            }
          }
        } catch (e) {
          debugPrint('Error reading dashboard: $e');

          // Attempt best-effort fallback: look for a sibling '<base>_dashboard' in the same folder as the settings file
          try {
            final fileMeta = await retryOp(() => driveApi.files.get(fileId, $fields: 'name, parents', supportsAllDrives: true)) as drive.File;
            final name = fileMeta.name ?? '';
            final parents = fileMeta.parents ?? [];
            if (name.endsWith('_settings') && parents.isNotEmpty) {
              final base = name.substring(0, name.length - '_settings'.length);
              for (var p in parents) {
                try {
                  final list = await driveApi.files.list(
                    q: "'${p}' in parents and name = '${base}_dashboard' and trashed = false",
                    $fields: 'files(id, name)',
                    includeItemsFromAllDrives: true,
                    supportsAllDrives: true,
                  );
                  if (list.files != null && list.files!.isNotEmpty) {
                    final found = list.files!.first;
                    final fallbackId = found.id;
                    // Try reading from the found spreadsheet id
                    final resp2 = await retryOp(() => sheetsApi.spreadsheets.values.get(fallbackId!, 'cards!A1:Z'));
                    if (resp2.values != null && resp2.values!.isNotEmpty) {
                      final firstRow = resp2.values!.first;
                      if (firstRow.isNotEmpty && firstRow.first is String && (firstRow.first as String).trim().startsWith('{')) {
                        config['dashboard'] = resp2.values!.map((r) => jsonDecode(r.first as String)).toList();
                      } else {
                        final map = await _readMapFromSheet(fallbackId!, 'cards');
                        if (map.isNotEmpty) config['dashboard'] = map.map((k, v) => MapEntry(k, jsonDecode(v)));
                      }
                      break;
                    }
                  }
                } catch (_) {}
              }
            }
          } catch (_) {}
        }
      }

      if (tabsId != null) {
        try {
          final read = await readTabsById(tabsId);
          if (read != null) config['tabs'] = read;
        } catch (e) {
          debugPrint('Error reading tabs: $e');

          // Migration step: if A:B read failed, attempt a one-time legacy A1 read and migrate to A:B
          try {
            final ss = await retryOp(() => sheetsApi.spreadsheets.get(tabsId));
            final sheetTitles = ss.sheets?.map((s) => s.properties?.title ?? '').where((t) => t.isNotEmpty).toList() ?? [];
            final legacyTabs = <dynamic>[];
            for (var title in sheetTitles) {
              try {
                final resp = await retryOp(() => sheetsApi.spreadsheets.values.get(tabsId, '$title!A1'));
                if (resp.values != null && resp.values!.isNotEmpty) {
                  final cell = resp.values!.first.first;
                  if (cell is String && cell.trim().isNotEmpty) {
                    try {
                      legacyTabs.add(jsonDecode(cell));
                    } catch (_) {}
                  }
                }
              } catch (_) {}
            }
            if (legacyTabs.isNotEmpty) {
              // rewrite tabs using A:B format and continue
              try {
                await writeTabsById(tabsId, legacyTabs);
                config['tabs'] = legacyTabs;
              } catch (_) {}
            }
          } catch (_) {}

          // Attempt fallback: look for '<base>_tabs' sibling in settings parent folder and try reading with readTabsById
          try {
            final fileMeta = await retryOp(() => driveApi.files.get(fileId, $fields: 'name, parents', supportsAllDrives: true)) as drive.File;
            final name = fileMeta.name ?? '';
            final parents = fileMeta.parents ?? [];
            if (name.endsWith('_settings') && parents.isNotEmpty) {
              final base = name.substring(0, name.length - '_settings'.length);
              for (var p in parents) {
                try {
                  final list = await driveApi.files.list(
                    q: "'${p}' in parents and name = '${base}_tabs' and trashed = false",
                    $fields: 'files(id, name)',
                    includeItemsFromAllDrives: true,
                    supportsAllDrives: true,
                  );
                  if (list.files != null && list.files!.isNotEmpty) {
                    final found = list.files!.first;
                    final fallbackId = found.id;
                    final readFb = await readTabsById(fallbackId!);
                    if (readFb != null) {
                      config['tabs'] = readFb;
                      break;
                    }
                  }
                } catch (_) {}
              }
            }
          } catch (_) {}
        }
      }

      if (config.isEmpty || (config['settings'] == null && config['tabs'] == null)) {
        return null;
      }
      return config;
    } catch (e) {
      debugPrint('Error reading module config: $e');
      return null;
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
      // Clear first to avoid stale data
      await sheetsApi.spreadsheets.values.clear(sheets.ClearValuesRequest(), fileId, '$sheetTitle!A:B');
      
      debugPrint('DriveSheetMixin: writing ${data.length} entries to $sheetTitle in $fileId');
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
          if (row.isEmpty) continue;
          final rawKey = row.length >= 1 ? row[0] : null;
          if (rawKey == null) continue;
          final key = rawKey.toString().trim();
          if (key.isEmpty) continue;
          final rawVal = row.length >= 2 ? row[1] : '';
          final val = rawVal == null ? '' : rawVal.toString();
          map[key] = val;
        }
      }
      return map;
    } catch (e) {
      debugPrint('Error reading sheet $sheetTitle: $e');
      return {};
    }
  }

  /// Read the 'meta' sheet from a settings spreadsheet id.
  Future<Map<String, String>> readMetaBySettingsId(String settingsId) async {
    try {
      return await _readMapFromSheet(settingsId, 'meta');
    } catch (e) {
      debugPrint('Error reading meta for $settingsId: $e');
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
        final rows = (dashboard as List).map((c) => [jsonEncode(c)]).toList();
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
            for (var entry in (t as Map).entries) {
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

  /// Write the 'meta' sheet for a settings spreadsheet.
  Future<void> writeMetaBySettingsId(String settingsId, Map<String, String> meta) async {
    try {
      await _writeMapToSheet(settingsId, 'meta', meta.cast<String, dynamic>());
    } catch (e) {
      debugPrint('Error writing meta to $settingsId: $e');
      rethrow;
    }
  }

  /// Create a new spreadsheet and move it into the target folder. Returns new spreadsheet id.
  Future<String> createSpreadsheetInFolder(String folderId, String title) async {
    try {
      final spreadsheet = sheets.Spreadsheet(
        properties: sheets.SpreadsheetProperties(title: title),
        sheets: [
          sheets.Sheet(properties: sheets.SheetProperties(title: 'data'))
        ],
      );
      final created = await retryOp(() => sheetsApi.spreadsheets.create(spreadsheet));
      final newId = created.spreadsheetId!;

      final file = await retryOp(() => driveApi.files.get(newId, $fields: 'parents', supportsAllDrives: true)) as drive.File;
      final previousParents = file.parents?.join(',') ?? '';
      if (previousParents.isNotEmpty) {
        await retryOp(() => driveApi.files.update(drive.File(), newId, addParents: folderId, removeParents: previousParents, $fields: 'id, parents'));
      } else {
        await retryOp(() => driveApi.files.update(drive.File(), newId, addParents: folderId, $fields: 'id, parents'));
      }

      return newId;
    } catch (e) {
      debugPrint('Error creating spreadsheet in folder $folderId: $e');
      rethrow;
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
          sheets: [
            sheets.Sheet(
              properties: sheets.SheetProperties(title: sheetTitle),
            )
          ],
        );
        final created = await retryOp(() => sheetsApi.spreadsheets.create(spreadsheet));
        spreadsheetId = created.spreadsheetId!;
        
        // Move to folder
          final file = await retryOp(() async {
            final result = await driveApi.files.get(spreadsheetId!, $fields: 'id, parents', supportsAllDrives: true);
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
                addSheet: sheets.AddSheetRequest(properties: sheets.SheetProperties(title: sheetTitle)),
              ),
            ],
          ),
          spreadsheetId,
        ));
        debugPrint('Created sheet for batch: $sheetTitle');
      }

      // 2. Read existing headers
      final headerResponse = await retryOp(() => sheetsApi.spreadsheets.values.get(spreadsheetId, '$sheetTitle!1:1'));
      List<String> headers = [];
      if (headerResponse.values != null && headerResponse.values!.isNotEmpty) {
        headers = headerResponse.values!.first.map((e) => e.toString()).toList();
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
        for (var k in r.keys) unionHeaders.add(k.toString());
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
          '$sheetTitle!A1',
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
            '$sheetTitle!1:1',
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
              requests: [sheets.Request(addSheet: sheets.AddSheetRequest(properties: sheets.SheetProperties(title: subSheet)))],
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
      debugPrint('fetchRecords: moduleFolderId=$moduleFolderId spreadsheetName=$spreadsheetName sheetTitle=$sheetTitle offset=$offset limit=$limit search=${searchQuery!=null}');
      // 1. Find Spreadsheet
      String targetSpreadsheetName = sheetTitle;
      String? spreadsheetId = await getFileId(moduleFolderId, targetSpreadsheetName);
      
      if (spreadsheetId == null) {
        debugPrint('fetchRecords: no spreadsheet found for $targetSpreadsheetName in $moduleFolderId');
        return [];
      }
      debugPrint('fetchRecords: resolved spreadsheetId=$spreadsheetId');

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
      debugPrint(' _fetchSheetData: spreadsheetId=$spreadsheetId sheetTitle=$sheetTitle offset=$offset limit=$limit');
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
      final targetSheet = spreadsheet.sheets?.firstWhere((s) => s.properties?.title == sheetTitle);
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
            finalRecords = finalRecords.where((item) => item.values.any((val) => val.toString().toLowerCase().contains(searchQuery!.toLowerCase()))).toList();
          }

          if (hasQuickFilter) {
            final field = quickFilter!['field'] as String;
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
        // Build a map of parent record_id -> list of subs
        final subTables = <String, List<Map<String, dynamic>>>{};
        for (var sub in subTableSheets) {
          try {
            final subRecords = await _fetchSheetData(spreadsheetId, sub);
            // Derive field name from sub-sheet title: sheet.subname -> subname
            final parts = sub.split('.');
            final fieldName = parts.length > 1 ? parts.sublist(1).join('.') : 'sub';

            for (var s in subRecords) {
              final parentId = s['parent_record_id']?.toString();
              if (parentId != null) {
                subTables[parentId] = subTables[parentId] ?? [];
                subTables[parentId]!.add(s);
              }
            }

            // Attach to main records
            for (var main in finalRecords) {
              final recordId = main['record_id']?.toString();
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
