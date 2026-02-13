import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../../providers/drive_provider.dart';
import '../../providers/workspace_provider.dart';
import '../../models/schema_models.dart';
import 'module_access_detail_screen.dart';
import 'user_access_landing_tab.dart';

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

class _UserAccessManagementScreenState extends State<UserAccessManagementScreen> with TickerProviderStateMixin {
  List<_ModuleAccessItem> _modules = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSaving = false;
  final Map<String, bool> _accessChanges = {};
  bool _isAddingModules = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadUserAccess();
  }

  void _onTabChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
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
    await showDialog(
      context: context,
      builder: (context) => _AddModuleDialog(
        theme: theme,
        email: widget.email,
        spreadsheetId: widget.spreadsheetId,
        onModulesAdded: () {
          _loadUserAccess();
        },
        loadAvailableModules: _loadAvailableModules,
        currentModules: _modules,
      ),
    );
  }

  Future<void> _showRevokeAccessDialog(ThemeData theme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              'Revoke Access',
              style: AppTheme.inter(
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to revoke access for ${widget.email}?',
              style: AppTheme.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This will:',
              style: AppTheme.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 8),
            _buildRevokeActionItem('Delete user access spreadsheet', theme),
            _buildRevokeActionItem('Remove user from companies registry', theme),
            _buildRevokeActionItem('Remove all module access', theme),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone',
                      style: AppTheme.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTheme.inter(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Revoke Access',
              style: AppTheme.inter(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _revokeAccess(theme);
    }
  }

  Widget _buildRevokeActionItem(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: theme.textTheme.bodySmall?.color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTheme.inter(
                fontSize: 13,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _revokeAccess(ThemeData theme) async {
    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Revoking access...',
                style: AppTheme.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final driveProvider = Provider.of<DriveProvider>(context, listen: false);
      final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
      
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

      // Step 1: Get companies registry ID and sheet metadata
      final companiesRegistryId = await driveService.ensureCompanyRegistry(rootFolderId);

      // Get spreadsheet metadata to find the correct sheet ID for user_access
      final spreadsheetMetadata = await driveService.sheetsApi.spreadsheets.get(companiesRegistryId);
      int? userAccessSheetId;
      
      for (final sheet in spreadsheetMetadata.sheets ?? []) {
        if (sheet.properties?.title == 'user_access') {
          userAccessSheetId = sheet.properties?.sheetId;
          break;
        }
      }

      if (userAccessSheetId == null) {
        throw Exception('user_access sheet not found in companies registry');
      }

      // Step 2: Find the row to delete in companies registry
      final response = await driveService.sheetsApi.spreadsheets.values.get(
        companiesRegistryId,
        'user_access!A:C',
      );

      final values = response.values ?? [];
      int? rowIndexToDelete;

      for (int i = 1; i < values.length; i++) {
        final row = values[i];
        if (row.length >= 3) {
          final companyFolderId = row[0].toString();
          final email = row[1].toString();
          final spreadsheetId = row[2].toString();

          if (companyFolderId == currentWorkspaceId &&
              email == widget.email &&
              spreadsheetId == widget.spreadsheetId) {
            rowIndexToDelete = i; // 0-based index for the data (row i+1 in sheet)
            break;
          }
        }
      }

      // Step 3: Read user's modules to get config file IDs before deleting
      final Set<String> fileIdsToDelete = {widget.spreadsheetId};
      
      try {
        final userModulesResponse = await driveService.sheetsApi.spreadsheets.values.get(
          widget.spreadsheetId,
          'modules!A:H',
        );

        final moduleValues = userModulesResponse.values ?? [];
        // Skip header row and collect all file IDs from each module
        for (int i = 1; i < moduleValues.length; i++) {
          final row = moduleValues[i];
          if (row.length >= 6) {
            // Dashboard ID (column C, index 2)
            final dashboardId = row.length > 2 ? row[2].toString().trim() : '';
            if (dashboardId.isNotEmpty && dashboardId.toLowerCase() != 'true' && dashboardId.toLowerCase() != 'false') {
              fileIdsToDelete.add(dashboardId);
            }
            
            // Settings ID (column D, index 3)
            final settingsId = row.length > 3 ? row[3].toString().trim() : '';
            if (settingsId.isNotEmpty && settingsId.toLowerCase() != 'true' && settingsId.toLowerCase() != 'false') {
              fileIdsToDelete.add(settingsId);
            }
            
            // Tabs ID (column E, index 4)
            final tabsId = row.length > 4 ? row[4].toString().trim() : '';
            if (tabsId.isNotEmpty) {
              fileIdsToDelete.add(tabsId);
            }
            
          }
        }
      } catch (e) {
        debugPrint('Warning: Could not read user modules before deletion: $e');
        // Continue with deletion even if we can't read modules
      }

      // Step 4: Delete all collected files by ID
      for (final fileId in fileIdsToDelete) {
        try {
          await driveService.driveApi.files.delete(
            fileId,
            supportsAllDrives: true,
          );
          debugPrint('Deleted file: $fileId');
        } catch (e) {
          debugPrint('Warning: Could not delete file $fileId: $e');
        }
      }

      // Step 5: Delete the row from companies registry
      if (rowIndexToDelete != null) {
        await driveService.sheetsApi.spreadsheets.batchUpdate(
          sheets.BatchUpdateSpreadsheetRequest(
            requests: [
              sheets.Request(
                deleteDimension: sheets.DeleteDimensionRequest(
                  range: sheets.DimensionRange(
                    sheetId: userAccessSheetId,
                    dimension: 'ROWS',
                    startIndex: rowIndexToDelete + 1, // +1 to skip header
                    endIndex: rowIndexToDelete + 2,   // +2 to include the row
                  ),
                ),
              ),
            ],
          ),
          companiesRegistryId,
        );
      }

      if (!mounted) return;

      // Close progress dialog
      Navigator.pop(context);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Access revoked for ${widget.email}'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back to user control screen
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      // Close progress dialog
      Navigator.pop(context);

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error revoking access: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                labelColor: theme.primaryColor,
                unselectedLabelColor: theme.textTheme.bodyMedium?.color,
                indicatorColor: theme.primaryColor,
                tabs: const [
                  Tab(text: 'INVITATION'),
                  Tab(text: 'MODULES'),
                ],
              ),
              Divider(
                height: 0,
                color: theme.dividerColor.withValues(alpha: 0.1),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Landing Tab
          _buildLandingTab(theme),
          // Modules Tab
          _buildModulesTab(theme),
        ],
      ),
      bottomNavigationBar: _tabController.index == 1 ? SafeArea(
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
      ) : null,
    );
  }

  Widget _buildLandingTab(ThemeData theme) {
    return Column(
      children: [
        Expanded(
          child: UserAccessLandingTab(
            email: widget.email,
            invitationCode: widget.spreadsheetId,
            userName: null, // TODO: Load user name from Firebase auth or user registry
          ),
        ),
        SafeArea(
          minimum: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: () => _showRevokeAccessDialog(theme),
            icon: const Icon(Icons.remove_circle_outline),
            label: Text(
              'REVOKE ACCESS',
              style: AppTheme.inter(fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: Colors.red.withValues(alpha: 0.6)),
              foregroundColor: Colors.red,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModulesTab(ThemeData theme) {
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

class _AddModuleDialog extends StatefulWidget {
  final ThemeData theme;
  final String email;
  final String spreadsheetId;
  final VoidCallback onModulesAdded;
  final Future<List<_ModuleSourceItem>> Function() loadAvailableModules;
  final List<_ModuleAccessItem> currentModules;

  const _AddModuleDialog({
    required this.theme,
    required this.email,
    required this.spreadsheetId,
    required this.onModulesAdded,
    required this.loadAvailableModules,
    required this.currentModules,
  });

  @override
  State<_AddModuleDialog> createState() => _AddModuleDialogState();
}

class _AddModuleDialogState extends State<_AddModuleDialog> {
  late Future<List<_ModuleSourceItem>> _modulesFuture;
  final Set<String> _selectedModules = {};
  bool _isAdding = false;
  String _progressMessage = '';
  int _currentModuleIndex = 0;
  int _totalModules = 0;

  @override
  void initState() {
    super.initState();
    _modulesFuture = widget.loadAvailableModules();
  }

  Future<void> _addModules(List<_ModuleSourceItem> allModules) async {
    if (_selectedModules.isEmpty) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _isAdding = true;
      _progressMessage = 'Preparing modules...';
    });

    try {
      final driveProvider = Provider.of<DriveProvider>(context, listen: false);
      final driveService = driveProvider.driveService;
      if (driveService == null) {
        throw Exception('Drive service not available');
      }

      final toAdd = allModules.where((m) => _selectedModules.contains(m.moduleId)).toList();
      _totalModules = toAdd.length;

      for (int i = 0; i < toAdd.length; i++) {
        final module = toAdd[i];
        _currentModuleIndex = i + 1;

        // Step 1: Create config folder
        setState(() {
          _progressMessage = 'Creating folder for ${module.moduleName} ($_currentModuleIndex/$_totalModules)...';
        });
        final configFolderId = await driveService.getOrCreateSubFolder(
          module.moduleId,
          'config',
        );

        // Step 2: Read configurations
        setState(() {
          _progressMessage = 'Loading ${module.moduleName} configuration ($_currentModuleIndex/$_totalModules)...';
        });
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

        // Step 3: Create module config
        setState(() {
          _progressMessage = 'Setting up ${module.moduleName} ($_currentModuleIndex/$_totalModules)...';
        });
        final configIds = await driveService.createModuleConfig(
          configFolderId,
          widget.email,
          config,
        );

        // Step 4: Update user access
        setState(() {
          _progressMessage = 'Registering ${module.moduleName} ($_currentModuleIndex/$_totalModules)...';
        });
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

      if (!mounted) return;

      Navigator.pop(context);
      widget.onModulesAdded();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_totalModules} ${_totalModules == 1 ? 'module' : 'modules'} added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isAdding = false;
        _progressMessage = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding modules: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.add_circle_outline,
            color: widget.theme.primaryColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            'Add Modules',
            style: AppTheme.inter(
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select modules to grant access to ${widget.email}',
              style: AppTheme.inter(
                fontSize: 14,
                color: widget.theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: FutureBuilder<List<_ModuleSourceItem>>(
                future: _modulesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: widget.theme.disabledColor,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Failed to load modules',
                            style: AppTheme.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: widget.theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            snapshot.error.toString(),
                            style: AppTheme.inter(
                              fontSize: 12,
                              color: widget.theme.disabledColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  final modules = snapshot.data ?? [];
                  if (modules.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 48,
                            color: widget.theme.disabledColor,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No additional modules available',
                            style: AppTheme.inter(
                              fontSize: 14,
                              color: widget.theme.textTheme.bodyMedium?.color,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: modules.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final module = modules[index];
                      final isSelected = _selectedModules.contains(module.moduleId);
                      return CheckboxListTile(
                        value: isSelected,
                        enabled: !_isAdding,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedModules.add(module.moduleId);
                            } else {
                              _selectedModules.remove(module.moduleId);
                            }
                          });
                        },
                        title: Text(
                          module.moduleName.isNotEmpty ? module.moduleName : module.moduleId,
                          style: AppTheme.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _isAdding
                                ? widget.theme.textTheme.bodyMedium?.color?.withOpacity(0.5)
                                : widget.theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                        subtitle: module.moduleType.isNotEmpty
                            ? Text(
                                module.moduleType.toUpperCase(),
                                style: AppTheme.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: widget.theme.primaryColor.withOpacity(0.7),
                                ),
                              )
                            : null,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        activeColor: widget.theme.primaryColor,
                      );
                    },
                  );
                },
              ),
            ),
            if (_isAdding) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              widget.theme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            _progressMessage,
                            style: AppTheme.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: widget.theme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_totalModules > 0) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: _currentModuleIndex / _totalModules,
                        backgroundColor: widget.theme.primaryColor.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.theme.primaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isAdding ? null : () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: AppTheme.inter(
              fontWeight: FontWeight.w600,
              color: _isAdding
                  ? widget.theme.textTheme.bodyMedium?.color?.withOpacity(0.3)
                  : widget.theme.textTheme.bodyMedium?.color,
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _isAdding
              ? null
              : () async {
                  final modules = await _modulesFuture;
                  await _addModules(modules);
                },
          icon: _isAdding
              ? const SizedBox.shrink()
              : const Icon(Icons.add, size: 18),
          label: Text(
            _isAdding ? 'Adding...' : 'Add Modules',
            style: AppTheme.inter(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.theme.primaryColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: widget.theme.primaryColor.withOpacity(0.3),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}

