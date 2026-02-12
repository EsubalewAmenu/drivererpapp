import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../../providers/drive_provider.dart';
import '../../providers/workspace_provider.dart';
import '../../models/schema_models.dart';

class UserAccessManagementScreen extends StatefulWidget {
  final String email;
  final String spreadsheetId;

  const UserAccessManagementScreen({
    super.key,
    required this.email,
    required this.spreadsheetId,
  });

  @override
  State<UserAccessManagementScreen> createState() => _UserAccessManagementScreenState();
}

class _UserAccessManagementScreenState extends State<UserAccessManagementScreen> {
  List<_ModuleAccessItem> _modules = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSaving = false;
  final Map<String, bool> _accessChanges = {};

  @override
  void initState() {
    super.initState();
    _loadUserAccess();
  }

  Future<void> _loadUserAccess() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
      final driveProvider = Provider.of<DriveProvider>(context, listen: false);

      final driveService = driveProvider.driveService;
      if (driveService == null) {
        throw Exception('Drive service not available');
      }

      final rootFolderId = workspaceProvider.rootFolderId;
      if (rootFolderId == null || rootFolderId.isEmpty) {
        throw Exception('Root folder not found');
      }

      final currentWorkspaceId = workspaceProvider.currentWorkspace?.id;
      if (currentWorkspaceId == null || currentWorkspaceId.isEmpty) {
        throw Exception('No workspace selected');
      }

      // Get companies registry ID
      final companiesRegistryId = await driveService.ensureCompanyRegistry(rootFolderId);

      // Read modules from companies registry
      final modulesResponse = await driveService.sheetsApi.spreadsheets.values.get(
        companiesRegistryId,
        'modules!A2:D1000',
      );

      final modulesValues = modulesResponse.values ?? [];
      final registeredModules = <String, List<String>>{};

      for (final row in modulesValues) {
        if (row.isNotEmpty) {
          final moduleId = row[0].toString();
          final moduleName = row.length > 1 ? row[1].toString() : moduleId;
          registeredModules[moduleId] = [moduleName];
        }
      }

      // Read user's current access from their personal spreadsheet
      final userAccessResponse = await driveService.sheetsApi.spreadsheets.values.get(
        widget.spreadsheetId,
        'modules!A2:F1000',
      );

      final userAccessValues = userAccessResponse.values ?? [];
      final userModuleAccess = <String, Map<String, dynamic>>{};
      List<String> headerRow = [];

      if (userAccessValues.isNotEmpty) {
        // First row is header
        headerRow = List<String>.from(userAccessValues[0].map((e) => e.toString()));

        // Parse data rows
        for (int i = 1; i < userAccessValues.length; i++) {
          final row = userAccessValues[i];
          if (row.isNotEmpty) {
            final moduleId = row[0].toString();
            final moduleName = row.length > 1 ? row[1].toString() : '';
            final dashboard = row.length > 2 ? row[2].toString().toLowerCase() == 'true' : false;
            final settings = row.length > 3 ? row[3].toString().toLowerCase() == 'true' : false;
            final tabs = row.length > 4 ? row[4].toString() : '';
            final moduleFiles = row.length > 5 ? row[5].toString() : '';

            userModuleAccess[moduleId] = {
              'moduleName': moduleName,
              'dashboard': dashboard,
              'settings': settings,
              'tabs': tabs,
              'moduleFiles': moduleFiles,
              'rowIndex': i + 2, // +2 because API returns data starting from row 2
            };
          }
        }
      }

      // Build module list
      final modules = <_ModuleAccessItem>[];
      for (final moduleId in registeredModules.keys) {
        final moduleName = registeredModules[moduleId]![0];
        final userAccess = userModuleAccess[moduleId];

        modules.add(_ModuleAccessItem(
          moduleId: moduleId,
          moduleName: moduleName,
          hasDashboard: userAccess?['dashboard'] as bool? ?? false,
          hasSettings: userAccess?['settings'] as bool? ?? false,
          tabs: userAccess?['tabs'] as String? ?? '',
          moduleFiles: userAccess?['moduleFiles'] as String? ?? '',
          rowIndex: userAccess?['rowIndex'] as int? ?? -1,
        ));
      }

