import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;

mixin DriveSheetMixin {
  drive.DriveApi get driveApi;
  sheets.SheetsApi get sheetsApi;
  http.Client get authClient;

  /// Retries a Google API operation if it fails (e.g., rate limits).
  Future<T> retryOp<T>(Future<T> Function() action, {int retries = 3}) async {
    int attempts = 0;
    while (attempts < retries) {
      try {
        return await action();
      } catch (e) {
        attempts++;
        if (attempts >= retries) rethrow;
        final seconds = attempts * 2;
        debugPrint('Operation failed, retrying in $seconds seconds... ($e)');
        await Future.delayed(Duration(seconds: seconds));
      }
    }
    throw Exception('Retry failed');
  }

  /// Finds a file ID given a folder ID and name.
  Future<String?> getFileId(String folderId, String fileName) async {
    final query = "name = '$fileName' and '$folderId' in parents and trashed = false";
    final list = await retryOp(() => driveApi.files.list(q: query, supportsAllDrives: true));
    if (list.files == null || list.files!.isEmpty) return null;
    return list.files!.first.id;
  }

  /// Converts a column index (0, 1, 2...) to Gviz/Sheets letters (A, B, C...).
  String indexToColumn(int index) {
    String res = '';
    int n = index + 1;
    while (n > 0) {
      int m = (n - 1) % 26;
      res = String.fromCharCode(65 + m) + res;
      n = ((n - m) ~/ 26);
    }
    return res;
  }

  /// Compatibility wrapper for the private version if needed by old parts
  String getColLetter(int colIndex) => indexToColumn(colIndex);
}
