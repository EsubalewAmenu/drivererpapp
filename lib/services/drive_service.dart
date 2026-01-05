import 'package:http/http.dart' as http;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'drive/drive_folder_mixin.dart';
import 'drive/drive_file_mixin.dart';
import 'drive/drive_sheet_mixin.dart';

class DriveService with DriveFolderMixin, DriveFileMixin, DriveSheetMixin {
  final http.Client authClient;
  @override
  late final drive.DriveApi driveApi;
  @override
  late final sheets.SheetsApi sheetsApi;

  DriveService(this.authClient) {
    driveApi = drive.DriveApi(authClient);
    sheetsApi = sheets.SheetsApi(authClient);
  }

  @override
  Future<T> retryOp<T>(Future<T> Function() action, {int retries = 3}) async {
    for (int i = 0; i < retries; i++) {
      try {
        return await action();
      } catch (e) {
        if (i == retries - 1) rethrow;
        await Future.delayed(Duration(seconds: 1 * (i + 1)));
        print('Retrying operation due to error: $e');
      }
    }
    throw Exception('Unreachable');
  }
}