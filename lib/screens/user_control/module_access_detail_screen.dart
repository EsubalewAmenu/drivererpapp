import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis/drive/v3.dart' as google;
import '../../theme/app_theme.dart';
import '../../providers/drive_provider.dart';

enum AccessLevel { noAccess, readOnly, readWrite }

class ModuleAccessDetailScreen extends StatefulWidget {
  final String email;
  final String spreadsheetId;
  final String moduleId;
  final String moduleName;
  final int rowIndex;

  const ModuleAccessDetailScreen({
    super.key,
    required this.email,
    required this.spreadsheetId,
    required this.moduleId,
    required this.moduleName,
    required this.rowIndex,
  });

  @override
  State<ModuleAccessDetailScreen> createState() => _ModuleAccessDetailScreenState();
}

class _ModuleAccessDetailScreenState extends State<ModuleAccessDetailScreen> {
  late _ModulePermissions _permissions;
  late _ModulePermissions _originalPermissions;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  late String _userEmail;
  final Map<String, AccessLevel> _changedPermissions = {};

  @override
  void initState() {
    super.initState();
    _userEmail = widget.email;
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final driveProvider = Provider.of<DriveProvider>(context, listen: false);
      final driveService = driveProvider.driveService;
      if (driveService == null) {
        throw Exception('Drive service not available');
      }

      // Read the specific row to get file IDs
      final response = await driveService.sheetsApi.spreadsheets.values.get(
        widget.spreadsheetId,
        'modules!A${widget.rowIndex}:H${widget.rowIndex}',
      );

      final values = response.values ?? [];
      if (values.isEmpty || values[0].isEmpty) {
        throw Exception('Module data not found');
      }

      final row = values[0];
      
      debugPrint('=== Loading Module Permissions ===');
      debugPrint('Module: ${widget.moduleName}');
      debugPrint('Row Index: ${widget.rowIndex}');
      debugPrint('Row Data Length: ${row.length}');
      debugPrint('Full Row: $row');
      
      // Extract file IDs from the row - handle both empty and whitespace-only values
      // Format: [module_folder_id, name, dashboard_id, settings_id, tabs_id, module_files_id, module_type, status]
      final moduleFolderFileId = _extractFileId(row, 0);
      final dashboardFileId = _extractFileId(row, 2);
      final settingsFileId = _extractFileId(row, 3);
      final tabsFileId = _extractFileId(row, 4);
      final moduleFilesFileId = _extractFileId(row, 5);
      
      debugPrint('Extracted File IDs:');
      debugPrint('  Module Folder ID: "$moduleFolderFileId"');
      debugPrint('  Dashboard ID: "$dashboardFileId"');
      debugPrint('  Settings ID: "$settingsFileId"');
      debugPrint('  Tabs ID: "$tabsFileId"');
      debugPrint('  Module Files ID: "$moduleFilesFileId"');
      debugPrint('  User Email: "$_userEmail"');
      debugPrint('=== Starting Permission Checks ===' );
      
      // Check actual sharing permissions for the invited user
      final permissions = _ModulePermissions(
        moduleFolderAccess: await _checkFileAccess(driveService, moduleFolderFileId, 'Module Folder'),
        dashboardAccess: await _checkFileAccess(driveService, dashboardFileId, 'Dashboard'),
        settingsAccess: await _checkFileAccess(driveService, settingsFileId, 'Settings'),
        tabsAccess: await _checkFileAccess(driveService, tabsFileId, 'Tabs'),
        moduleFilesAccess: await _checkFileAccess(driveService, moduleFilesFileId, 'Module Files'),
      );

      setState(() {
        _permissions = permissions;
        _originalPermissions = _ModulePermissions(
          moduleFolderAccess: permissions.moduleFolderAccess,
          dashboardAccess: permissions.dashboardAccess,
          settingsAccess: permissions.settingsAccess,
          tabsAccess: permissions.tabsAccess,
          moduleFilesAccess: permissions.moduleFilesAccess,
        );
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading permissions: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String _extractFileId(List<Object?> row, int index) {
    if (row.length <= index) {
      return '';
    }
    final value = row[index];
    if (value == null) {
      return '';
    }
    final fileId = value.toString().trim();
    return fileId.isEmpty ? '' : fileId;
  }

  void _updatePermission(String component, AccessLevel value) {
    setState(() {
      _changedPermissions[component] = value;

      // Update the permissions object
      switch (component) {
        case 'moduleFolder':
          _permissions.moduleFolderAccess = value;
          break;
        case 'dashboard':
          _permissions.dashboardAccess = value;
          break;
        case 'settings':
          _permissions.settingsAccess = value;
          break;
        case 'tabs':
          _permissions.tabsAccess = value;
          break;
        case 'moduleFiles':
          _permissions.moduleFilesAccess = value;
          break;
      }
    });
  }

  Future<void> _savePermissions() async {
    if (_changedPermissions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes to save')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final driveProvider = Provider.of<DriveProvider>(context, listen: false);
      final driveService = driveProvider.driveService;
      if (driveService == null) {
        throw Exception('Drive service not available');
      }

      // Get the file IDs from the spreadsheet row
      final response = await driveService.sheetsApi.spreadsheets.values.get(
        widget.spreadsheetId,
        'modules!A${widget.rowIndex}:H${widget.rowIndex}',
      );

      final values = response.values ?? [];
      if (values.isEmpty || values[0].isEmpty) {
        throw Exception('Module data not found');
      }

      final row = values[0];
      
      // Extract file IDs
      final fileIds = {
        'moduleFolder': _extractFileId(row, 0),
        'dashboard': _extractFileId(row, 2),
        'settings': _extractFileId(row, 3),
        'tabs': _extractFileId(row, 4),
        'moduleFiles': _extractFileId(row, 5),
      };

      // Process each changed permission
      for (final entry in _changedPermissions.entries) {
        final component = entry.key;
        final newAccessLevel = entry.value;
        final fileId = fileIds[component];

        if (fileId == null || fileId.isEmpty) {
          debugPrint('Skipping $component - no file ID');
          continue;
        }

        // Get the original access level
        final originalAccessLevel = _getOriginalAccessLevel(component);

        // If changing FROM "No Access" TO something, we need to share the file
        if (originalAccessLevel == AccessLevel.noAccess && newAccessLevel != AccessLevel.noAccess) {
          debugPrint('Sharing $component with $_userEmail');
          await _shareFileWithUser(driveService, fileId, newAccessLevel, component);
        }
        // If changing TO "No Access", we would need to remove permissions
        else if (newAccessLevel == AccessLevel.noAccess && originalAccessLevel != AccessLevel.noAccess) {
          debugPrint('Removing share from $component for $_userEmail');
          await _removeFileShare(driveService, fileId, component);
        }
        // If changing between read and write access
        else if (originalAccessLevel != newAccessLevel) {
          debugPrint('Updating $component share for $_userEmail');
          await _updateFileShare(driveService, fileId, newAccessLevel, component);
        }
      }

      setState(() {
        _isSaving = false;
        _changedPermissions.clear();
        // Update original permissions to current state
        _originalPermissions = _ModulePermissions(
          moduleFolderAccess: _permissions.moduleFolderAccess,
          dashboardAccess: _permissions.dashboardAccess,
          settingsAccess: _permissions.settingsAccess,
          tabsAccess: _permissions.tabsAccess,
          moduleFilesAccess: _permissions.moduleFilesAccess,
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissions updated successfully')),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving permissions: $e')),
        );
      }
    }
  }

  AccessLevel _getOriginalAccessLevel(String component) {
    switch (component) {
      case 'moduleFolder':
        return _originalPermissions.moduleFolderAccess;
      case 'dashboard':
        return _originalPermissions.dashboardAccess;
      case 'settings':
        return _originalPermissions.settingsAccess;
      case 'tabs':
        return _originalPermissions.tabsAccess;
      case 'moduleFiles':
        return _originalPermissions.moduleFilesAccess;
      default:
        return AccessLevel.noAccess;
    }
  }

  Future<void> _shareFileWithUser(dynamic driveService, String fileId, AccessLevel accessLevel, String componentName) async {
    try {
      final role = accessLevel == AccessLevel.readWrite ? 'writer' : 'reader';
      
      final permission = google.Permission()
        ..emailAddress = _userEmail
        ..role = role
        ..type = 'user';

      await driveService.driveApi.permissions.create(
        permission,
        fileId,
        supportsAllDrives: true,
        sendNotificationEmail: false,
      );

      debugPrint('Successfully shared $componentName with $_userEmail as $role');
    } catch (e) {
      debugPrint('Error sharing $componentName with $_userEmail: $e');
      rethrow;
    }
  }

  Future<void> _updateFileShare(dynamic driveService, String fileId, AccessLevel accessLevel, String componentName) async {
    try {
      // First, find the permission ID for this user
      final permissions = await driveService.driveApi.permissions.list(
        fileId,
        supportsAllDrives: true,
        $fields: 'permissions(id,emailAddress,role)',
      );

      String? permissionId;
      for (final perm in (permissions.permissions ?? [])) {
        if (perm.emailAddress?.toLowerCase() == _userEmail.toLowerCase()) {
          permissionId = perm.id;
          break;
        }
      }

      if (permissionId == null) {
        throw Exception('Permission not found for $_userEmail');
      }

      final role = accessLevel == AccessLevel.readWrite ? 'writer' : 'reader';

      final permission = google.Permission()
        ..role = role;

      await driveService.driveApi.permissions.update(
        permission,
        fileId,
        permissionId,
        supportsAllDrives: true,
      );

      debugPrint('Successfully updated $componentName share for $_userEmail to $role');
    } catch (e) {
      debugPrint('Error updating $componentName share for $_userEmail: $e');
      rethrow;
    }
  }

  Future<void> _removeFileShare(dynamic driveService, String fileId, String componentName) async {
    try {
      // First, find the permission ID for this user
      final permissions = await driveService.driveApi.permissions.list(
        fileId,
        supportsAllDrives: true,
        $fields: 'permissions(id,emailAddress)',
      );

      String? permissionId;
      for (final perm in (permissions.permissions ?? [])) {
        if (perm.emailAddress?.toLowerCase() == _userEmail.toLowerCase()) {
          permissionId = perm.id;
          break;
        }
      }

      if (permissionId == null) {
        debugPrint('No permission found to remove for $componentName');
        return;
      }

      await driveService.driveApi.permissions.delete(
        fileId,
        permissionId,
        supportsAllDrives: true,
      );

      debugPrint('Successfully removed $componentName share for $_userEmail');
    } catch (e) {
      debugPrint('Error removing $componentName share for $_userEmail: $e');
      rethrow;
    }
  }

  Future<AccessLevel> _checkFileAccess(dynamic driveService, String fileId, String componentName) async {
    if (fileId.isEmpty) {
      debugPrint('  $componentName: No file ID provided');
      return AccessLevel.noAccess;
    }

    try {
      debugPrint('  Checking $componentName access (ID: $fileId)...');
      
      // Check if the user has access to this file
      // Request specific fields to ensure we get emailAddress
      final permissions = await driveService.driveApi.permissions.list(
        fileId,
        supportsAllDrives: true,
        pageSize: 100,
        $fields: 'permissions(id,emailAddress,displayName,role,type,kind)',
      );

      final permissionsList = permissions.permissions ?? [];
      debugPrint('    Found ${permissionsList.length} permissions for file: $fileId');
      
      // Look for the invited user's email in the permissions
      for (final perm in permissionsList) {
        debugPrint('    - Email: ${perm.emailAddress}, DisplayName: ${perm.displayName}, ID: ${perm.id}, Type: ${perm.type}, Role: ${perm.role}');
      }
      
      for (final perm in permissionsList) {
        // Check both emailAddress and displayName
        final permEmail = perm.emailAddress?.toLowerCase();
        final userEmailLower = _userEmail.toLowerCase();
        
        if (permEmail == userEmailLower || perm.displayName?.toLowerCase() == userEmailLower) {
          debugPrint('    ✓ Match found for $_userEmail! Role: ${perm.role}');
          
          // Check the role for write access
          // Write access roles: owner, writer, fileOrganizer, organizer, editor
          final writeAccessRoles = ['owner', 'writer', 'fileOrganizer', 'organizer'];
          final readAccessRoles = ['reader', 'commenter', 'viewer'];
          
          if (writeAccessRoles.contains(perm.role)) {
            debugPrint('    ✓ Returning READ_WRITE (role: ${perm.role})');
            return AccessLevel.readWrite;
          } else if (readAccessRoles.contains(perm.role)) {
            debugPrint('    ✓ Returning READ_ONLY (role: ${perm.role})');
            return AccessLevel.readOnly;
          } else {
            debugPrint('    ⚠ Unknown role: ${perm.role}, treating as READ_WRITE for editor access');
            return AccessLevel.readWrite;
          }
        }
      }
      
      // User not found in permissions
      debugPrint('    ✗ User $_userEmail not found in permissions list');
      return AccessLevel.noAccess;
    } catch (e) {
      debugPrint('  ERROR checking $componentName access (ID: $fileId): $e');
      return AccessLevel.noAccess;
    }
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.moduleName.toUpperCase(),
          style: AppTheme.inter(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: theme.iconTheme,
      ),
      body: _buildBody(theme),
      bottomNavigationBar: _changedPermissions.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _savePermissions,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: theme.primaryColor,
                  disabledBackgroundColor: theme.disabledColor,
                ),
                child: _isSaving
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(theme.scaffoldBackgroundColor),
                        ),
                      )
                    : Text(
                        'SAVE CHANGES',
                        style: AppTheme.inter(
                          fontWeight: FontWeight.w700,
                          color: theme.scaffoldBackgroundColor,
                        ),
                      ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: theme.disabledColor),
              const SizedBox(height: 16),
              Text(
                'Failed to load permissions',
                style: AppTheme.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: AppTheme.inter(
                  fontSize: 13,
                  color: theme.disabledColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadPermissions,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Text(
              'User: ${widget.email}',
              style: AppTheme.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          ),
          const Divider(),
          const SizedBox(height: 16),
          _buildFolderAccessCard('Module Folder', 'moduleFolder', _permissions.moduleFolderAccess, theme),
          _buildFolderAccessCard('Module Files', 'moduleFiles', _permissions.moduleFilesAccess, theme),
          _buildAccessCard('Dashboard', 'dashboard', _permissions.dashboardAccess, theme),
          _buildAccessCard('Settings', 'settings', _permissions.settingsAccess, theme),
          _buildAccessCard('Tabs', 'tabs', _permissions.tabsAccess, theme),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFolderAccessCard(
    String label,
    String componentId,
    AccessLevel currentAccess,
    ThemeData theme,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: AppTheme.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.titleMedium?.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildAccessOption(
              componentId,
              AccessLevel.noAccess,
              'No Access',
              'User cannot see this folder',
              currentAccess,
              theme,
            ),
            const SizedBox(height: 12),
            _buildAccessOption(
              componentId,
              AccessLevel.readOnly,
              'Read Access',
              'User can view but not modify',
              currentAccess,
              theme,
            ),
            const SizedBox(height: 12),
            _buildAccessOption(
              componentId,
              AccessLevel.readWrite,
              'Write Access',
              'User can view and modify',
              currentAccess,
              theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessCard(
    String label,
    String componentId,
    AccessLevel currentAccess,
    ThemeData theme,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: AppTheme.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.titleMedium?.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildAccessOption(
              componentId,
              AccessLevel.noAccess,
              'No Access',
              'User cannot access this file',
              currentAccess,
              theme,
            ),
            const SizedBox(height: 12),
            _buildAccessOption(
              componentId,
              AccessLevel.readOnly,
              'Read Only',
              'User can view but not modify',
              currentAccess,
              theme,
            ),
            const SizedBox(height: 12),
            _buildAccessOption(
              componentId,
              AccessLevel.readWrite,
              'Write Access',
              'User can view and modify',
              currentAccess,
              theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessOption(
    String componentId,
    AccessLevel value,
    String title,
    String subtitle,
    AccessLevel currentAccess,
    ThemeData theme,
  ) {
    final isSelected = currentAccess == value;
    return InkWell(
      onTap: () {
        _updatePermission(componentId, value);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? theme.primaryColor : theme.dividerColor.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? theme.primaryColor : theme.disabledColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTheme.inter(
                      fontSize: 12,
                      color: theme.disabledColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModulePermissions {
  AccessLevel moduleFolderAccess;
  AccessLevel dashboardAccess;
  AccessLevel settingsAccess;
  AccessLevel tabsAccess;
  AccessLevel moduleFilesAccess;

  _ModulePermissions({
    required this.moduleFolderAccess,
    required this.dashboardAccess,
    required this.settingsAccess,
    required this.tabsAccess,
    required this.moduleFilesAccess,
  });
}
