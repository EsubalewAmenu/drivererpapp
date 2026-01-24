import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/schema_models.dart';
import '../providers/drive_provider.dart';
import '../providers/schema_provider.dart';
import '../providers/workspace_provider.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'schema_editor/structure_editor.dart';
import 'schema_editor/dashboard_editor.dart';
import 'schema_editor/settings_editor.dart';
import 'schema_editor/dashboard_card_selection_screen.dart';
import 'schema_editor/dashboard_card_edit_screen.dart';

class SchemaEditorScreen extends StatefulWidget {
  final ModuleSchema module;
  final bool isNewSetup;
  final String? settingsSheetId;
  final String? dashboardSheetId;
  final String? tabsSheetId;

  const SchemaEditorScreen({
    super.key,
    required this.module,
    this.isNewSetup = false,
    this.settingsSheetId,
    this.dashboardSheetId,
    this.tabsSheetId,
  });

  @override
  State<SchemaEditorScreen> createState() => _SchemaEditorScreenState();
}

class _SchemaEditorScreenState extends State<SchemaEditorScreen> with SingleTickerProviderStateMixin {

  late TabController _tabController;
  
  // Editable State
  late List<TabConfig> _tabs;
  late List<DashboardCard> _cards;
  late Map<String, dynamic> _settingsValues;
  
  Map<String, dynamic>? _rawSettings;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Deep copy for editing
    _tabs = List.from(widget.module.tabs); 
    _cards = List.from(widget.module.dashboard.cards);
    
    _settingsValues = {};
    _rawSettings = {};
    
