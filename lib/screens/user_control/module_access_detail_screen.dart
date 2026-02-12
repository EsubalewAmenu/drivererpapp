import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import '../../theme/app_theme.dart';
import '../../providers/drive_provider.dart';

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
  bool _isSaving = false;
  final Map<String, Map<String, bool>> _changedPermissions = {};

  @override
  void initState() {
    super.initState();
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

      // Read the specific row from the user's spreadsheet
      final response = await driveService.sheetsApi.spreadsheets.values.get(
        widget.spreadsheetId,
        'modules!A${widget.rowIndex}:H${widget.rowIndex}',
      );

      final values = response.values ?? [];
      if (values.isEmpty || values[0].isEmpty) {
        throw Exception('Module data not found');
      }

      final row = values[0];
      
      // Parse permissions from the row
      // Assuming the format is: id, name, dashboard, settings, tabs, module_files, module_type, status
      final permissions = _ModulePermissions(
        moduleFolderRead: true, // Module folder always has read access
        moduleFolderWrite: false,
        dashboardRead: row.length > 2 ? row[2].toString().toLowerCase() == 'true' : false,
        dashboardWrite: false,
        settingsRead: row.length > 3 ? row[3].toString().toLowerCase() == 'true' : false,
        settingsWrite: false,
        tabsRead: (row.length > 4 ? row[4].toString() : '').isNotEmpty,
        tabsWrite: false,
        moduleFilesRead: (row.length > 5 ? row[5].toString() : '').isNotEmpty,
        moduleFilesWrite: false,
      );

      setState(() {
        _permissions = permissions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
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

      // Build the updated row with new values
      final updatedRow = [
        widget.moduleId,
        widget.moduleName,
        _permissions.dashboardRead ? 'true' : 'false', // dashboard
        _permissions.settingsRead ? 'true' : 'false', // settings
        _permissions.tabsRead ? 'tabs' : '', // tabs (just indicate presence)
        _permissions.moduleFilesRead ? 'module_files' : '', // module_files
      ];

      // Update the spreadsheet
      await driveService.sheetsApi.spreadsheets.values.update(
        sheets.ValueRange(values: [updatedRow]),
        widget.spreadsheetId,
        'modules!A${widget.rowIndex}:F${widget.rowIndex}',
        valueInputOption: 'RAW',
      );

      setState(() {
        _isSaving = false;
        _changedPermissions.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissions updated successfully')),
        );
        Navigator.of(context).pop();
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

  void _updatePermission(String component, String type, bool value) {
    setState(() {
      if (!_changedPermissions.containsKey(component)) {
        _changedPermissions[component] = {};
      }
      _changedPermissions[component]![type] = value;

      // Update the permissions object
      switch (component) {
        case 'moduleFolder':
          if (type == 'read') _permissions.moduleFolderRead = value;
          if (type == 'write') _permissions.moduleFolderWrite = value;
          break;
        case 'dashboard':
          if (type == 'read') _permissions.dashboardRead = value;
          if (type == 'write') _permissions.dashboardWrite = value;
          break;
        case 'settings':
          if (type == 'read') _permissions.settingsRead = value;
          if (type == 'write') _permissions.settingsWrite = value;
          break;
        case 'tabs':
          if (type == 'read') _permissions.tabsRead = value;
          if (type == 'write') _permissions.tabsWrite = value;
          break;
        case 'moduleFiles':
          if (type == 'read') _permissions.moduleFilesRead = value;
          if (type == 'write') _permissions.moduleFilesWrite = value;
          break;
      }
    });
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
          _buildPermissionCard('Module Folder', 'moduleFolder', _permissions.moduleFolderRead, _permissions.moduleFolderWrite, theme),
          _buildPermissionCard('Dashboard', 'dashboard', _permissions.dashboardRead, _permissions.dashboardWrite, theme),
          _buildPermissionCard('Settings', 'settings', _permissions.settingsRead, _permissions.settingsWrite, theme),
          _buildPermissionCard('Tabs', 'tabs', _permissions.tabsRead, _permissions.tabsWrite, theme),
          _buildPermissionCard('Module Files', 'moduleFiles', _permissions.moduleFilesRead, _permissions.moduleFilesWrite, theme),
        ],
      ),
    );
  }

  Widget _buildPermissionCard(
    String label,
    String componentId,
    bool readAccess,
    bool writeAccess,
    ThemeData theme,
  ) {
    final hasChanges = _changedPermissions.containsKey(componentId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTheme.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.titleMedium?.color,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.visibility,
                      size: 20,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Read',
                      style: AppTheme.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: readAccess,
                  onChanged: (value) {
                    _updatePermission(componentId, 'read', value);
                  },
                  activeColor: theme.primaryColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.edit,
                      size: 20,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Write',
                      style: AppTheme.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: writeAccess,
                  onChanged: (value) {
                    _updatePermission(componentId, 'write', value);
                  },
                  activeColor: theme.primaryColor,
                ),
              ],
            ),
            if (hasChanges) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Modified',
                  style: AppTheme.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.primaryColor,
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

class _ModulePermissions {
  bool moduleFolderRead;
  bool moduleFolderWrite;
  bool dashboardRead;
  bool dashboardWrite;
  bool settingsRead;
  bool settingsWrite;
  bool tabsRead;
  bool tabsWrite;
  bool moduleFilesRead;
  bool moduleFilesWrite;

  _ModulePermissions({
    required this.moduleFolderRead,
    required this.moduleFolderWrite,
    required this.dashboardRead,
    required this.dashboardWrite,
    required this.settingsRead,
    required this.settingsWrite,
    required this.tabsRead,
    required this.tabsWrite,
    required this.moduleFilesRead,
    required this.moduleFilesWrite,
  });
}
