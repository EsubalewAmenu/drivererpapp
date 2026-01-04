import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

class DriveService {
  final http.Client authClient;
  late final drive.DriveApi _driveApi;

  // The name of the root folder for our app
  static const String _rootFolderName = 'DriveERP_Data';

  DriveService(this.authClient) {
    _driveApi = drive.DriveApi(authClient);
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

  Future<List<Map<String, dynamic>>> readSheet(String workspace, String sheetName) async {
    // TODO: Implement real sheet reading
    return [];
  }

  Future<void> writeSheet(String workspace, String sheetName, List<Map<String, dynamic>> data) async {
    // TODO: Implement real sheet writing
  }
}
