import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/schema_models.dart';
import '../providers/drive_provider.dart';
import '../providers/schema_provider.dart';
import '../theme/app_theme.dart';
import 'schema_editor/structure_editor.dart';
import 'schema_editor/dashboard_editor.dart';
import 'schema_editor/settings_editor.dart';
import 'schema_editor/dialogs/edit_card_dialog.dart';
import 'schema_editor/dashboard_card_selection_screen.dart';

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
    );
  }

  Future<void> _saveChanges() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final moduleSettings = _rawSettings?.map((key, value) {
        return MapEntry(key, SettingItem.fromJson(value as Map<String, dynamic>));
      }) ?? {};

      // 1. Construct schema object
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

      // 2. Save via SchemaService
      final schemaProvider = Provider.of<SchemaProvider>(context, listen: false);
      await schemaProvider.service.saveModuleConfig(widget.module.id, updatedSchema);

      // 3. Update memory cache
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
    final newCard = await Navigator.push<DashboardCard>(
      context,
      MaterialPageRoute(builder: (context) => const DashboardCardSelectionScreen()),
    );

    if (newCard != null) {
      setState(() {
        _cards.add(newCard);
      });
    }
  }

  Future<void> _showEditCardDialog(int index, DashboardCard card) async {
    final updatedCard = await showDialog<DashboardCard>(
      context: context,
      builder: (context) => EditCardDialog(card: card),
    );

    if (updatedCard != null) {
      setState(() {
        _cards[index] = updatedCard;
      });
    }
  }
}
