import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import '../models/schema_models.dart';
import '../providers/workspace_provider.dart';
import 'auth_service.dart';
import 'drive_service.dart';

class ModuleImportResult {
  final String moduleId;
  final String moduleName;

  ModuleImportResult({required this.moduleId, required this.moduleName});
}

class ModuleImportService {
  final DriveService driveService;
  final WorkspaceProvider workspaceProvider;
  final AuthService authService;

  ModuleImportService({
    required this.driveService,
    required this.workspaceProvider,
    required this.authService,
  });

  Future<ModuleImportResult> importSpreadsheetAsModule(
    String spreadsheetId, {
    String? spreadsheetName,
    void Function(String message, double progress)? onProgress,
  }) async {
    onProgress?.call('Validating workspace...', 0.05);
    final workspace = workspaceProvider.currentWorkspace;
    if (workspace == null || workspace.id == null) {
      throw Exception('Workspace is not selected');
    }

    final userAccessFileId = workspaceProvider.lastUserAccessSpreadsheetId ??
        await WorkspaceProvider.getLastUserAccessSpreadsheetId();
    if (userAccessFileId == null || userAccessFileId.isEmpty) {
      throw Exception('User access spreadsheet not found');
    }

    final userEmail = authService.currentUser?.email;
    if (userEmail == null || userEmail.isEmpty) {
      throw Exception('User email not found');
    }

    onProgress?.call('Reading spreadsheet metadata...', 0.15);
    final fileName = spreadsheetName?.trim().isNotEmpty == true
        ? spreadsheetName!.trim()
        : ((await driveService.driveApi.files.get(
              spreadsheetId,
              $fields: 'id,name',
              supportsAllDrives: true,
            ) as drive.File)
                .name ??
            'Imported Module');

    final moduleName = fileName.trim();

    onProgress?.call('Creating module folder...', 0.35);
    final moduleFolder = await driveService.createWorkspace(workspace.id!, moduleName);
    final moduleFolderId = moduleFolder.id!;

    onProgress?.call('Creating config folder...', 0.55);
    final configFolderId = await driveService.getOrCreateSubFolder(moduleFolderId, 'config');

    onProgress?.call('Preparing tab config...', 0.65);
    final sheetInfo = await driveService.sheetsApi.spreadsheets.get(spreadsheetId);
    final sheetTitle = sheetInfo.sheets?.first.properties?.title ?? 'Sheet1';

    final headers = await _readHeaderRow(spreadsheetId, sheetTitle);
    final columns = _buildColumns(headers);

    final tabConfig = TabConfig(
      id: sheetTitle,
      label: sheetTitle,
      columns: columns,
      fileId: spreadsheetId,
    );

    final settings = <String, dynamic>{
      'name': SettingItem(label: 'Name', type: 'text', value: moduleName).toJson(),
      'icon': SettingItem(label: 'Icon', type: 'text', value: 'table_chart').toJson(),
      'primaryColor': SettingItem(label: 'Primary Color', type: 'text', value: '#4F46E5').toJson(),
      'version': SettingItem(label: 'Version', type: 'text', value: '1.0').toJson(),
    };

    final config = {
      'settings': settings,
      'dashboard': {'cards': []},
      'tabs': [tabConfig.toJson()],
    };
    onProgress?.call('Creating config spreadsheets...', 0.8);
    final configIds = await driveService.createModuleConfig(configFolderId, userEmail, config);

    onProgress?.call('Registering module access...', 0.92);
    await driveService.upsertUserAccessModule(
      userAccessFileId,
      moduleFolderId,
      moduleName,
      configIds['dashboard'] ?? '',
      configIds['settings'] ?? '',
      configIds['tabs'] ?? '',
    );
    onProgress?.call('Done', 1.0);

    return ModuleImportResult(moduleId: moduleFolderId, moduleName: moduleName);
  }

  Future<List<String>> _readHeaderRow(String spreadsheetId, String sheetTitle) async {
    try {
      final resp = await driveService.sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        "'$sheetTitle'!1:1",
      );
      final row = resp.values?.isNotEmpty == true ? resp.values!.first : const <dynamic>[];
      return row.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    } catch (e) {
      debugPrint('ModuleImportService: Failed to read header row: $e');
      return [];
    }
  }

  List<ColumnConfig> _buildColumns(List<String> headers) {
    if (headers.isEmpty) {
      return [ColumnConfig(key: 'col_1', label: 'Column 1', type: 'text')];
    }
    return headers.map((h) => ColumnConfig(key: h, label: h, type: 'text')).toList();
  }

}
