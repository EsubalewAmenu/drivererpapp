import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import '../models/schema_models.dart';
import '../providers/workspace_provider.dart';
import 'drive_service.dart';

class ModuleImportService {
  final DriveService driveService;
  final WorkspaceProvider workspaceProvider;

  ModuleImportService({
    required this.driveService,
    required this.workspaceProvider,
  });

  Future<String> importSpreadsheetAsModule(String spreadsheetId) async {
    final workspace = workspaceProvider.currentWorkspace;
    if (workspace == null || workspace.id == null) {
      throw Exception('Workspace is not selected');
    }

    final userAccessFileId = workspaceProvider.lastUserAccessSpreadsheetId ??
        await WorkspaceProvider.getLastUserAccessSpreadsheetId();
    if (userAccessFileId == null || userAccessFileId.isEmpty) {
      throw Exception('User access spreadsheet not found');
    }

    final file = await driveService.driveApi.files.get(
      spreadsheetId,
      $fields: 'id,name',
      supportsAllDrives: true,
    ) as drive.File;

    final moduleName = (file.name ?? 'Imported Module').trim();

    final moduleFolder = await driveService.createWorkspace(workspace.id!, moduleName);
    final moduleFolderId = moduleFolder.id!;

    // Attempt to add the spreadsheet into the module folder (non-destructive)
    try {
      await driveService.driveApi.files.update(
        drive.File(),
        spreadsheetId,
        addParents: moduleFolderId,
        supportsAllDrives: true,
      );
    } catch (e) {
      debugPrint('ModuleImportService: Failed to add spreadsheet to module folder: $e');
    }

    final configFolderId = await driveService.getOrCreateSubFolder(moduleFolderId, 'config');

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

    final configBase = _normalizeFileBase(moduleName);
    final configIds = await driveService.createModuleConfig(configFolderId, configBase, config);

    await driveService.upsertUserAccessModule(
      userAccessFileId,
      moduleFolderId,
      moduleName,
      configIds['dashboard'] ?? '',
      configIds['settings'] ?? '',
      configIds['tabs'] ?? '',
    );

    return moduleFolderId;
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

  String _normalizeFileBase(String input) {
    final normalized = input.toLowerCase().trim().replaceAll(RegExp(r'\s+'), '_');
    return normalized.replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }
}