      setState(() {
        _modules = modules;
        _isLoading = false;
        _accessChanges.clear();
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_accessChanges.isEmpty) {
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

      // Update user's spreadsheet with changes
      for (final moduleId in _accessChanges.keys) {
        final module = _modules.firstWhere((m) => m.moduleId == moduleId);
        final hasAccess = _accessChanges[moduleId]!;

        if (hasAccess && module.rowIndex == -1) {
          // Add new row for this module
          final row = [
            module.moduleId,
            module.moduleName,
            'true', // dashboard
            'false', // settings
            '', // tabs
            '', // module_files
          ];

          await driveService.sheetsApi.spreadsheets.values.append(
            sheets.ValueRange(values: [row]),
            widget.spreadsheetId,
            'modules!A1',
            valueInputOption: 'RAW',
            insertDataOption: 'INSERT_ROWS',
          );
        } else if (!hasAccess && module.rowIndex != -1) {
          // Remove row for this module
          await driveService.sheetsApi.spreadsheets.batchUpdate(
            sheets.BatchUpdateSpreadsheetRequest(
              requests: [
                sheets.Request(
                  deleteDimension: sheets.DeleteDimensionRequest(
                    range: sheets.DimensionRange(
                      sheetId: 0,
                      dimension: 'ROWS',
                      startIndex: module.rowIndex - 1,
                      endIndex: module.rowIndex,
                    ),
                  ),
                ),
              ],
            ),
            widget.spreadsheetId,
          );
        }
      }

      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access updated successfully')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving changes: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'MANAGE ACCESS',
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
      bottomNavigationBar: _accessChanges.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveChanges,
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
                'Failed to load access settings',
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
                onPressed: _loadUserAccess,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_modules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 64, color: theme.disabledColor),
            const SizedBox(height: 16),
            Text(
              'No modules available',
              style: AppTheme.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          ],
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
          const SizedBox(height: 8),
          ...List.generate(_modules.length, (index) {
            final module = _modules[index];
            return _buildModuleCard(module, theme, index);
          }),
        ],
      ),
    );
  }

  Widget _buildModuleCard(
    _ModuleAccessItem module,
    ThemeData theme,
    int index,
  ) {
    // Get current access state (either changed or original)
    final hasAccess = _accessChanges[module.moduleId] ?? (module.rowIndex != -1);

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    module.moduleName,
                    style: AppTheme.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.titleMedium?.color,
                    ),
                  ),
                ),
                Switch(
                  value: hasAccess,
                  onChanged: (value) {
                    setState(() {
                      if (value == (module.rowIndex != -1)) {
                        // Reset to original state
                        _accessChanges.remove(module.moduleId);
                      } else {
                        // Track the change
                        _accessChanges[module.moduleId] = value;
                      }
                    });
                  },
                  activeColor: theme.primaryColor,
                ),
              ],
            ),
            if (hasAccess) ...[
              const SizedBox(height: 12),
              _buildAccessOption('Dashboard', module.hasDashboard, theme),
              _buildAccessOption('Settings', module.hasSettings, theme),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildAccessOption(String label, bool hasAccess, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            hasAccess ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: hasAccess ? Colors.green : theme.disabledColor,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTheme.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleAccessItem {
  final String moduleId;
  final String moduleName;
  final bool hasDashboard;
  final bool hasSettings;
  final String tabs;
  final String moduleFiles;
  final int rowIndex;

  _ModuleAccessItem({
    required this.moduleId,
    required this.moduleName,
    required this.hasDashboard,
    required this.hasSettings,
    required this.tabs,
    required this.moduleFiles,
    required this.rowIndex,
  });
}
