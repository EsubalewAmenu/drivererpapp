import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'mixin.dart';

mixin DriveSheetGviz on DriveSheetMixin {
  /// Executes a raw Google Visualization API Query (tq).
  /// Returns the first cell of the first row if scalar, or list of rows.
  Future<dynamic> executeGvizQuery(
    String moduleFolderId, 
    String sheetName, 
    String query,
  ) async {
    try {
      final spreadsheetId = await getFileId(moduleFolderId, sheetName);
      if (spreadsheetId == null) {
        debugPrint('Spreadsheet $sheetName not found in $moduleFolderId');
        return null;
      }
      
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
      if (response.statusCode != 200) {
        debugPrint('Gviz query failed: ${response.statusCode} for $url');
        return null;
      }

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

  // Cache for column types to avoid redundant metadata fetches
  static final Map<String, List<String>> _columnTypesCache = {};

  Future<List<String>> getSheetColumnTypes(String spreadsheetId, int? gid) async {
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
}
