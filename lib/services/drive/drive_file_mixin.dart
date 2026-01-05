import 'dart:convert';
import 'package:googleapis/drive/v3.dart' as drive;

mixin DriveFileMixin {
  drive.DriveApi get driveApi;
  Future<T> retryOp<T>(Future<T> Function() action, {int retries = 3});

  /// Checks if a file exists in a folder and returns its ID.
  Future<String?> getFileId(String folderId, String fileName) async {
    return retryOp(() async {
      try {
        final fileList = await driveApi.files.list(
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
    });
  }

  /// Reads the content of a file as a String.
  Future<String> getFileContent(String fileId) async {
    try {
      final media = await driveApi.files.get(
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

      final createdFile = await driveApi.files.create(
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

      await driveApi.files.update(
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
}