    // Initialize settings from the passed module
    widget.module.settings.forEach((key, item) {
      // Use value if present, otherwise default
      _settingsValues[key] = item.value ?? item.defaultValue;
      
      // Reconstruct raw settings map for the editor
      // We need to ensure the 'value' in the raw map reflects the current value
      var itemJson = item.toJson();
      itemJson['value'] = _settingsValues[key];
      _rawSettings![key] = itemJson;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.isNewSetup ? 'COMPLETE SETUP' : 'BLUEPRINT EDITOR', 
          style: AppTheme.inter(
            fontWeight: FontWeight.w900, 
            letterSpacing: 1.0,
            color: theme.appBarTheme.titleTextStyle?.color,
          ),
        ),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: theme.disabledColor,
          labelStyle: AppTheme.inter(fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'STRUCTURE'),
            Tab(text: 'DASHBOARD'),
            Tab(text: 'SETTINGS'),
          ],
        ),
        actions: [
          if (_isSaving)
            const Center(child: Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ))
          else
            TextButton(
              onPressed: _saveChanges,
              child: Text(
                widget.isNewSetup ? 'ACTIVATE' : 'SAVE', 
                style: AppTheme.inter(fontWeight: FontWeight.w700, color: AppTheme.primaryColor)
              ),
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          StructureEditor(
            tabs: _tabs,
            rawSettings: _rawSettings,
            onTabsChanged: (newTabs) {
              setState(() {
                _tabs = newTabs;
              });
            },
          ),
          DashboardEditor(
            cards: _cards,
            onAddCard: () {
              _showAddCardDialog();
            },
            onDeleteCard: (index) {
              setState(() {
                _cards.removeAt(index);
              });
            },
            onEditCard: (index, card) {
              _showEditCardDialog(index, card);
            },
          ),
          SettingsEditor(
            rawSettings: _rawSettings,
            settingsValues: _settingsValues,
            onSettingChanged: (key, value) {
              setState(() {
                _settingsValues[key] = value;
                // Also update the raw settings value so it persists in the map
                if (_rawSettings != null && _rawSettings![key] != null) {
                  _rawSettings![key]['value'] = value;
                }
              });
            },
            onSchemaChanged: (newSchema) {
              setState(() {
                _rawSettings = newSchema;
              });
            },
          ),
        ],
      ),
      bottomNavigationBar: widget.isNewSetup ? null : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _deactivateModule,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.orange.shade700),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('DEACTIVATE', style: AppTheme.inter(fontWeight: FontWeight.w700, color: Colors.orange.shade700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _terminateModule,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.red.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('TERMINATE', style: AppTheme.inter(fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deactivateModule() async {
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Deactivate Module'),
      content: const Text('Deactivating will prevent users from opening this module. Data will not be deleted. Continue?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('DEACTIVATE')),
      ],
    ));
    if (confirm != true) return;

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final userEmail = auth.currentUser?.email;
      final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
      final workspaceId = workspaceProvider.currentWorkspace?.id;
      final driveProvider = Provider.of<DriveProvider>(context, listen: false);
      final driveService = driveProvider.driveService!;

      if (userEmail == null || workspaceId == null) throw Exception('Missing user or workspace');

      final uaFolderId = await driveService.ensureUserAccessFolder(workspaceId);
      final uaFileId = await driveService.ensureUserAccessSpreadsheet(uaFolderId, userEmail);

      await driveService.setUserAccessModuleStatus(uaFileId, widget.module.id, 'deactivated');

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Module deactivated')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to deactivate: $e')));
    }
  }

  Future<void> _terminateModule() async {
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Terminate Module'),
      content: const Text('Terminating will delete the module folder and remove access for users. This is irreversible. Continue?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('TERMINATE')),
      ],
    ));
    if (confirm != true) return;

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final userEmail = auth.currentUser?.email;
      final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
      final workspaceId = workspaceProvider.currentWorkspace?.id;
      final driveProvider = Provider.of<DriveProvider>(context, listen: false);
      final driveService = driveProvider.driveService!;

      if (workspaceId == null) throw Exception('Missing workspace');

      // Delete module folder (widget.module.id assumed to be folder id for installed modules)
      await driveService.deleteFile(widget.module.id);

      if (userEmail != null) {
        final uaFolderId = await driveService.ensureUserAccessFolder(workspaceId);
        final uaFileId = await driveService.ensureUserAccessSpreadsheet(uaFolderId, userEmail);
        await driveService.removeUserAccessModule(uaFileId, widget.module.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Module terminated')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to terminate: $e')));
    }
  }

  Future<void> _saveChanges() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final moduleSettings = _rawSettings?.map((key, value) {
        return MapEntry(key, SettingItem.fromJson(value as Map<String, dynamic>));
      }) ?? {};

      // 1. Determine which parts changed and save each part independently
      final schemaProvider = Provider.of<SchemaProvider>(context, listen: false);

      // Original values for comparison
      String origSettingsJson = '{}';
      try {
        final origMap = widget.module.settings.map((k, v) => MapEntry(k, v.toJson()));
        origSettingsJson = origMap.isNotEmpty ? origMap.toString() : '{}';
      } catch (_) {}

      String newSettingsJson = '{}';
      try {
        final newMap = moduleSettings.map((k, v) => MapEntry(k, v.toJson()));
        newSettingsJson = newMap.isNotEmpty ? newMap.toString() : '{}';
      } catch (_) {}

      final settingsChanged = origSettingsJson != newSettingsJson;

      final origDashboardJson = widget.module.dashboard.cards.map((c) => c.toJson()).toList().toString();
      final newDashboardJson = _cards.map((c) => c.toJson()).toList().toString();
      final dashboardChanged = origDashboardJson != newDashboardJson;

      final origTabsJson = widget.module.tabs.map((t) => t.toJson()).toList().toString();
      final newTabsJson = _tabs.map((t) => t.toJson()).toList().toString();
      final tabsChanged = origTabsJson != newTabsJson;

      // Require explicit per-sheet ids; show error and abort if any id missing
      if (widget.settingsSheetId == null || widget.dashboardSheetId == null || widget.tabsSheetId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Missing spreadsheet id(s). Cannot save without sheet ids.')),
          );
        }
        return;
      }
        // Execute saves for changed parts (only write parts when explicit ids provided)
        if (settingsChanged) {
          await schemaProvider.service.saveSettingsPart(widget.module.id, moduleSettings.map((k, v) => MapEntry(k, v.toJson())), settingsId: widget.settingsSheetId);
        }

        if (dashboardChanged) {
          await schemaProvider.service.saveDashboardPart(widget.module.id, {'cards': _cards.map((c) => c.toJson()).toList()}, settingsId: widget.settingsSheetId, dashboardId: widget.dashboardSheetId);
        }

        if (tabsChanged) {
          await schemaProvider.service.saveTabsPart(widget.module.id, _tabs.map((t) => t.toJson()).toList(), settingsId: widget.settingsSheetId, tabsId: widget.tabsSheetId);
        }

        // Update memory cache with the merged updated schema
        final updatedSchema = ModuleSchema(
          id: widget.module.id,
          name: _settingsValues['name'] ?? widget.module.name,
          icon: _settingsValues['icon'] ?? widget.module.icon,
          primaryColor: _settingsValues['primaryColor'] ?? widget.module.primaryColor,
          version: _settingsValues['version'] ?? widget.module.version,
          settings: moduleSettings,
          dashboard: DashboardConfig(cards: _cards),
          tabs: _tabs,
        );

        schemaProvider.updateMemoryCache(widget.module.id, updatedSchema);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuration saved successfully.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving configuration: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving configuration: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _showAddCardDialog() async {
    final template = await Navigator.push<DashboardCard>(
      context,
      MaterialPageRoute(builder: (context) => const DashboardCardSelectionScreen()),
    );

    if (template == null) return;

    if (!mounted) return;
    // Chain directly to the Edit/Configuration Screen
    final configuredCard = await Navigator.push<DashboardCard>(
      context,
      MaterialPageRoute(builder: (context) => DashboardCardEditScreen(
        card: template,
        module: widget.module,
        index: -1,
      )),
    );

    if (configuredCard != null) {
      setState(() {
        _cards.add(configuredCard);
      });
    }
  }

  Future<void> _showEditCardDialog(int index, DashboardCard card) async {
    final updatedCard = await Navigator.push<DashboardCard>(
      context,
      MaterialPageRoute(builder: (context) => DashboardCardEditScreen(
        card: card,
        module: widget.module,
        index: index,
      )),
    );

    if (updatedCard != null) {
      setState(() {
        _cards[index] = updatedCard;
      });
    }
  }
}
