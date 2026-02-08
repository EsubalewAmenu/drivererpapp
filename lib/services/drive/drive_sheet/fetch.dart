import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'mixin.dart';
import 'gviz.dart'; // Needed for getSheetColumnTypes

mixin DriveSheetFetch on DriveSheetMixin, DriveSheetGviz {
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
      String? spreadsheetId = await getFileId(moduleFolderId, spreadsheetName);
      if (spreadsheetId == null && spreadsheetName != sheetTitle) {
        spreadsheetId = await getFileId(moduleFolderId, sheetTitle);
      }
      if (spreadsheetId == null) return [];
      
      return fetchRecordsBySpreadsheetId(
        spreadsheetId,
        sheetTitle,
        offset: offset,
        limit: limit,
        fetchSubTables: fetchSubTables,
        descending: descending,
        searchQuery: searchQuery,
        quickFilter: quickFilter,
      );
    } catch (e) {
      debugPrint('Error fetching records: $e');
      rethrow;
    }
  }

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
      final spreadsheet = await retryOp(() => sheetsApi.spreadsheets.get(spreadsheetId));
      final allSheetTitles = spreadsheet.sheets?.map((s) => s.properties?.title ?? '').toList() ?? [];
      
      final targetSheet = spreadsheet.sheets?.firstWhere(
        (s) => s.properties?.title == sheetTitle,
        orElse: () => throw Exception('Sheet with title "$sheetTitle" not found in spreadsheet $spreadsheetId'),
      );
      final int? gid = targetSheet?.properties?.sheetId;

      List<String> subTableSheets = [];
      if (fetchSubTables) {
        subTableSheets = allSheetTitles.where((t) => t.startsWith('$sheetTitle.')).toList();
      }

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
          debugPrint('Server-side search/filter/sort failed fall back to local: $e');
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

      if (fetchSubTables && finalRecords.isNotEmpty) {
        for (var sub in subTableSheets) {
          try {
            final subTables = <String, List<Map<String, dynamic>>>{};
            final subRecords = await _fetchSheetData(spreadsheetId, sub);
            final parts = sub.split('.');
            final fieldName = parts.length > 1 ? parts.sublist(1).join('.') : 'sub';

            for (var s in subRecords) {
              final parentId = s['parent_record_id']?.toString() ?? s['parent_record']?.toString() ?? s['parent_id']?.toString();
              if (parentId != null) {
                subTables[parentId] = subTables[parentId] ?? [];
                subTables[parentId]!.add(s);
              }
            }

            for (var main in finalRecords) {
              final recordId = main['record_id']?.toString() ?? main['id']?.toString();
              if (recordId != null) {
                main[fieldName] = subTables[recordId] ?? [];
              }
            }
          } catch (e) {
            debugPrint('Error fetching sub-table $sub: $e');
          }
        }
      }
      return finalRecords;
    } catch (e) {
      debugPrint('Error fetching records by spreadsheetId $spreadsheetId: $e');
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
      final headerResponse = await retryOp(() => sheetsApi.spreadsheets.values.get(spreadsheetId, "'$sheetTitle'!A1:ZZ1"));
      final headerValues = headerResponse.values;
      if (headerValues == null || headerValues.isEmpty) return [];
      
      final headers = headerValues.first.map((e) => e.toString().trim()).toList();

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
        if (!isEmptyRow) records.add(record);
      }
      return records;
    } catch (e) {
      debugPrint('Error reading sheet $sheetTitle: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchSheetDataSearch(
    String spreadsheetId, 
    String sheetTitle, {
    int? gid,
    String? query,
    Map<String, dynamic>? filter,
    int offset = 0,
    int limit = 20,
    bool descending = false,
  }) async {
    try {
      final headerResponse = await retryOp(() => sheetsApi.spreadsheets.values.get(spreadsheetId, "'$sheetTitle'!A1:ZZ1"));
      final rawHeaders = headerResponse.values?.first.map((e) => e.toString().trim()).toList() ?? [];
      if (rawHeaders.isEmpty) return [];

      String tq = "SELECT *";
      final whereClauses = <String>[];
      
      if (query != null && query.isNotEmpty) {
        final searchParts = <String>[];
        final searchLimit = rawHeaders.length > 50 ? 50 : rawHeaders.length;
        final actualTypes = await getSheetColumnTypes(spreadsheetId, gid);
        
        final strictlyNonText = [
          'qty', 'quantity', 'price', 'amount', 'total', 'cost', 
          'tax', 'discount', 'date', 'time', 'lat', 'long', 'zip', 'postcode', 
          'balance', 'ledger', 'credit', 'debit', 'value', 'count', 'score', 'percent',
          'is_', 'has_', 'can_', 'are_', 'was_', 'phone', 'mobile', 'tel'
        ];

        for (var i = 0; i < searchLimit; i++) {
          final col = indexToColumn(i);
          final header = rawHeaders[i].toLowerCase();
          bool isText = true;
          if (actualTypes.length > i) {
            isText = actualTypes[i] == 'string';
          } else {
            isText = !strictlyNonText.any((k) => header.contains(k));
          }
          if (!isText) {
            final numQuery = double.tryParse(query);
            if (numQuery != null) searchParts.add("$col = $numQuery");
          } else {
            searchParts.add("lower($col) contains '${query.toLowerCase().replaceAll("'", "''")}'");
          }
        }
        if (searchParts.isNotEmpty) whereClauses.add("(${searchParts.join(' OR ')})");
      }

      if (filter != null) {
        final field = filter['field'] as String;
        final op = filter['operator'] as String;
        final val = filter['value'];
        final fieldIndex = rawHeaders.indexOf(field);
        if (fieldIndex != -1) {
          final col = indexToColumn(fieldIndex);
          String? clause;
          final actualTypes = await getSheetColumnTypes(spreadsheetId, gid);
          bool isNumericCol = false;
          if (actualTypes.length > fieldIndex) {
            final typeStr = actualTypes[fieldIndex].toLowerCase();
            isNumericCol = typeStr == 'number' || typeStr == 'boolean';
          }
          String gvizVal = val.toString();
          bool isNumericVal = num.tryParse(gvizVal) != null;
          bool isBoolVal = gvizVal.toLowerCase() == 'true' || gvizVal.toLowerCase() == 'false';
          String escapedVal = gvizVal.replaceAll("'", "''");
          bool useNoQuotes = isNumericCol || (actualTypes.isEmpty && (isNumericVal || isBoolVal));

          if (op == '==' || op == '=') {
            clause = useNoQuotes ? "$col = $gvizVal" : "$col = '$escapedVal'";
          } else if (op == '!=') {
            clause = useNoQuotes ? "$col != $gvizVal" : "$col != '$escapedVal'";
          } else if (op == 'contains') {
            clause = "lower($col) contains '${escapedVal.toLowerCase()}'";
          } else if (op == '>' || op == '>=' || op == '<' || op == '<=') {
            clause = useNoQuotes ? "$col $op $gvizVal" : "$col $op '$escapedVal'";
          } else if (op == 'startsWith') {
            clause = "lower($col) starts with '${escapedVal.toLowerCase()}'";
          }
          if (clause != null) whereClauses.add(clause);
        }
      }

      if (whereClauses.isNotEmpty) tq += " WHERE ${whereClauses.join(' AND ')}";
      final ridIdx = rawHeaders.indexWhere((h) => h.toLowerCase() == 'record_id');
      if (ridIdx != -1) tq += " ORDER BY ${indexToColumn(ridIdx)} ${descending ? 'DESC' : 'ASC'}";
      tq += " LIMIT $limit OFFSET $offset";

      final url = 'https://docs.google.com/spreadsheets/d/$spreadsheetId/gviz/tq?tqx=out:json&tq=${Uri.encodeComponent(tq)}${gid != null ? '&gid=$gid' : ''}&headers=1';
      final response = await authClient.get(Uri.parse(url));
      if (response.statusCode != 200) return [];

      final body = response.body;
      final start = body.indexOf('{');
      final end = body.lastIndexOf('}');
      if (start == -1 || end == -1) return [];

      final jsonStr = body.substring(start, end + 1);
      final decoded = jsonDecode(jsonStr);
      if (decoded['status'] == 'error') throw Exception('Gviz Query Failed');

      final table = decoded['table'];
      if (table == null || table['rows'] == null) return [];

      final List<dynamic> gvizCols = table['cols'] ?? [];
      final List<String> effectiveHeaders = [];
      for (int i = 0; i < gvizCols.length; i++) {
        String label = (gvizCols[i]['label']?.toString() ?? '').trim();
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
            final val = cell['v'] ?? cell['f'];
            record[effectiveHeaders[i]] = val;
            if (val != null && val.toString().trim().isNotEmpty) isEmptyRow = false;
          } else {
            record[effectiveHeaders[i]] = null;
          }
        }
        if (!isEmptyRow) results.add(record);
      }
      return results;
    } catch (e) {
      debugPrint('Error in server-side search: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> fetchRecordByUuid(String moduleFolderId, String moduleName, String uuid) async {
    final records = await fetchRecords(moduleFolderId, moduleName, moduleName, fetchSubTables: false);
    try {
      return records.firstWhere((r) => r['uuid'] == uuid || r['record_id'] == uuid);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> searchRecords(
    String moduleFolderId, 
    String moduleName, 
    String query,
    { String? columnName }
  ) async {
    return fetchRecords(moduleFolderId, moduleName, moduleName, searchQuery: query);
  }
}
