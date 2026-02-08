import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'mixin.dart';

mixin DriveSheetCrud on DriveSheetMixin {
  Future<void> saveRecordBySpreadsheetId(String spreadsheetId, String sheetTitle, Map<String, dynamic> data) async {
    try {
      final prepared = _prepareRecordForDrive(data);
      final recordId = prepared['recordId'] as String;
      final mainRecord = prepared['mainRecord'] as Map<String, dynamic>;
      final nestedTables = prepared['nestedTables'] as Map<String, List<dynamic>>;

      await _saveToSheet(spreadsheetId, sheetTitle, mainRecord);

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

  Future<void> saveRecordsBatchBySpreadsheetId(String spreadsheetId, String sheetTitle, List<Map<String, dynamic>> records) async {
    if (records.isEmpty) return;
    try {
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
      }

      final headerResponse = await retryOp(() => sheetsApi.spreadsheets.values.get(spreadsheetId, "'$sheetTitle'!A1:ZZ1"));
      List<String> headers = [];
      if (headerResponse.values != null && headerResponse.values!.isNotEmpty) {
        headers = headerResponse.values!.first.map((e) => e.toString().trim()).toList();
      }

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

      final unionHeaders = Set<String>.from(headers);
      for (var r in mainRecords) {
        for (var k in r.keys) unionHeaders.add(k.toString());
      }
      unionHeaders.add('record_id');
      unionHeaders.add('created_at');
      final finalHeaders = unionHeaders.toList();

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

      final rows = <List<String>>[];
      for (var r in mainRecords) {
        final row = headers.map((h) => r[h]?.toString() ?? '').toList();
        rows.add(row);
      }

      if (rows.isNotEmpty) {
        await retryOp(() => sheetsApi.spreadsheets.values.append(
          sheets.ValueRange(values: rows),
          spreadsheetId,
          '$sheetTitle!A1',
          valueInputOption: 'RAW',
          insertDataOption: 'INSERT_ROWS',
        ));
      }

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
          if (!existing.contains('sub_record_id')) existing.add('sub_record_id');
          if (!existing.contains('parent_record_id')) existing.add('parent_record_id');
          for (var e in entries) {
            for (var key in e.keys) if (!existing.contains(key)) existing.add(key.toString());
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

      for (var subSheet in subHeadersMap.keys) {
        final subHeaders = subHeadersMap[subSheet]!;
        final subRows = subRowsMap[subSheet] ?? [];
        if (subRows.isEmpty) continue;
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
      }
    } catch (e) {
      debugPrint('Error in saveRecordsBatchBySpreadsheetId: $e');
      rethrow;
    }
  }

  Future<void> deleteRecordBySpreadsheetId(String spreadsheetId, String sheetTitle, String recordId) async {
    try {
      final headerResponse = await retryOp(() => sheetsApi.spreadsheets.values.get(spreadsheetId, '$sheetTitle!1:1'));
      if (headerResponse.values == null || headerResponse.values!.isEmpty) return;
      
      final headers = headerResponse.values!.first.map((e) => e.toString()).toList();
      final idColIndex = headers.indexOf('record_id');
      if (idColIndex == -1) return;

      final colLetter = indexToColumn(idColIndex);
      final idColResponse = await retryOp(() => sheetsApi.spreadsheets.values.get(spreadsheetId, '$sheetTitle!$colLetter:$colLetter'));
      final idValues = idColResponse.values;
      
      int? rowIndex;
      if (idValues != null) {
        for (int i = 0; i < idValues.length; i++) {
          if (idValues[i].isNotEmpty && idValues[i].first.toString() == recordId) {
            rowIndex = i;
            break;
          }
        }
      }
      if (rowIndex == null) return;

      final spreadsheet = await retryOp(() => sheetsApi.spreadsheets.get(spreadsheetId));
      final sheet = spreadsheet.sheets?.firstWhere((s) => s.properties?.title == sheetTitle, orElse: () => spreadsheet.sheets!.first);
      final int? gid = sheet?.properties?.sheetId;
      if (gid == null) return;

      await retryOp(() => sheetsApi.spreadsheets.batchUpdate(
        sheets.BatchUpdateSpreadsheetRequest(
          requests: [
            sheets.Request(
              deleteDimension: sheets.DeleteDimensionRequest(
                range: sheets.DimensionRange(
                  sheetId: gid,
                  dimension: 'ROWS',
                  startIndex: rowIndex,
                  endIndex: rowIndex! + 1,
                ),
              ),
            ),
          ],
        ),
        spreadsheetId,
      ));

      final subTableSheets = spreadsheet.sheets?.where((s) => s.properties?.title?.startsWith('$sheetTitle.') ?? false).toList() ?? [];
      for (var subSheet in subTableSheets) {
        final title = subSheet.properties!.title!;
        final subGid = subSheet.properties!.sheetId!;
        final subHeadersRes = await retryOp(() => sheetsApi.spreadsheets.values.get(spreadsheetId, '$title!1:1'));
        if (subHeadersRes.values == null || subHeadersRes.values!.isEmpty) continue;
        final subHeaders = subHeadersRes.values!.first.map((e) => e.toString()).toList();
        final pIdIndex = subHeaders.indexOf('parent_record_id');
        if (pIdIndex == -1) continue;
        final pColLetter = indexToColumn(pIdIndex);
        final pColData = await retryOp(() => sheetsApi.spreadsheets.values.get(spreadsheetId, '$title!$pColLetter:$pColLetter'));
        final pValues = pColData.values;
        if (pValues != null) {
          List<int> toDelete = [];
          for (int i = 1; i < pValues.length; i++) {
            if (pValues[i].isNotEmpty && pValues[i].first.toString() == recordId) toDelete.add(i);
          }
          if (toDelete.isNotEmpty) {
            toDelete.sort((a, b) => b.compareTo(a));
            final requests = toDelete.map((idx) => sheets.Request(
              deleteDimension: sheets.DeleteDimensionRequest(
                range: sheets.DimensionRange(sheetId: subGid, dimension: 'ROWS', startIndex: idx, endIndex: idx + 1),
              ),
            )).toList();
            await retryOp(() => sheetsApi.spreadsheets.batchUpdate(sheets.BatchUpdateSpreadsheetRequest(requests: requests), spreadsheetId));
          }
        }
      }
    } catch (e) {
      debugPrint('Error deleting record by spreadsheetId $spreadsheetId: $e');
      rethrow;
    }
  }

  Future<void> _saveToSheet(String spreadsheetId, String sheetTitle, Map<String, dynamic> data) async {
    final spreadsheet = await retryOp(() => sheetsApi.spreadsheets.get(spreadsheetId));
    bool sheetExists = spreadsheet.sheets?.any((s) => s.properties?.title == sheetTitle) ?? false;
    if (!sheetExists) {
      await retryOp(() => sheetsApi.spreadsheets.batchUpdate(
        sheets.BatchUpdateSpreadsheetRequest(
          requests: [sheets.Request(addSheet: sheets.AddSheetRequest(properties: sheets.SheetProperties(title: sheetTitle, gridProperties: sheets.GridProperties(frozenRowCount: 1))))],
        ),
        spreadsheetId,
      ));
    }
    final headerResponse = await retryOp(() => sheetsApi.spreadsheets.values.get(spreadsheetId, "'$sheetTitle'!A1:ZZ1"));
    List<String> headers = [];
    if (headerResponse.values != null && headerResponse.values!.isNotEmpty) {
      headers = headerResponse.values!.first.map((e) => e.toString().trim()).toList();
    }
    if (headers.isEmpty) {
      headers = data.keys.toList();
      await retryOp(() => sheetsApi.spreadsheets.values.append(sheets.ValueRange(values: [headers]), spreadsheetId, "'$sheetTitle'!A1", valueInputOption: 'RAW'));
    } else {
      final newKeys = data.keys.where((k) => !headers.contains(k)).toList();
      if (newKeys.isNotEmpty) {
        headers.addAll(newKeys);
        await retryOp(() => sheetsApi.spreadsheets.values.update(sheets.ValueRange(values: [headers]), spreadsheetId, "'$sheetTitle'!A1", valueInputOption: 'RAW'));
      }
    }
    final recordId = data['record_id']?.toString() ?? data['sub_record_id']?.toString();
    final idKey = data.containsKey('record_id') ? 'record_id' : (data.containsKey('sub_record_id') ? 'sub_record_id' : null);
    int? recordRowIndex;
    if (recordId != null && idKey != null) {
      final idColIndex = headers.indexOf(idKey);
      if (idColIndex != -1) {
        final colLetter = indexToColumn(idColIndex);
        final idColResponse = await retryOp(() => sheetsApi.spreadsheets.values.get(spreadsheetId, "'$sheetTitle'!$colLetter:$colLetter"));
        final idValues = idColResponse.values;
        if (idValues != null) {
          for (int i = 0; i < idValues.length; i++) {
            if (idValues[i].isNotEmpty && idValues[i].first.toString() == recordId) {
              recordRowIndex = i + 1;
              break;
            }
          }
        }
      }
    }
    final row = headers.map((h) => data[h]?.toString() ?? '').toList();
    if (recordRowIndex != null) {
      await retryOp(() => sheetsApi.spreadsheets.values.update(sheets.ValueRange(values: [row]), spreadsheetId, "'$sheetTitle'!$recordRowIndex:$recordRowIndex", valueInputOption: 'RAW'));
    } else {
      await retryOp(() => sheetsApi.spreadsheets.values.append(sheets.ValueRange(values: [row]), spreadsheetId, "'$sheetTitle'!A1", valueInputOption: 'RAW'));
    }
  }

  Map<String, dynamic> _prepareRecordForDrive(Map<String, dynamic> data) {
    final recordId = data['record_id'] ?? DateTime.now().microsecondsSinceEpoch.toString();
    final finalData = Map<String, dynamic>.from(data);
    finalData['record_id'] = recordId;
    if (finalData['created_at'] == null) finalData['created_at'] = DateTime.now().toIso8601String();
    final nestedTables = <String, List<Map<String, dynamic>>>{};
    final keysToRemove = <String>[];
    finalData.forEach((key, value) {
      if (value is List) {
        if (value.isNotEmpty && value.first is Map) {
          nestedTables[key] = value.cast<Map<String, dynamic>>();
          keysToRemove.add(key);
        } else {
          finalData[key] = jsonEncode(value);
        }
      }
    });
    for (var key in keysToRemove) finalData.remove(key);
    return {'recordId': recordId, 'mainRecord': finalData, 'nestedTables': nestedTables};
  }
}
