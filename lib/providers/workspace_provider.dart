import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/company_model.dart';
import '../services/drive_service.dart';

class WorkspaceProvider extends ChangeNotifier {
  final DriveService? _driveService;
  
  drive.File? _currentWorkspace;
  List<Company> _companies = [];
  bool _isLoading = false;

  WorkspaceProvider({DriveService? driveService}) : _driveService = driveService;

  drive.File? get currentWorkspace => _currentWorkspace;
  List<Company> get companies => _companies;
  bool get isLoading => _isLoading;
  bool get hasWorkspace => _currentWorkspace != null;

  Future<void> loadCompanies(String rootFolderId) async {
    if (_driveService == null) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      // Ensure registry exists first
      await _driveService!.ensureCompanyRegistry(rootFolderId);
      
      // Fetch list
      _companies = await _driveService!.getCompanies(rootFolderId);
    } catch (e) {
      debugPrint('Error loading companies: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> registerNewCompany(String rootFolderId, Company company) async {
    if (_driveService == null) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      await _driveService!.registerCompany(rootFolderId, company);
      _companies.add(company);
    } catch (e) {
      debugPrint('Error registering company: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> restorePreviousSession() async {
    if (_driveService == null) return false;
    
    final lastId = await getLastWorkspaceId();
    if (lastId == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      // 1. Find Root Folder (needed for registry)
      final rootId = await _driveService!.checkRootFolder();
      
      if (rootId != null) {
        // 2. Try to fetch from registry to get the CORRECT name
        try {
          // Temporarily ensure registry exists (lightweight check inside mixin)
          // We don't call ensureCompanyRegistry here to avoid write ops during read
          final companies = await _driveService!.getCompanies(rootId);
          
          try {
            final match = companies.firstWhere((c) => c.folderId == lastId);
            // Found in registry - construct file with registry metadata
            final file = drive.File()
              ..id = match.folderId
              ..name = match.name; // <--- The Fix: Use Registry Name
            
            _currentWorkspace = file;
            _companies = companies; // Cache these since we fetched them
            notifyListeners();
            return true;
          } catch (_) {
            // Not found in registry
          }
        } catch (e) {
          debugPrint('Registry lookup failed during restore: $e');
        }
      }

      // 3. Fallback: Drive API lookup (Folder Name)
      // If registry failed or company not in registry
      final file = await _driveService!.driveApi.files.get(
        lastId,
        $fields: 'id, name, mimeType, parents, properties'
      ) as drive.File;
      
      setWorkspace(file);
      return true;

    } catch (e) {
      debugPrint('Failed to restore workspace: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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
