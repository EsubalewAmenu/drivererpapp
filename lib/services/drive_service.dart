import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'drive/drive_folder_mixin.dart';
import 'drive/drive_file_mixin.dart';
import 'drive/drive_sheet_mixin.dart';
import 'drive/drive_company_mixin.dart';

class DriveService with DriveFolderMixin, DriveFileMixin, DriveSheetMixin, DriveCompanyMixin {
  @override
  final http.Client authClient;
  @override
  late drive.DriveApi driveApi;
  @override
  late sheets.SheetsApi sheetsApi;

  @visibleForTesting
  final Future<void> Function(Duration) delay;

  DriveService(this.authClient, {
    drive.DriveApi? driveApi, 
    sheets.SheetsApi? sheetsApi,
    this.delay = Future.delayed,
  }) {
    this.driveApi = driveApi ?? drive.DriveApi(authClient);
    this.sheetsApi = sheetsApi ?? sheets.SheetsApi(authClient);
  }

  @override
  Future<T> retryOp<T>(Future<T> Function() action, {int retries = 3}) async {
    for (int i = 0; i < retries; i++) {
      try {
        return await action();
      } catch (e) {
        // Fast fail if offline (SocketException or ClientException with SocketException)
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('socketexception') || 
            errorString.contains('failed host lookup') ||
            errorString.contains('network is unreachable')) {
          debugPrint('Offline detected, skipping retries for operation.');
          rethrow;
        }

        if (i == retries - 1) rethrow;
        
        final delayDuration = Duration(seconds: 1 * (i + 1));
        debugPrint('Retrying operation in ${delayDuration.inSeconds}s due to error: $e');
        await delay(delayDuration);
      }
    }
    throw Exception('Unreachable');
  }
}