import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/schema_models.dart';
import '../theme/app_theme.dart';
import 'schema_editor/structure_editor.dart';
import 'schema_editor/dashboard_editor.dart';
import 'schema_editor/settings_editor.dart';
import 'schema_editor/dialogs/edit_kpi_dialog.dart';

class SchemaEditorScreen extends StatefulWidget {
  final ModuleSchema module;

  const SchemaEditorScreen({super.key, required this.module});

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
  bool _isLoadingSettings = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Deep copy for editing (simplified)
    _tabs = List.from(widget.module.tabs); 
    _kpis = List.from(widget.module.dashboard.kpiCards);
    
    _settingsValues = {};
    _loadSettingsFromFile();
  }

  Future<void> _loadSettingsFromFile() async {
    try {
      final fileName = widget.module.name.toLowerCase();
      final jsonString = await rootBundle.loadString('assets/erp_modules/$fileName.json');
      final jsonMap = jsonDecode(jsonString);
      
      if (mounted) {
        setState(() {
          _rawSettings = jsonMap['settings'];
          _isLoadingSettings = false;
          
          // Initialize values from raw JSON
          if (_rawSettings != null) {
            _rawSettings!.forEach((key, value) {
               _settingsValues[key] = value['value'];
            });
          }
        });
      }
    } catch (e) {
      print('Error loading settings: $e');
      if (mounted) {
        setState(() {
          _isLoadingSettings = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('BLUEPRINT EDITOR', style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 1.0)),
        centerTitle: true,
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.secondaryTextColor,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'STRUCTURE'),
            Tab(text: 'DASHBOARD'),
            Tab(text: 'SETTINGS'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _saveChanges,
            child: Text('SAVE', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppTheme.primaryColor)),
          ),
        ],
      ),
      body: _isLoadingSettings 
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
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

  void _saveChanges() {
    // In a real app, this would serialize the state back to JSON and upload to Drive
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Blueprint updated. Syncing to Drive...')),
    );
    Navigator.pop(context);
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
