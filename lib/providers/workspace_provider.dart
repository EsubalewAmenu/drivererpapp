import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';

class WorkspaceProvider extends ChangeNotifier {
  drive.File? _currentWorkspace;

  drive.File? get currentWorkspace => _currentWorkspace;

  bool get hasWorkspace => _currentWorkspace != null;

  void setWorkspace(drive.File workspace) {
    _currentWorkspace = workspace;
    _saveWorkspaceId(workspace.id);
    notifyListeners();
  }

  void clearWorkspace() {
    _currentWorkspace = null;
    _clearWorkspaceId();
    notifyListeners();
  }

  Future<void> _saveWorkspaceId(String? id) async {
    if (id == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_workspace_id', id);
  }

  Future<void> _clearWorkspaceId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_workspace_id');
  }

  static Future<String?> getLastWorkspaceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_workspace_id');
  }
}
