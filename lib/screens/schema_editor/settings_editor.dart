import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'dialogs/edit_setting_dialog.dart';

class SettingsEditor extends StatefulWidget {
  final Map<String, dynamic>? rawSettings;
  final Map<String, dynamic> settingsValues;
  final Function(String key, dynamic value) onSettingChanged;
  final Function(Map<String, dynamic> newSchema) onSchemaChanged;

  const SettingsEditor({
    super.key,
    required this.rawSettings,
    required this.settingsValues,
    required this.onSettingChanged,
    required this.onSchemaChanged,
  });

  @override
  State<SettingsEditor> createState() => _SettingsEditorState();
}

class _SettingsEditorState extends State<SettingsEditor> {
  @override
  Widget build(BuildContext context) {
    final settings = widget.rawSettings ?? {};

    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        if (settings.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Text(
                'No settings defined.',
                style: GoogleFonts.inter(color: AppTheme.secondaryTextColor),
              ),
            ),
          ),
        
        ...settings.entries.map((entry) {
          final key = entry.key;
          final item = entry.value as Map<String, dynamic>;
          
          return _buildSettingRow(key, item);
        }),

        const SizedBox(height: 24),
        _buildAddButton(),
      ],
    );
  }

  Widget _buildSettingRow(String key, Map<String, dynamic> item) {
    return Card(
      color: AppTheme.surfaceColor,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['label'] ?? key,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppTheme.textColor),
                      ),
                      Text(
                        'Key: $key | Type: ${item['type']}',
                        style: GoogleFonts.sourceCodePro(fontSize: 10, color: AppTheme.secondaryTextColor),
                      ),
                      if (item['dependsOn'] != null)
                        Text(
                          'Depends on: ${item['dependsOn']}',
                          style: GoogleFonts.inter(fontSize: 10, color: Colors.orange),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  color: AppTheme.primaryColor,
                  onPressed: () => _showEditSettingDialog(key, item),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: Colors.red,
                  onPressed: () => _confirmDeleteSetting(key),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildValueInput(key, item),
          ],
        ),
      ),
    );
  }

  Widget _buildValueInput(String key, Map<String, dynamic> item) {
    final type = item['type'] as String? ?? 'text';
    
    if (item['dependsOn'] != null) {
       final dependencyValue = widget.settingsValues[item['dependsOn']];
       if (dependencyValue != true) {
         return Text(
           'Disabled (Dependency not met)', 
           style: TextStyle(color: AppTheme.secondaryTextColor.withOpacity(0.5), fontStyle: FontStyle.italic)
         );
       }
    }

    switch (type) {
      case 'boolean':
        return SwitchListTile(
          title: Text('Value', style: TextStyle(color: AppTheme.secondaryTextColor)),
          value: widget.settingsValues[key] == true,
          onChanged: (val) => widget.onSettingChanged(key, val),
          activeColor: AppTheme.primaryColor,
          contentPadding: EdgeInsets.zero,
          dense: true,
        );
      case 'text':
        return TextFormField(
          initialValue: widget.settingsValues[key]?.toString(),
          style: GoogleFonts.inter(color: AppTheme.textColor),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Enter value',
            hintStyle: TextStyle(color: AppTheme.secondaryTextColor.withOpacity(0.5)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: (val) => widget.onSettingChanged(key, val),
        );
      case 'list':
        List<String> currentList = (widget.settingsValues[key] as List?)?.cast<String>() ?? [];
        return Wrap(
          spacing: 8,
          children: [
            ...currentList.map((e) => Chip(
              label: Text(e),
              onDeleted: () {
                final newList = List<String>.from(currentList)..remove(e);
                widget.onSettingChanged(key, newList);
              },
            )),
            ActionChip(
              label: const Icon(Icons.add, size: 16),
              onPressed: () => _showAddListItemDialog(key, currentList),
            ),
          ],
        );
      default:
        return Text('Unsupported type: $type', style: const TextStyle(color: Colors.red));
    }
  }

  Widget _buildAddButton() {
    return InkWell(
      onTap: _showAddSettingDialog,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.secondaryTextColor.withOpacity(0.3), style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: AppTheme.secondaryTextColor, size: 24),
              const SizedBox(width: 8),
              Text('Add New Setting', style: GoogleFonts.inter(color: AppTheme.secondaryTextColor, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddSettingDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditSettingDialog(
        existingKeys: widget.rawSettings?.keys.toList() ?? [],
      ),
    );

    if (result != null) {
      final key = result['key'];
      final data = result['data'];
      
      final newSchema = Map<String, dynamic>.from(widget.rawSettings ?? {});
      newSchema[key] = data;
      
      widget.onSchemaChanged(newSchema);
    }
  }

  Future<void> _showEditSettingDialog(String oldKey, Map<String, dynamic> item) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditSettingDialog(
        settingKey: oldKey,
        settingData: item,
        existingKeys: widget.rawSettings?.keys.toList() ?? [],
      ),
    );

    if (result != null) {
      final newKey = result['key'];
      final data = result['data'];
      
      final newSchema = Map<String, dynamic>.from(widget.rawSettings ?? {});
      
      if (newKey != oldKey) {
        newSchema.remove(oldKey);
        // Note: Value migration for renamed keys would need to happen in parent
      }
      
      newSchema[newKey] = data;
      
      widget.onSchemaChanged(newSchema);
    }
  }

  void _confirmDeleteSetting(String key) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text('Delete Setting', style: TextStyle(color: AppTheme.textColor)),
        content: Text('Are you sure you want to delete "$key"?', style: TextStyle(color: AppTheme.secondaryTextColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final newSchema = Map<String, dynamic>.from(widget.rawSettings ?? {});
              newSchema.remove(key);
              widget.onSchemaChanged(newSchema);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
                final newList = List<String>.from(currentList)..add(newValue);
                widget.onSettingChanged(key, newList);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
