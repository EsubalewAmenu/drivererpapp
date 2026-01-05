import 'dart:convert';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;

class DriveService {
  final http.Client authClient;
  late final drive.DriveApi _driveApi;
  late final sheets.SheetsApi _sheetsApi;

  // The name of the root folder for our app
  static const String _rootFolderName = 'DriveERP_Data';

  DriveService(this.authClient) {
    _driveApi = drive.DriveApi(authClient);
    _sheetsApi = sheets.SheetsApi(authClient);
  }

  /// Checks if the root folder exists. Returns the folder ID if it does, or null.
  Future<String?> checkRootFolder() async {
    try {
      final fileList = await _driveApi.files.list(
        q: "mimeType = 'application/vnd.google-apps.folder' and name = '$_rootFolderName' and trashed = false",
        $fields: 'files(id, name)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.id;
      }
      return null;
    } catch (e) {
      print('Error checking root folder: $e');
      rethrow;
    }
  }

  /// Creates the root folder and returns its ID.
  Future<String> createRootFolder() async {
    try {
      final folder = drive.File()
        ..name = _rootFolderName
        ..mimeType = 'application/vnd.google-apps.folder';

      final createdFolder = await _driveApi.files.create(folder);
      return createdFolder.id!;
    } catch (e) {
      print('Error creating root folder: $e');
      rethrow;
    }
  }

  /// Lists subfolders (workspaces) inside the root folder.
  Future<List<drive.File>> listWorkspaces(String rootFolderId) async {
    try {
      final fileList = await _driveApi.files.list(
        q: "'$rootFolderId' in parents and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
        $fields: 'files(id, name)',
      );
      return fileList.files ?? [];
    } catch (e) {
      print('Error listing workspaces: $e');
      rethrow;
    }
  }
  
  /// Creates a new workspace folder inside the root folder.
  Future<drive.File> createWorkspace(String rootFolderId, String workspaceName) async {
    try {
      final folder = drive.File()
        ..name = workspaceName
        ..parents = [rootFolderId]
        ..mimeType = 'application/vnd.google-apps.folder';

      return await _driveApi.files.create(folder);
    } catch (e) {
      print('Error creating workspace: $e');
      rethrow;
    }
  }

  /// Lists subfolders (modules) inside a workspace folder.
  Future<List<drive.File>> listModules(String workspaceId) async {
    try {
      final fileList = await _driveApi.files.list(
        q: "'$workspaceId' in parents and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
        $fields: 'files(id, name)',
      );
      return fileList.files ?? [];
    } catch (e) {
      print('Error listing modules: $e');
      rethrow;
    }
  }

  /// Checks if a file exists in a folder and returns its ID.
  Future<String?> getFileId(String folderId, String fileName) async {
    try {
      final fileList = await _driveApi.files.list(
        q: "'$folderId' in parents and name = '$fileName' and trashed = false",
        $fields: 'files(id, name)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.id;
      }
      return null;
    } catch (e) {
      print('Error checking file: $e');
      rethrow;
    }
  }

  /// Reads the content of a file as a String.
  Future<String> getFileContent(String fileId) async {
    try {
      final media = await _driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final stream = media.stream;
      final content = await stream.transform(utf8.decoder).join();
      return content;
    } catch (e) {
      print('Error reading file content: $e');
      rethrow;
    }
  }

  /// Creates a file in a folder with the given content.
  Future<String> createFile(String folderId, String fileName, String content) async {
    try {
      final file = drive.File()
        ..name = fileName
        ..parents = [folderId]
        ..mimeType = 'application/json';

      final bytes = utf8.encode(content);
      final media = drive.Media(
        Stream.value(bytes),
        bytes.length,
      );

      final createdFile = await _driveApi.files.create(
        file,
        uploadMedia: media,
      );
      print('Created file: ${createdFile.name} (${createdFile.id})');
      return createdFile.id!;
    } catch (e) {
      print('Error creating file: $e');
      rethrow;
    }
  }

  /// Updates the content of an existing file.
  Future<void> updateFile(String fileId, String content) async {
    try {
      final file = drive.File(); // Metadata updates if needed
      
      final bytes = utf8.encode(content);
      final media = drive.Media(
        Stream.value(bytes),
        bytes.length,
      );

      await _driveApi.files.update(
        file,
        fileId,
        uploadMedia: media,
      );
      print('Updated file: $fileId');
    } catch (e) {
      print('Error updating file: $e');
      rethrow;
    }
  }

  /// Creates a Google Sheet for configuration and stores the JSON content in cell A1.
  Future<String> createConfigSheet(String folderId, String fileName, String content) async {
    try {
      // 1. Create Spreadsheet
      final spreadsheet = sheets.Spreadsheet(
        properties: sheets.SpreadsheetProperties(title: fileName),
      );
      
      final created = await _sheetsApi.spreadsheets.create(spreadsheet);
      final fileId = created.spreadsheetId!;
      print('Created spreadsheet: $fileName ($fileId)');

      // 2. Move to folder (Sheets API creates in root by default)
      // Get current parents to remove them
      final file = await _driveApi.files.get(fileId, $fields: 'parents') as drive.File;
      final previousParents = file.parents?.join(',') ?? '';
      
      await _driveApi.files.update(
        drive.File(), 
        fileId, 
        addParents: folderId, 
        removeParents: previousParents,
        $fields: 'id, parents',
      );
      print('Moved spreadsheet to folder: $folderId');

      // 3. Write content to A1
      await updateConfigSheet(fileId, content);
      
      return fileId;
    } catch (e) {
      print('Error creating config sheet: $e');
      rethrow;
    }
  }

  /// Reads the JSON content from cell A1 of the config sheet.
  Future<String> readConfigSheet(String fileId) async {
    try {
      final response = await _sheetsApi.spreadsheets.values.get(fileId, 'Sheet1!A1');
      if (response.values != null && response.values!.isNotEmpty && response.values![0].isNotEmpty) {
        return response.values![0][0] as String;
      }
      return '{}';
    } catch (e) {
      print('Error reading config sheet: $e');
      rethrow;
    }
  }

  /// Updates the JSON content in cell A1 of the config sheet.
  Future<void> updateConfigSheet(String fileId, String content) async {
    try {
      final valueRange = sheets.ValueRange(
        values: [[content]], // Row 1, Col 1
      );
      await _sheetsApi.spreadsheets.values.update(
        valueRange, 
        fileId, 
        'Sheet1!A1', 
        valueInputOption: 'RAW'
      );
      print('Updated config sheet: $fileId');
    } catch (e) {
      print('Error updating config sheet: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> readSheet(String workspace, String sheetName) async {
    // TODO: Implement real sheet reading
    return [];
  }

  Future<void> writeSheet(String workspace, String sheetName, List<Map<String, dynamic>> data) async {
    // TODO: Implement real sheet writing
  }
}
