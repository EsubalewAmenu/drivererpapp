import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/schema_models.dart';
import '../theme/app_theme.dart';

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
  late TextEditingController _moduleNameController;
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
    _moduleNameController = TextEditingController(text: widget.module.name);
    
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
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStructureEditor(),
          _buildDashboardEditor(),
          _buildSettingsEditor(),
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

  // --- Structure Editor ---

  Widget _buildStructureEditor() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tabs.length + 1,
      itemBuilder: (context, index) {
        if (index == _tabs.length) {
          return _buildAddButton('Add New Tab', () {
            // TODO: Add tab logic
          });
        }
        return _buildTabEditorCard(_tabs[index]);
      },
    );
  }

  Widget _buildTabEditorCard(TabConfig tab) {
    return Card(
      color: AppTheme.surfaceColor,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        title: Text(tab.label, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppTheme.textColor)),
        subtitle: Text('${tab.columns.length} Columns', style: GoogleFonts.inter(color: AppTheme.secondaryTextColor)),
        iconColor: AppTheme.primaryColor,
        collapsedIconColor: AppTheme.secondaryTextColor,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ...tab.columns.map((col) => _buildColumnRow(col)),
                const SizedBox(height: 16),
                _buildAddButton('Add Column', () {
                  // TODO: Add column logic
                }, isSmall: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnRow(ColumnConfig col) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(_getIconForType(col.type), size: 16, color: AppTheme.secondaryTextColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(col.label, style: GoogleFonts.inter(color: AppTheme.textColor)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.secondaryTextColor.withOpacity(0.3)),
            ),
            child: Text(col.type.toUpperCase(), style: GoogleFonts.sourceCodePro(fontSize: 10, color: AppTheme.secondaryTextColor)),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 16),
            color: AppTheme.primaryColor,
            onPressed: () {
              _showEditColumnDialog(col);
            },
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'text': return Icons.text_fields;
      case 'number': return Icons.numbers;
      case 'date': return Icons.calendar_today;
      case 'select': return Icons.list;
      case 'formula': return Icons.functions;
      default: return Icons.short_text;
    }
  }

  void _showEditColumnDialog(ColumnConfig col) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text('Edit Column', style: GoogleFonts.inter(color: AppTheme.textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: TextEditingController(text: col.label),
              style: TextStyle(color: AppTheme.textColor),
              decoration: const InputDecoration(labelText: 'Column Name'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: col.type,
              dropdownColor: AppTheme.surfaceColor,
              style: TextStyle(color: AppTheme.textColor),
              items: ['text', 'number', 'date', 'select', 'formula', 'scanner', 'image', 'signature']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase())))
                  .toList(),
              onChanged: (val) {},
              decoration: const InputDecoration(labelText: 'Data Type'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Save')),
        ],
      ),
    );
  }

  // --- Dashboard Editor ---

  Widget _buildDashboardEditor() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _kpis.length + 1,
      itemBuilder: (context, index) {
        if (index == _kpis.length) {
          return _buildAddButton('Add KPI Card', () {});
        }
        return _buildKpiEditorCard(_kpis[index]);
      },
    );
  }

  Widget _buildKpiEditorCard(KpiCard kpi) {
    return Card(
      color: AppTheme.surfaceColor,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(kpi.label, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppTheme.textColor)),
                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () {}),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.functions, size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      kpi.calculation,
                      style: GoogleFonts.sourceCodePro(color: AppTheme.textColor),
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

  // --- Settings Editor ---

  Widget _buildSettingsEditor() {
    if (_isLoadingSettings) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_rawSettings == null) {
      return Center(
        child: Text(
          'No settings found in JSON file.',
          style: GoogleFonts.inter(color: AppTheme.secondaryTextColor),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        ..._rawSettings!.entries.map((entry) {
          final key = entry.key;
          final item = entry.value as Map<String, dynamic>;
          
          if (item['dependsOn'] != null) {
             final dependencyValue = _settingsValues[item['dependsOn']];
             if (dependencyValue != true) return const SizedBox.shrink();
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: _buildSettingField(key, item),
          );
        }),
      ],
    );
  }

  Widget _buildSettingField(String key, Map<String, dynamic> item) {
    final label = item['label'] as String? ?? key;
    final type = item['type'] as String? ?? 'text';

    switch (type) {
      case 'boolean':
        return SwitchListTile(
          title: Text(label, style: GoogleFonts.inter(color: AppTheme.textColor)),
          value: _settingsValues[key] == true,
          onChanged: (val) {
            setState(() {
              _settingsValues[key] = val;
            });
          },
          activeColor: AppTheme.primaryColor,
          contentPadding: EdgeInsets.zero,
        );
      case 'text':
        return TextFormField(
          initialValue: _settingsValues[key]?.toString(),
          style: GoogleFonts.inter(color: AppTheme.textColor),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: AppTheme.secondaryTextColor),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.secondaryTextColor)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor)),
          ),
          onChanged: (val) {
            _settingsValues[key] = val;
          },
        );
      case 'list':
        List<String> currentList = (_settingsValues[key] as List?)?.cast<String>() ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(color: AppTheme.secondaryTextColor, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ...currentList.map((e) => Chip(
                  label: Text(e),
                  onDeleted: () {
                    setState(() {
                      currentList.remove(e);
                      _settingsValues[key] = currentList;
                    });
                  },
                )),
                ActionChip(
                  label: const Icon(Icons.add, size: 16),
                  onPressed: () {
                    _showAddListItemDialog(key, currentList);
                  },
                ),
              ],
            ),
          ],
        );
      default:
        return Text('Unsupported type: $type', style: const TextStyle(color: Colors.red));
    }
  }

  void _showAddListItemDialog(String key, List<String> currentList) {
    String newValue = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add to $key'),
        content: TextField(
          autofocus: true,
          onChanged: (val) => newValue = val,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (newValue.isNotEmpty) {
                setState(() {
                  currentList.add(newValue);
                  _settingsValues[key] = currentList;
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(String label, VoidCallback onTap, {bool isSmall = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: isSmall ? 12 : 16),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.secondaryTextColor.withOpacity(0.3), style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: AppTheme.secondaryTextColor, size: isSmall ? 16 : 24),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.inter(color: AppTheme.secondaryTextColor, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
