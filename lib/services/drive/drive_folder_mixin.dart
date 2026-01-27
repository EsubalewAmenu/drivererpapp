import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;

mixin DriveFolderMixin {
  drive.DriveApi get driveApi;
  
  static const String rootFolderName = 'DriveERP_Data';

  /// Checks if the root folder exists. Returns the folder ID if it does, or null.
  Future<String?> checkRootFolder() async {
    try {
      final fileList = await driveApi.files.list(
        q: "mimeType = 'application/vnd.google-apps.folder' and name = '$rootFolderName' and trashed = false",
        $fields: 'files(id, name)',
        includeItemsFromAllDrives: true,
        supportsAllDrives: true,
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.id;
      }
      return null;
    } catch (e) {
      debugPrint('Error checking root folder: $e');
      rethrow;
    }
  }

  /// Creates the root folder and returns its ID.
  Future<String> createRootFolder() async {
    try {
      final folder = drive.File()
        ..name = rootFolderName
        ..mimeType = 'application/vnd.google-apps.folder';

      final createdFolder = await driveApi.files.create(folder);
      return createdFolder.id!;
    } catch (e) {
      debugPrint('Error creating root folder: $e');
      rethrow;
    }
  }

  /// Lists subfolders (workspaces) inside the root folder.
  Future<List<drive.File>> listWorkspaces(String rootFolderId) async {
    try {
      final fileList = await driveApi.files.list(
        q: "'$rootFolderId' in parents and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
        $fields: 'files(id, name)',
        includeItemsFromAllDrives: true,
        supportsAllDrives: true,
      );
      return fileList.files ?? [];
    } catch (e) {
      debugPrint('Error listing workspaces: $e');
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

      return await driveApi.files.create(folder);
    } catch (e) {
      debugPrint('Error creating workspace: $e');
      rethrow;
    }
  }

  /// Gets or creates a subfolder inside a parent folder.
  Future<String> getOrCreateSubFolder(String parentId, String folderName) async {
    try {
      // Check if exists
      final fileList = await driveApi.files.list(
        q: "'$parentId' in parents and mimeType = 'application/vnd.google-apps.folder' and name = '$folderName' and trashed = false",
        $fields: 'files(id)',
        includeItemsFromAllDrives: true,
        supportsAllDrives: true,
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.id!;
      }

      // Create if not exists
      final folder = drive.File()
        ..name = folderName
        ..parents = [parentId]
        ..mimeType = 'application/vnd.google-apps.folder';

      final created = await driveApi.files.create(folder);
      return created.id!;
    } catch (e) {
      debugPrint('Error getting/creating subfolder $folderName: $e');
      rethrow;
    }
  }

  /// Lists subfolders (modules) inside a workspace folder.
  // Note: module listing via Drive folders has been removed. Access control
  // and module activation are now driven exclusively by the companies
  // registry `user_access` sheet. Do not add a Drive-based fallback.
}
