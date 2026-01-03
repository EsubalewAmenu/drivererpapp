import 'dart:convert';

class DriveService {
  // Simulating Drive with in-memory storage for now.
  // TODO: Replace with SharedPreferences or Google Drive API.
  final Map<String, String> _storage = {};
  static const String _manifestKey = 'drive_erp_manifest';

  Future<List<String>> getWorkspaces() async {
    final data = _storage[_manifestKey];
    if (data != null) {
      return List<String>.from(json.decode(data));
    }
    return ['Default Workspace'];
  }

  Future<void> createWorkspace(String name) async {
    final workspaces = await getWorkspaces();
    if (!workspaces.contains(name)) {
      workspaces.add(name);
      _storage[_manifestKey] = json.encode(workspaces);
    }
  }

  Future<List<Map<String, dynamic>>> readSheet(String workspace, String sheetName) async {
    final key = 'workspace_${workspace}_$sheetName';
    final data = _storage[key];
    if (data != null) {
      return List<Map<String, dynamic>>.from(json.decode(data));
    }
    return [];
  }

  Future<void> writeSheet(String workspace, String sheetName, List<Map<String, dynamic>> data) async {
    final key = 'workspace_${workspace}_$sheetName';
    _storage[key] = json.encode(data);
  }
}
