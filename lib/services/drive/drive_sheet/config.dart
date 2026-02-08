import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'mixin.dart';

mixin DriveSheetConfig on DriveSheetMixin {
  /// Creates a Google Sheet for configuration with multiple sheets.
  Future<Map<String, String>> createModuleConfig(String folderId, String fileName, Map<String, dynamic> config) async {
    try {
      final settingsTitle = '${fileName}_settings';
      final dashboardTitle = '${fileName}_dashboard';
      final tabsTitle = '${fileName}_tabs';

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

      final tabsFile = drive.File()
        ..name = tabsTitle
        ..mimeType = 'application/vnd.google-apps.spreadsheet'
        ..parents = [folderId];
      final createdTabs = await retryOp(() => driveApi.files.create(tabsFile, supportsAllDrives: true));
      final tabsId = createdTabs.id!;

      final tabsList = (config['tabs'] as List? ?? []).cast<dynamic>();
      final List<sheets.Request> tabRequests = [];
      
      if (tabsList.isNotEmpty) {
        final tid0 = (tabsList[0] is Map && tabsList[0]['id'] != null) ? tabsList[0]['id'].toString() : 'Sheet1';
        tabRequests.add(sheets.Request(updateSheetProperties: sheets.UpdateSheetPropertiesRequest(
          properties: sheets.SheetProperties(sheetId: 0, title: tid0),
          fields: 'title',
        )));
        
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

      await _writeMapToSheet(settingsId, 'settings', config['settings'] ?? {});

      if (config.containsKey('dashboard')) {
        final cards = config['dashboard'];
        if (cards is Map) {
          await _writeMapToSheet(dashboardId, 'cards', cards as Map<String, dynamic>);
        } else if (cards is List) {
          final rows = (cards).map((c) => [jsonEncode(c)]).toList();
          await retryOp(() => sheetsApi.spreadsheets.values.update(sheets.ValueRange(values: rows), dashboardId, 'cards!A1', valueInputOption: 'RAW'));
        }
      }

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

  Future<void> updateModuleConfig(String fileId, Map<String, dynamic> config) async {
    try {
      if (config.containsKey('settings')) {
        await _writeMapToSheet(fileId, 'settings', config['settings'] ?? {});
      }
    } catch (e) {
      debugPrint('Error updating module config: $e');
    }
  }

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

  Future<dynamic> readDashboardById(String dashboardId) async {
    try {
      try {
        final resp = await retryOp(() => sheetsApi.spreadsheets.values.get(dashboardId, 'cards!A1:Z'));
        if (resp.values != null && resp.values!.isNotEmpty) {
          final firstRow = resp.values!.first;
          if (firstRow.isNotEmpty && firstRow.first is String && (firstRow.first as String).trim().startsWith('{')) {
            return resp.values!.map((r) => jsonDecode(r.first as String)).toList();
          }
        }
      } catch (_) {}

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
      return null;
    } catch (e) {
      debugPrint('Error reading dashboard by id $dashboardId: $e');
      return null;
    }
  }

  Future<List<dynamic>?> readTabsById(String tabsId) async {
    try {
      final ss = await retryOp(() => sheetsApi.spreadsheets.get(tabsId));
      final sheetTitles = ss.sheets?.map((s) => s.properties?.title ?? '').where((t) => t.isNotEmpty).toList() ?? [];
      final tabs = <dynamic>[];
      for (var title in sheetTitles) {
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
            if (decoded['id'] == null || (decoded['id'] is String && (decoded['id'] as String).trim().isEmpty)) {
              decoded['id'] = title;
            }
            if (decoded['label'] == null || (decoded['label'] is String && (decoded['label'] as String).trim().isEmpty)) {
              decoded['label'] = title;
            }
            tabs.add(decoded);
            continue;
          }
          tabs.add(<String, dynamic>{'id': title, 'label': title});
        } catch (e) {
          debugPrint('Error reading tab sheet $title in $tabsId: $e');
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
      await sheetsApi.spreadsheets.values.clear(sheets.ClearValuesRequest(), fileId, "'$sheetTitle'!A:B");
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
    }
  }

  Future<Map<String, String>> _readMapFromSheet(String fileId, String sheetTitle) async {
    try {
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

  Future<void> writeSettingsById(String settingsId, Map<String, dynamic> settings) async {
    try {
      await _writeMapToSheet(settingsId, 'settings', settings);
    } catch (e) {
      debugPrint('Error writing settings to $settingsId: $e');
      rethrow;
    }
  }

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

  Future<void> writeTabsById(String tabsId, List<dynamic> tabs) async {
    try {
      final ss = await retryOp(() => sheetsApi.spreadsheets.get(tabsId));
      final existingTitles = ss.sheets?.map((s) => s.properties?.title ?? '').where((t) => t.isNotEmpty).toSet() ?? <String>{};

      for (var t in tabs) {
        final tid = (t is Map && t['id'] != null) ? t['id'].toString() : DateTime.now().microsecondsSinceEpoch.toString();

        if (!existingTitles.contains(tid)) {
          try {
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

  Future<void> updateTabField(String tabsId, String tabId, String key, dynamic value) async {
    return updateTabFields(tabsId, tabId, {key: value});
  }

  Future<void> updateTabFields(String tabsId, String tabId, Map<String, dynamic> fields) async {
    if (fields.isEmpty) return;
    try {
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
    } catch (e) {
      debugPrint('Error updating tab fields in $tabId: $e');
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

  Future<void> ensureSpreadsheetsExist(String moduleFolderId, Map<String, dynamic> blueprint) async {
    final modules = blueprint['modules'] as Map<String, dynamic>? ?? {};
    await ensureSheetExists(moduleFolderId, '_settings');
    await ensureSheetExists(moduleFolderId, '_dashboard');
    for (var moduleName in modules.keys) {
      await ensureSheetExists(moduleFolderId, moduleName);
      final spreadsheetId = await getFileId(moduleFolderId, moduleName);
      if (spreadsheetId != null) {
        final moduleData = modules[moduleName] as Map<String, dynamic>;
        final fields = moduleData['fields'] as List? ?? [];
        final headers = [
          'uuid', 
          ...fields.map((f) => f['label'] as String),
          'createdAt',
          'updatedAt'
        ];
        final currentValues = await retryOp(() => sheetsApi.spreadsheets.values.get(spreadsheetId, 'A1:Z1'));
        if (currentValues.values == null || currentValues.values!.isEmpty) {
          await retryOp(() => sheetsApi.spreadsheets.values.update(
            sheets.ValueRange(values: [headers]),
            spreadsheetId,
            'A1',
            valueInputOption: 'RAW',
          ));
          await freezeHeaderRow(spreadsheetId);
        }
      }
    }
  }

  Future<void> freezeHeaderRow(String spreadsheetId) async {
    try {
      final spreadsheet = await retryOp(() => sheetsApi.spreadsheets.get(spreadsheetId));
      if (spreadsheet.sheets == null || spreadsheet.sheets!.isEmpty) return;
      final sheetId = spreadsheet.sheets![0].properties?.sheetId;
      if (sheetId == null) return;

      final request = sheets.BatchUpdateSpreadsheetRequest(
        requests: [
          sheets.Request(
            updateSheetProperties: sheets.UpdateSheetPropertiesRequest(
              properties: sheets.SheetProperties(
                sheetId: sheetId,
                gridProperties: sheets.GridProperties(frozenRowCount: 1),
              ),
              fields: 'gridProperties.frozenRowCount',
            ),
          ),
        ],
      );
      await retryOp(() => sheetsApi.spreadsheets.batchUpdate(request, spreadsheetId));
    } catch (e) {
      debugPrint('Error freezing header row: $e');
    }
  }

  Future<String?> ensureSheetExists(String folderId, String name) async {
    var id = await getFileId(folderId, name);
    if (id == null) {
      final newFile = await retryOp(() => driveApi.files.create(
        drive.File(
          name: name,
          mimeType: 'application/vnd.google-apps.spreadsheet',
          parents: [folderId],
        ),
      ));
      id = newFile.id;
    }
    return id;
  }
}
