import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class WorkspaceProvider extends ChangeNotifier {
  drive.File? _currentWorkspace;

  drive.File? get currentWorkspace => _currentWorkspace;

  bool get hasWorkspace => _currentWorkspace != null;

  void setWorkspace(drive.File workspace) {
    _currentWorkspace = workspace;
    notifyListeners();
  }

  void clearWorkspace() {
    _currentWorkspace = null;
    notifyListeners();
  }
}
