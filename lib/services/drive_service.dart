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

  Future<T> _retry<T>(Future<T> Function() action, {int retries = 3}) async {
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
    return _retry(() async {
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
    });
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

  /// Creates a Google Sheet for configuration with multiple sheets.
  Future<String> createModuleConfig(String folderId, String fileName, Map<String, dynamic> config) async {
    try {
      // 1. Create Spreadsheet with specific sheets
      final spreadsheet = sheets.Spreadsheet(
        properties: sheets.SpreadsheetProperties(title: fileName),
        sheets: [
          sheets.Sheet(properties: sheets.SheetProperties(title: 'settings')),
          sheets.Sheet(properties: sheets.SheetProperties(title: 'dashboard')),
          sheets.Sheet(properties: sheets.SheetProperties(title: 'tabs')),
        ],
      );
      
      final created = await _sheetsApi.spreadsheets.create(spreadsheet);
      final fileId = created.spreadsheetId!;
      print('Created spreadsheet: $fileName ($fileId)');

      // 2. Move to folder
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

      // 3. Write data
      await updateModuleConfig(fileId, config);
      
      return fileId;
    } catch (e) {
      print('Error creating module config: $e');
      rethrow;
    }
  }

  /// Updates the module configuration in the spreadsheet.
  Future<void> updateModuleConfig(String fileId, Map<String, dynamic> config) async {
     // Write settings
     if (config.containsKey('settings')) {
       await _writeMapToSheet(fileId, 'settings', config['settings']);
     }
     
     // Write dashboard
     if (config.containsKey('dashboard')) {
       await _writeMapToSheet(fileId, 'dashboard', config['dashboard']);
     }
     
     // Write tabs
     if (config.containsKey('tabs')) {
       final tabsList = config['tabs'] as List;
       // Map tabs by their ID for storage
       final tabsMap = {for (var t in tabsList) (t['id'] as String): t};
       await _writeMapToSheet(fileId, 'tabs', tabsMap);
     }
  }

  /// Reads the module configuration from the spreadsheet.
  Future<Map<String, dynamic>> readModuleConfig(String fileId) async {
    final config = <String, dynamic>{};
    
    try {
      // Read settings
      final settingsMap = await _readMapFromSheet(fileId, 'settings');
      config['settings'] = settingsMap.map((k, v) => MapEntry(k, jsonDecode(v)));
      
      // Read dashboard
      final dashboardMap = await _readMapFromSheet(fileId, 'dashboard');
      config['dashboard'] = dashboardMap.map((k, v) => MapEntry(k, jsonDecode(v)));
      
      // Read tabs
      final tabsMap = await _readMapFromSheet(fileId, 'tabs');
      config['tabs'] = tabsMap.values.map((v) => jsonDecode(v)).toList();
      
      return config;
    } catch (e) {
      print('Error reading module config: $e');
      return {};
    }
  }

  Future<void> _writeMapToSheet(String fileId, String sheetTitle, Map<String, dynamic> data) async {
    try {
      // Clear first to avoid stale data
      await _sheetsApi.spreadsheets.values.clear(sheets.ClearValuesRequest(), fileId, '$sheetTitle!A:B');
      
      final rows = data.entries.map((e) => [e.key, jsonEncode(e.value)]).toList();
      final valueRange = sheets.ValueRange(values: rows);
      
      await _sheetsApi.spreadsheets.values.update(
        valueRange,
        fileId,
        '$sheetTitle!A1',
        valueInputOption: 'RAW',
      );
    } catch (e) {
      print('Error writing to sheet $sheetTitle: $e');
      // Don't rethrow, try to continue
    }
  }

  Future<Map<String, String>> _readMapFromSheet(String fileId, String sheetTitle) async {
    try {
      final response = await _sheetsApi.spreadsheets.values.get(fileId, '$sheetTitle!A:B');
      final map = <String, String>{};
      if (response.values != null) {
        for (var row in response.values!) {
          if (row.length >= 2) {
            map[row[0] as String] = row[1] as String;
          }
        }
      }
      return map;
    } catch (e) {
      print('Error reading sheet $sheetTitle: $e');
      return {};
    }
  }

  Future<void> saveRecord(String moduleFolderId, String spreadsheetName, String sheetTitle, Map<String, dynamic> data) async {
    try {
      // 1. Find or Create Spreadsheet
      String? spreadsheetId = await getFileId(moduleFolderId, spreadsheetName);
      
      if (spreadsheetId == null) {
        // Create new spreadsheet
        final spreadsheet = sheets.Spreadsheet(
          properties: sheets.SpreadsheetProperties(title: spreadsheetName),
        );
        final created = await _retry(() => _sheetsApi.spreadsheets.create(spreadsheet));
        spreadsheetId = created.spreadsheetId!;
        
        // Move to folder
        final file = await _retry(() => _driveApi.files.get(spreadsheetId!, $fields: 'parents') as Future<drive.File>);
        final previousParents = file.parents?.join(',') ?? '';
        
        if (previousParents.isNotEmpty) {
           await _retry(() => _driveApi.files.update(
            drive.File(), 
            spreadsheetId!, 
            addParents: moduleFolderId, 
            removeParents: previousParents,
            $fields: 'id, parents',
          ));
        } else {
           await _retry(() => _driveApi.files.update(
            drive.File(), 
            spreadsheetId!, 
            addParents: moduleFolderId,
            $fields: 'id, parents',
          ));
        }
        print('Created data spreadsheet: $spreadsheetName ($spreadsheetId)');
      }

      // 2. Check/Create Sheet (Tab)
      final spreadsheet = await _retry(() => _sheetsApi.spreadsheets.get(spreadsheetId!));
      bool sheetExists = spreadsheet.sheets?.any((s) => s.properties?.title == sheetTitle) ?? false;
      
      if (!sheetExists) {
        await _retry(() => _sheetsApi.spreadsheets.batchUpdate(
          sheets.BatchUpdateSpreadsheetRequest(
            requests: [
              sheets.Request(
                addSheet: sheets.AddSheetRequest(
                  properties: sheets.SheetProperties(title: sheetTitle),
                ),
              ),
            ],
          ),
          spreadsheetId!,
        ));
        print('Created sheet: $sheetTitle');
      }

      // 3. Handle Headers and Append
      // Read the first row to check headers
      final headerResponse = await _retry(() => _sheetsApi.spreadsheets.values.get(spreadsheetId!, '$sheetTitle!1:1'));
      List<String> headers = [];
      
      if (headerResponse.values != null && headerResponse.values!.isNotEmpty) {
        headers = headerResponse.values!.first.map((e) => e.toString()).toList();
      }

      // If no headers, write them from data keys
      if (headers.isEmpty) {
        headers = data.keys.toList();
        await _retry(() => _sheetsApi.spreadsheets.values.append(
          sheets.ValueRange(values: [headers]),
          spreadsheetId!,
          '$sheetTitle!A1',
          valueInputOption: 'RAW',
        ));
      } else {
        // Check if we have new keys in data that are not in headers
        final newKeys = data.keys.where((k) => !headers.contains(k)).toList();
        if (newKeys.isNotEmpty) {
          headers.addAll(newKeys);
          final valueRange = sheets.ValueRange(values: [headers]);
          await _retry(() => _sheetsApi.spreadsheets.values.update(
            valueRange,
            spreadsheetId!,
            '$sheetTitle!1:1',
            valueInputOption: 'RAW',
          ));
        }
      }

      // 4. Prepare Row Data
      final row = headers.map((h) => data[h]?.toString() ?? '').toList();
      
      // 5. Append Row
      await _retry(() => _sheetsApi.spreadsheets.values.append(
        sheets.ValueRange(values: [row]),
        spreadsheetId!,
        '$sheetTitle!A1',
        valueInputOption: 'RAW',
      ));
      print('Appended record to $sheetTitle');
      
    } catch (e) {
      print('Error saving record: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchRecords(String moduleFolderId, String spreadsheetName, String sheetTitle) async {
    try {
      // 1. Find Spreadsheet
      String? spreadsheetId = await getFileId(moduleFolderId, spreadsheetName);
      
      if (spreadsheetId == null) {
        return [];
      }

      // 2. Read Data
      final response = await _retry(() => _sheetsApi.spreadsheets.values.get(spreadsheetId, '$sheetTitle!A:ZZ'));
      final values = response.values;

      if (values == null || values.isEmpty) {
        return [];
      }

      // 3. Parse Headers
      final headers = values.first.map((e) => e.toString()).toList();
      final records = <Map<String, dynamic>>[];

      // 4. Parse Rows
      for (var i = 1; i < values.length; i++) {
        final row = values[i];
        final record = <String, dynamic>{};
        
        for (var j = 0; j < headers.length; j++) {
          if (j < row.length) {
            record[headers[j]] = row[j];
          } else {
            record[headers[j]] = null;
          }
        }
        records.add(record);
      }

      return records;
    } catch (e) {
      print('Error fetching records: $e');
      return [];
    }
  }
}
