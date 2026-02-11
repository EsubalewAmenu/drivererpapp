import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../models/schema_models.dart';
import '../providers/drive_provider.dart';
import '../providers/schema_provider.dart';
import '../providers/workspace_provider.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import '../services/auth_service.dart';
import 'schema_editor/structure_editor.dart';
import 'schema_editor/dashboard_editor.dart';
import 'schema_editor/settings_editor.dart';
import 'schema_editor/dashboard_card_selection_screen.dart';
import 'schema_editor/dashboard_card_edit_screen.dart';

class SchemaEditorScreen extends StatefulWidget {
  final ModuleSchema module;
  final String? settingsSheetId;
  final String? dashboardSheetId;
  final String? tabsSheetId;

  const SchemaEditorScreen({
    super.key,
    required this.module,
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
          'BLUEPRINT EDITOR', 
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
                'SAVE', 
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
            onDeactivate: _deactivateModule,
            onTerminate: _terminateModule,
          ),
        ],
      ),
      bottomNavigationBar: null,
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

      final uaFileId = workspaceProvider.lastUserAccessSpreadsheetId;
      if (uaFileId != null) {
        await driveService.setUserAccessModuleStatus(uaFileId, widget.module.id, 'deactivated');
      }

      // Refresh workspace provider to force dashboards/lists to reload
      if (workspaceProvider.currentWorkspace != null) workspaceProvider.setWorkspace(workspaceProvider.currentWorkspace!);

      if (mounted) {
        // Return to root Dashboard and refresh by replacing with a fresh screen
        Navigator.popUntil(context, (r) => r.isFirst);
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
      }
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
        final uaFileId = workspaceProvider.lastUserAccessSpreadsheetId;
        if (uaFileId != null) {
          await driveService.removeUserAccessModule(uaFileId, widget.module.id);
        }
      }

      // Clear any cached configs and in-memory entries for this module
      try {
        final schemaProvider = Provider.of<SchemaProvider>(context, listen: false);
        try {
          await schemaProvider.service.removeCachedConfig(widget.module.id);
        } catch (_) {}
        try {
          schemaProvider.updateMemoryCache(widget.module.id, null);
        } catch (_) {}
      } catch (e) {
        debugPrint('Error clearing schema cache after termination: $e');
      }

      // Refresh workspace provider so Dashboard reflects removed module
      if (workspaceProvider.currentWorkspace != null) workspaceProvider.setWorkspace(workspaceProvider.currentWorkspace!);

      if (mounted) {
        Navigator.popUntil(context, (r) => r.isFirst);
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
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

      // Original values for comparison using JSON for accuracy
      final origSettingsJson = jsonEncode(widget.module.settings.map((k, v) => MapEntry(k, v.toJson())));
      final newSettingsJson = jsonEncode(moduleSettings.map((k, v) => MapEntry(k, v.toJson())));
      final settingsChanged = origSettingsJson != newSettingsJson;

      final origDashboardJson = jsonEncode(widget.module.dashboard.cards.map((c) => c.toJson()).toList());
      final newDashboardJson = jsonEncode(_cards.map((c) => c.toJson()).toList());
      final dashboardChanged = origDashboardJson != newDashboardJson;

      final origTabsJson = jsonEncode(widget.module.tabs.map((t) => t.toJson()).toList());
      final newTabsJson = jsonEncode(_tabs.map((t) => t.toJson()).toList());
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
        // Granular Update for settings
        final Map<String, dynamic> changedSettings = {};
        final newSettingsMap = moduleSettings.map((k, v) => MapEntry(k, v.toJson()));
        final origSettingsMap = widget.module.settings.map((k, v) => MapEntry(k, v.toJson()));
        
        newSettingsMap.forEach((key, value) {
          if (jsonEncode(value) != jsonEncode(origSettingsMap[key])) {
            changedSettings[key] = value;
          }
        });

        if (changedSettings.isNotEmpty) {
          debugPrint('SchemaEditor: Updating changed settings fields: ${changedSettings.keys.toList()}');
          await schemaProvider.service.saveSettingFields(widget.module.id, changedSettings, settingsId: widget.settingsSheetId);
        }

        final settingsModified = await schemaProvider.service.driveService?.getFileModifiedTime(widget.settingsSheetId!);
        await schemaProvider.service.cacheConfig(
          widget.module.id, 
          {'settings': newSettingsMap}, 
          fileId: widget.settingsSheetId, 
          modifiedTime: settingsModified?.toIso8601String()
        );
      }

      if (dashboardChanged) {
        // Dashboards are usually a list of cards; clear and rewrite the whole cards sheet for now
        await schemaProvider.service.saveDashboardPart(widget.module.id, {'cards': _cards.map((c) => c.toJson()).toList()}, settingsId: widget.settingsSheetId, dashboardId: widget.dashboardSheetId);
      }

      if (tabsChanged) {
        // Granular Update: Only update changed fields in changed tabs to avoid re-writing everything
        for (final newTab in _tabs) {
          final newTabJson = newTab.toJson();
          
          // Find original tab
          final origTab = widget.module.tabs.firstWhere(
            (t) => t.id == newTab.id,
            orElse: () => TabConfig(id: '', label: '', columns: []),
          );

          if (origTab.id.isEmpty) {
            // New tab added - write the whole sheet
            debugPrint('SchemaEditor: Writing new tab sheet for ${newTab.id}');
            await schemaProvider.service.saveTabsPart(widget.module.id, [newTabJson], settingsId: widget.settingsSheetId, tabsId: widget.tabsSheetId);
          } else {
            // Existing tab - find changed fields
            final origTabJson = origTab.toJson();
            final Map<String, dynamic> changedFields = {};
            
            newTabJson.forEach((key, value) {
              if (jsonEncode(value) != jsonEncode(origTabJson[key])) {
                changedFields[key] = value;
              }
            });

            if (changedFields.isNotEmpty) {
              debugPrint('SchemaEditor: Updating changed fields for tab ${newTab.id}: ${changedFields.keys.toList()}');
              await schemaProvider.service.saveTabFields(
                widget.module.id, 
                newTab.id, 
                changedFields, 
                settingsId: widget.settingsSheetId, 
                tabsId: widget.tabsSheetId
              );
            }
          }
        }
        
        // Also handle deleted tabs?
        // For now, we update cache to ensure local state reflects the full tabs list including any deletions
        final tabsModified = await schemaProvider.service.driveService?.getFileModifiedTime(widget.tabsSheetId!);
        await schemaProvider.service.cacheConfig(
          widget.module.id, 
          {'tabs': _tabs.map((t) => t.toJson()).toList()}, 
          fileId: widget.settingsSheetId, 
          modifiedTime: tabsModified?.toIso8601String()
        );
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
