import 'package:flutter/material.dart';
import 'package:drivererpapp/theme/app_theme.dart';
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
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        if (settings.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Text(
                'No settings defined.',
                style: AppTheme.inter(color: theme.textTheme.bodyMedium?.color),
              ),
            ),
          ),
        
        ...settings.entries.map((entry) {
          final key = entry.key;
          final item = entry.value as Map<String, dynamic>;
          
          return _buildSettingRow(context, key, item);
        }),

        const SizedBox(height: 24),
        _buildAddButton(context),
      ],
    );
  }

  Widget _buildSettingRow(BuildContext context, String key, Map<String, dynamic> item) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardTheme.color ?? theme.cardColor,
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
                        style: AppTheme.inter(fontWeight: FontWeight.w600, color: theme.textTheme.titleMedium?.color),
                      ),
                      Text(
                        'Key: $key | Type: ${item['type']}',
                        style: AppTheme.sourceCodePro(fontSize: 10, color: theme.textTheme.bodyMedium?.color),
                      ),
                      if (item['dependsOn'] != null)
                        Text(
                          'Depends on: ${item['dependsOn']}',
                          style: AppTheme.inter(fontSize: 10, color: Colors.orange),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  color: theme.primaryColor,
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
            _buildValueInput(context, key, item),
          ],
        ),
      ),
    );
  }

  Widget _buildValueInput(BuildContext context, String key, Map<String, dynamic> item) {
    final theme = Theme.of(context);
    final type = item['type'] as String? ?? 'text';
    final textColor = theme.textTheme.bodyMedium?.color ?? theme.textTheme.bodyLarge?.color ?? Colors.black;
    final hintColor = theme.disabledColor;
    
    if (item['dependsOn'] != null) {
       final dependencyValue = widget.settingsValues[item['dependsOn']];
       if (dependencyValue != true) {
         return Text(
           'Disabled (Dependency not met)', 
           style: TextStyle(color: hintColor, fontStyle: FontStyle.italic)
         );
       }
    }

    switch (type) {
      case 'boolean':
        return SwitchListTile(
          title: Text('Value', style: TextStyle(color: textColor)),
          value: widget.settingsValues[key] == true,
          onChanged: (val) => widget.onSettingChanged(key, val),
          activeThumbColor: theme.primaryColor,
          contentPadding: EdgeInsets.zero,
          dense: true,
        );
      case 'text':
        return TextFormField(
          initialValue: widget.settingsValues[key]?.toString(),
          style: AppTheme.inter(color: textColor),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Enter value',
            hintStyle: TextStyle(color: hintColor),
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

  Widget _buildAddButton(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    
    return InkWell(
      onTap: _showAddSettingDialog,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3), style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: color, size: 24),
              const SizedBox(width: 8),
              Text('Add New Setting', style: AppTheme.inter(color: color, fontWeight: FontWeight.w600)),
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
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
        title: Text('Delete Setting', style: TextStyle(color: theme.textTheme.titleLarge?.color)),
        content: Text('Are you sure you want to delete "$key"?', style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
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
