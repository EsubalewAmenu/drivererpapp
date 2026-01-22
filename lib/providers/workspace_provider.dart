import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/company_model.dart';
import '../services/drive_service.dart';

class WorkspaceProvider extends ChangeNotifier {
  final DriveService? _driveService;
  
  drive.File? _currentWorkspace;
  String? _rootFolderId;
  List<Company> _companies = [];
  bool _isLoading = false;

  WorkspaceProvider({DriveService? driveService}) : _driveService = driveService;

  drive.File? get currentWorkspace => _currentWorkspace;
  String? get rootFolderId => _rootFolderId;
  List<Company> get companies => _companies;
  bool get isLoading => _isLoading;
  bool get hasWorkspace => _currentWorkspace != null;

  Company? get currentCompany {
    if (_currentWorkspace == null) return null;
    try {
      return _companies.firstWhere((c) => c.folderId == _currentWorkspace!.id);
    } catch (_) {
      return null;
    }
  }

  void setRootFolderId(String id) {
    _rootFolderId = id;
    notifyListeners();
  }

  Future<void> loadCompanies(String rootFolderId) async {
    if (_driveService == null) return;
    
    _rootFolderId = rootFolderId;
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
    
    _rootFolderId = rootFolderId;
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

  Future<void> updateCompanyName(String newName) async {
    if (_driveService == null || _currentWorkspace == null || _rootFolderId == null) {
      debugPrint('Update failed: Missing service, workspace or root folder ID');
      return;
    }
    
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Find the current company object
      final companyIndex = _companies.indexWhere((c) => c.folderId == _currentWorkspace!.id);
      if (companyIndex == -1) throw Exception('Current company not found in registry');

      final current = _companies[companyIndex];
      final updated = Company(
        id: current.id,
        name: newName,
        folderId: current.folderId,
        logoUrl: current.logoUrl,
        role: current.role,
      );

      // 2. Update via DriveService (spreadsheet)
      await _driveService!.updateCompany(_rootFolderId!, updated);

      // 3. Update local state
      _companies[companyIndex] = updated;
      
      // Update the currentWorkspace file object as well so the UI reflects it immediately
      final updatedFile = drive.File()
        ..id = _currentWorkspace!.id
        ..name = newName;
      _currentWorkspace = updatedFile;

    } catch (e) {
      debugPrint('Error updating company name: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateCompanyLogo(List<int> bytes, String extension) async {
    if (_driveService == null || _currentWorkspace == null || _rootFolderId == null) {
      debugPrint('Logo update failed: Missing service, workspace or root folder ID');
      return;
    }
    
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Find the current company object to get its internal ID
      final companyIndex = _companies.indexWhere((c) => c.folderId == _currentWorkspace!.id);
      if (companyIndex == -1) {
        throw Exception('Current company not found in registry. Logo update requires a registered workspace.');
      }

      final company = _companies[companyIndex];
      
      // 2. Perform upload and deletion of old logo via service
      final newUrl = await _driveService!.updateCompanyLogo(
        _rootFolderId!, 
        company.id, 
        bytes, 
        extension
      );

      // 3. Update local state
      if (companyIndex != -1) {
        _companies[companyIndex] = Company(
          id: company.id,
          name: company.name,
          folderId: company.folderId,
          logoUrl: newUrl,
          role: company.role,
        );
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating company logo in provider: $e');
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
      _rootFolderId = rootId;
      
      if (rootId != null) {
        // 2. Try to fetch from registry to get the CORRECT name
        try {
          // Temporarily ensure registry exists (lightweight check inside mixin)
          // We don't call ensureCompanyRegistry here to avoid write ops during read
          final companies = await _driveService!.getCompanies(rootId);
          _companies = companies; // Cache these
          
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
        $fields: 'id, name, mimeType, parents, properties',
        supportsAllDrives: true,
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
