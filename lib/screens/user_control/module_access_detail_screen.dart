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
  bool _isSaving = false;
  final Map<String, dynamic> _changedPermissions = {};

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
      // Format: id, name, dashboard, settings, tabs, module_files, module_type, status
      final permissions = _ModulePermissions(
        moduleFolderAccess: AccessLevel.readOnly, // Module folder default read-only
        dashboardAccess: row.length > 2 ? row[2].toString().toLowerCase() == 'true' ? AccessLevel.readWrite : AccessLevel.readOnly : AccessLevel.readOnly,
        settingsAccess: row.length > 3 ? row[3].toString().toLowerCase() == 'true' ? AccessLevel.readWrite : AccessLevel.readOnly : AccessLevel.readOnly,
        tabsAccess: (row.length > 4 ? row[4].toString() : '').isNotEmpty ? AccessLevel.readWrite : AccessLevel.readOnly,
        moduleFilesAccess: (row.length > 5 ? row[5].toString() : '').isNotEmpty ? AccessLevel.readWrite : AccessLevel.noAccess,
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
        _permissions.dashboardAccess != AccessLevel.noAccess ? 'true' : 'false', // dashboard (mandatory, always true if active)
        _permissions.settingsAccess != AccessLevel.noAccess ? 'true' : 'false', // settings (mandatory, always true if active)
        _permissions.tabsAccess != AccessLevel.noAccess ? 'tabs' : '', // tabs (mandatory, always present if active)
        _permissions.moduleFilesAccess != AccessLevel.noAccess ? 'module_files' : '', // module_files
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
    final hasChanges = _changedPermissions.containsKey(componentId);

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
                if (hasChanges)
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
              ],
            ),
            const SizedBox(height: 16),
            _buildRadioOption(
              componentId,
              AccessLevel.noAccess,
              'No Access',
              'User cannot see this folder',
              currentAccess,
              theme,
            ),
            const SizedBox(height: 12),
            _buildRadioOption(
              componentId,
              AccessLevel.readOnly,
              'Read Access',
              'User can view but not modify',
              currentAccess,
              theme,
            ),
            const SizedBox(height: 12),
            _buildRadioOption(
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
    final hasChanges = _changedPermissions.containsKey(componentId);

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
                if (hasChanges)
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
              ],
            ),
            const SizedBox(height: 16),
            _buildRadioOption(
              componentId,
              AccessLevel.readOnly,
              'Read Only',
              'User can view but not modify',
              currentAccess,
              theme,
            ),
            const SizedBox(height: 12),
            _buildRadioOption(
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

  Widget _buildRadioOption(
    String componentId,
    AccessLevel value,
    String title,
    String subtitle,
    AccessLevel currentAccess,
    ThemeData theme,
  ) {
    return InkWell(
      onTap: () {
        _updatePermission(componentId, value);
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Radio<AccessLevel>(
              value: value,
              groupValue: currentAccess,
              onChanged: (newValue) {
                if (newValue != null) {
                  _updatePermission(componentId, newValue);
                }
              },
              activeColor: theme.primaryColor,
            ),
            const SizedBox(width: 8),
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
