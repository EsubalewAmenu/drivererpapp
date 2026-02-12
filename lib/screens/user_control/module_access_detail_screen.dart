import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
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
  bool _isLoading = true;
  String? _errorMessage;
  late String _userEmail;

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
      final dashboardFileId = _extractFileId(row, 2);
      final settingsFileId = _extractFileId(row, 3);
      final tabsFileId = _extractFileId(row, 4);
      final moduleFilesFileId = _extractFileId(row, 5);
      
      debugPrint('Extracted File IDs:');
      debugPrint('  Dashboard ID: "$dashboardFileId"');
      debugPrint('  Settings ID: "$settingsFileId"');
      debugPrint('  Tabs ID: "$tabsFileId"');
      debugPrint('  Module Files ID: "$moduleFilesFileId"');
      debugPrint('  User Email: "$_userEmail"');
      debugPrint('=== Starting Permission Checks ===' );
      
      // Check actual sharing permissions for the invited user
      final permissions = _ModulePermissions(
        moduleFolderAccess: await _checkFileAccess(driveService, moduleFilesFileId, 'Module Folder'),
        dashboardAccess: await _checkFileAccess(driveService, dashboardFileId, 'Dashboard'),
        settingsAccess: await _checkFileAccess(driveService, settingsFileId, 'Settings'),
        tabsAccess: await _checkFileAccess(driveService, tabsFileId, 'Tabs'),
        moduleFilesAccess: await _checkFileAccess(driveService, moduleFilesFileId, 'Module Files'),
      );

      setState(() {
        _permissions = permissions;
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
            _buildReadOnlyAccessOption(
              'No Access',
              'User cannot see this folder',
              currentAccess,
              AccessLevel.noAccess,
              theme,
            ),
            const SizedBox(height: 12),
            _buildReadOnlyAccessOption(
              'Read Access',
              'User can view but not modify',
              currentAccess,
              AccessLevel.readOnly,
              theme,
            ),
            const SizedBox(height: 12),
            _buildReadOnlyAccessOption(
              'Write Access',
              'User can view and modify',
              currentAccess,
              AccessLevel.readWrite,
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
            _buildReadOnlyAccessOption(
              'Read Only',
              'User can view but not modify',
              currentAccess,
              AccessLevel.readOnly,
              theme,
            ),
            const SizedBox(height: 12),
            _buildReadOnlyAccessOption(
              'Write Access',
              'User can view and modify',
              currentAccess,
              AccessLevel.readWrite,
              theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyAccessOption(
    String title,
    String subtitle,
    AccessLevel currentAccess,
    AccessLevel optionValue,
    ThemeData theme,
  ) {
    final isSelected = currentAccess == optionValue;
    return Container(
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
