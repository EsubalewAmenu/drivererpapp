import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/schema_models.dart';
import '../providers/drive_provider.dart';
import '../theme/app_theme.dart';
import 'schema_editor/structure_editor.dart';
import 'schema_editor/dashboard_editor.dart';
import 'schema_editor/settings_editor.dart';
import 'schema_editor/dialogs/edit_kpi_dialog.dart';

class SchemaEditorScreen extends StatefulWidget {
  final ModuleSchema module;
  final bool isNewSetup;

  const SchemaEditorScreen({
    super.key, 
    required this.module,
    this.isNewSetup = false,
  });

  @override
  State<SchemaEditorScreen> createState() => _SchemaEditorScreenState();
}

class _SchemaEditorScreenState extends State<SchemaEditorScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Editable State
  late List<TabConfig> _tabs;
  late List<KpiCard> _kpis;
  late Map<String, dynamic> _settingsValues;
  
  Map<String, dynamic>? _rawSettings;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Deep copy for editing
    _tabs = List.from(widget.module.tabs); 
    _kpis = List.from(widget.module.dashboard.kpiCards);
    
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.isNewSetup ? 'COMPLETE SETUP' : 'BLUEPRINT EDITOR', 
          style: AppTheme.inter(fontWeight: FontWeight.w900, letterSpacing: 1.0)
        ),
        centerTitle: true,
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.secondaryTextColor,
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
            kpis: _kpis,
            onAddKpi: () {
              _showAddKpiDialog();
            },
            onDeleteKpi: (index) {
              setState(() {
                _kpis.removeAt(index);
              });
            },
            onEditKpi: (index, kpi) {
              _showEditKpiDialog(index, kpi);
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
    );
  }

  Future<void> _saveChanges() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // 1. Construct the JSON object
      final Map<String, dynamic> jsonMap = {
        // Core properties are now in settings
        'settings': _rawSettings, // This now contains the updated values
        'dashboard': {
          'kpiCards': _kpis.map((k) => k.toJson()).toList(),
        },
        'tabs': _tabs.map((t) => t.toJson()).toList(),
      };

      // 2. Save to Drive
      final driveService = Provider.of<DriveProvider>(context, listen: false).driveService;
      if (driveService == null) throw Exception("Not authenticated");

      // Check if config exists
      final existingFileId = await driveService.getFileId(widget.module.id, 'config');

      if (existingFileId != null) {
        debugPrint('Updating existing config sheet ($existingFileId)...');
        await driveService.updateModuleConfig(existingFileId, jsonMap);
      } else {
        debugPrint('Creating new config sheet in ${widget.module.id}...');
        await driveService.createModuleConfig(widget.module.id, 'config', jsonMap);
      }

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

  Future<void> _showAddKpiDialog() async {
    final newKpi = await showDialog<KpiCard>(
      context: context,
      builder: (context) => const EditKpiDialog(),
    );

    if (newKpi != null) {
      setState(() {
        _kpis.add(newKpi);
      });
    }
  }

  Future<void> _showEditKpiDialog(int index, KpiCard kpi) async {
    final updatedKpi = await showDialog<KpiCard>(
      context: context,
      builder: (context) => EditKpiDialog(kpi: kpi),
    );

    if (updatedKpi != null) {
      setState(() {
        _kpis[index] = updatedKpi;
      });
    }
  }
}
