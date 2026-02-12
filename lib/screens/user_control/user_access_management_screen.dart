import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../../providers/drive_provider.dart';
import '../../providers/workspace_provider.dart';
import '../../models/schema_models.dart';
import 'module_access_detail_screen.dart';

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
  bool _isAddingModules = false;

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
      final driveProvider = Provider.of<DriveProvider>(context, listen: false);

      final driveService = driveProvider.driveService;
      if (driveService == null) {
        throw Exception('Drive service not available');
      }

      // Read user's current access from their personal spreadsheet
      final userAccessResponse = await driveService.sheetsApi.spreadsheets.values.get(
        widget.spreadsheetId,
        'modules!A1:H1000',
      );

      final userAccessValues = userAccessResponse.values ?? [];
      final userModuleAccess = <String, _ModuleAccessItem>{};

      if (userAccessValues.isNotEmpty) {
        // First row is header (skip it)
        for (int i = 1; i < userAccessValues.length; i++) {
          final row = userAccessValues[i];
          if (row.isNotEmpty) {
            final moduleId = row[0].toString();
            final moduleName = row.length > 1 ? row[1].toString() : '';
            final dashboard = row.length > 2 ? row[2].toString().toLowerCase() == 'true' : false;
            final settings = row.length > 3 ? row[3].toString().toLowerCase() == 'true' : false;
            final tabs = row.length > 4 ? row[4].toString() : '';
            final moduleFiles = row.length > 5 ? row[5].toString() : '';
            final moduleType = row.length > 6 ? row[6].toString() : '';
            final status = row.length > 7 ? row[7].toString() : 'activated';
            
            // A module is considered active based on status column
            final isActive = status.toLowerCase() == 'activated';

            userModuleAccess[moduleId] = _ModuleAccessItem(
              moduleId: moduleId,
              moduleName: moduleName,
              hasDashboard: dashboard,
              hasSettings: settings,
              tabs: tabs,
              moduleFiles: moduleFiles,
              moduleType: moduleType,
              status: status,
              rowIndex: i + 1,
              isActive: isActive,
            );
          }
        }
      }

      setState(() {
        _modules = userModuleAccess.values.toList();
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

  Future<String?> _getCurrentUserAccessSpreadsheetId() async {
    final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
    String? uaId = workspaceProvider.lastUserAccessSpreadsheetId;
    if (uaId == null || uaId.isEmpty) {
      try {
        uaId = await WorkspaceProvider.getLastUserAccessSpreadsheetId();
      } catch (_) {
        return null;
      }
    }
    return uaId;
  }

  Future<List<_ModuleSourceItem>> _loadAvailableModules() async {
    final driveProvider = Provider.of<DriveProvider>(context, listen: false);
    final driveService = driveProvider.driveService;
    if (driveService == null) {
      throw Exception('Drive service not available');
    }

    final currentUserSheetId = await _getCurrentUserAccessSpreadsheetId();
    if (currentUserSheetId == null || currentUserSheetId.isEmpty) {
      throw Exception('Current user access spreadsheet not found');
    }

    final resp = await driveService.sheetsApi.spreadsheets.values.get(
      currentUserSheetId,
      'modules!A1:H1000',
    );

    final values = resp.values ?? [];
    if (values.isEmpty) return [];

    final existingIds = _modules.map((m) => m.moduleId).toSet();
    final items = <_ModuleSourceItem>[];

    for (int i = 1; i < values.length; i++) {
      final row = values[i];
      if (row.isEmpty) continue;
      final moduleId = row[0].toString();
      if (moduleId.isEmpty || existingIds.contains(moduleId)) continue;

      final moduleName = row.length > 1 ? row[1].toString() : '';
      final dashboardId = row.length > 2 ? row[2].toString() : '';
      final settingsId = row.length > 3 ? row[3].toString() : '';
      final tabsId = row.length > 4 ? row[4].toString() : '';
      final moduleFilesId = row.length > 5 ? row[5].toString() : '';
      final moduleType = row.length > 6 ? row[6].toString() : '';
      final status = row.length > 7 ? row[7].toString() : 'activated';

      if (status.toLowerCase() == 'deactivated') continue;

      items.add(_ModuleSourceItem(
        moduleId: moduleId,
        moduleName: moduleName,
        dashboardId: dashboardId,
        settingsId: settingsId,
        tabsId: tabsId,
        moduleFilesId: moduleFilesId,
        moduleType: moduleType,
      ));
    }

    return items;
  }

  Future<void> _showAddModuleDialog(ThemeData theme) async {
    final future = _loadAvailableModules();
    final selected = <String>{};

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Add Modules',
                style: AppTheme.inter(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: FutureBuilder<List<_ModuleSourceItem>>(
                  future: future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Text(
                        'Failed to load modules: ${snapshot.error}',
                        style: AppTheme.inter(fontSize: 12, color: theme.disabledColor),
                      );
                    }

                    final modules = snapshot.data ?? [];
                    if (modules.isEmpty) {
                      return Text(
                        'No additional modules available to add.',
                        style: AppTheme.inter(fontSize: 13, color: theme.textTheme.bodyMedium?.color),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: modules.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final module = modules[index];
                        final isSelected = selected.contains(module.moduleId);
                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              if (isSelected) {
                                selected.remove(module.moduleId);
                              } else {
                                selected.add(module.moduleId);
                              }
                            });
                          },
                          child: Row(
                            children: [
                              Checkbox(
                                value: isSelected,
                                onChanged: (value) {
                                  setDialogState(() {
                                    if (value == true) {
                                      selected.add(module.moduleId);
                                    } else {
                                      selected.remove(module.moduleId);
                                    }
                                  });
                                },
                              ),
                              Expanded(
                                child: Text(
                                  module.moduleName.isNotEmpty ? module.moduleName : module.moduleId,
                                  style: AppTheme.inter(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: AppTheme.inter(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: _isAddingModules
                      ? null
                      : () async {
                          try {
                            setState(() {
                              _isAddingModules = true;
                            });

                            final driveProvider = Provider.of<DriveProvider>(context, listen: false);
                            final driveService = driveProvider.driveService;
                            if (driveService == null) {
                              throw Exception('Drive service not available');
                            }

                            final modules = await future;
                            final toAdd = modules.where((m) => selected.contains(m.moduleId)).toList();
                            if (toAdd.isEmpty) {
                              Navigator.pop(context);
                              return;
                            }

                            for (final module in toAdd) {
                              final configFolderId = await driveService.getOrCreateSubFolder(
                                module.moduleId,
                                'config',
                              );

                              final settings = module.settingsId.isNotEmpty
                                  ? await driveService.readSettingsById(module.settingsId)
                                  : null;
                              final dashboard = module.dashboardId.isNotEmpty
                                  ? await driveService.readDashboardById(module.dashboardId)
                                  : null;
                              final tabs = module.tabsId.isNotEmpty
                                  ? await driveService.readTabsById(module.tabsId)
                                  : null;

                              final config = {
                                'settings': settings ?? <String, dynamic>{},
                                'dashboard': dashboard ?? <String, dynamic>{'cards': []},
                                'tabs': tabs ?? <dynamic>[],
                              };

                              final configIds = await driveService.createModuleConfig(
                                configFolderId,
                                module.moduleName.isNotEmpty ? module.moduleName : module.moduleId,
                                config,
                              );

                              await driveService.upsertUserAccessModule(
                                widget.spreadsheetId,
                                module.moduleId,
                                module.moduleName,
                                configIds['dashboard'] ?? '',
                                configIds['settings'] ?? '',
                                configIds['tabs'] ?? '',
                                module.moduleFilesId,
                                moduleType: module.moduleType,
                              );
                              await driveService.setUserAccessModuleStatus(
                                widget.spreadsheetId,
                                module.moduleId,
                                'activated',
                              );
                            }

                            if (mounted) {
                              Navigator.pop(context);
                              await _loadUserAccess();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Modules added successfully')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error adding modules: $e')),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isAddingModules = false;
                              });
                            }
                          }
                        },
                  child: Text(
                    'Add',
                    style: AppTheme.inter(fontWeight: FontWeight.w600, color: theme.primaryColor),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
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

        // Update only the status column (column H)
        final status = hasAccess ? 'activated' : 'deactivated';
        
        await driveService.sheetsApi.spreadsheets.values.update(
          sheets.ValueRange(values: [[status]]),
          widget.spreadsheetId,
          'modules!H${module.rowIndex}',
          valueInputOption: 'RAW',
        );
        
        // Update local state to reflect the change
        final updatedModule = _modules.firstWhere((m) => m.moduleId == moduleId);
        final index = _modules.indexOf(updatedModule);
        _modules[index] = _ModuleAccessItem(
          moduleId: updatedModule.moduleId,
          moduleName: updatedModule.moduleName,
          hasDashboard: updatedModule.hasDashboard,
          hasSettings: updatedModule.hasSettings,
          tabs: updatedModule.tabs,
          moduleFiles: updatedModule.moduleFiles,
          moduleType: updatedModule.moduleType,
          status: status,
          rowIndex: updatedModule.rowIndex,
          isActive: hasAccess,
        );
      }

      setState(() {
        _isSaving = false;
        _accessChanges.clear();
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
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: _isAddingModules ? null : () => _showAddModuleDialog(theme),
              icon: const Icon(Icons.add_circle_outline),
              label: Text(
                'ADD MODULE',
                style: AppTheme.inter(fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: theme.primaryColor.withValues(alpha: 0.6)),
              ),
            ),
            if (_accessChanges.isNotEmpty) ...[
              const SizedBox(height: 12),
              ElevatedButton(
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
            ],
          ],
        ),
      ),
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
    final hasAccess = _accessChanges[module.moduleId] ?? module.isActive;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ModuleAccessDetailScreen(
              email: widget.email,
              spreadsheetId: widget.spreadsheetId,
              moduleId: module.moduleId,
              moduleName: module.moduleName,
              rowIndex: module.rowIndex,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Card(
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
                        if (value == module.isActive) {
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
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'View Details',
                      style: AppTheme.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 13,
                      color: theme.primaryColor,
                    ),
                  ],
                ),
              ]
            ],
          ),
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
  final String moduleType;
  final String status;
  final int rowIndex;
  final bool isActive;

  _ModuleAccessItem({
    required this.moduleId,
    required this.moduleName,
    required this.hasDashboard,
    required this.hasSettings,
    required this.tabs,
    required this.moduleFiles,
    required this.moduleType,
    required this.status,
    required this.rowIndex,
    this.isActive = true,
  });
}

class _ModuleSourceItem {
  final String moduleId;
  final String moduleName;
  final String dashboardId;
  final String settingsId;
  final String tabsId;
  final String moduleFilesId;
  final String moduleType;

  _ModuleSourceItem({
    required this.moduleId,
    required this.moduleName,
    required this.dashboardId,
    required this.settingsId,
    required this.tabsId,
    required this.moduleFilesId,
    required this.moduleType,
  });
}
