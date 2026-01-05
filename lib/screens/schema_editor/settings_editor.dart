import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class SettingsEditor extends StatefulWidget {
  final Map<String, dynamic>? rawSettings;
  final Map<String, dynamic> settingsValues;
  final Function(String key, dynamic value) onSettingChanged;

  const SettingsEditor({
    super.key,
    required this.rawSettings,
    required this.settingsValues,
    required this.onSettingChanged,
  });

  @override
  State<SettingsEditor> createState() => _SettingsEditorState();
}

class _SettingsEditorState extends State<SettingsEditor> {
  @override
  Widget build(BuildContext context) {
    if (widget.rawSettings == null) {
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
        ...widget.rawSettings!.entries.map((entry) {
          final key = entry.key;
          final item = entry.value as Map<String, dynamic>;
          
          if (item['dependsOn'] != null) {
             final dependencyValue = widget.settingsValues[item['dependsOn']];
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
          value: widget.settingsValues[key] == true,
          onChanged: (val) {
            widget.onSettingChanged(key, val);
          },
          activeColor: AppTheme.primaryColor,
          contentPadding: EdgeInsets.zero,
        );
      case 'text':
        return TextFormField(
          initialValue: widget.settingsValues[key]?.toString(),
          style: GoogleFonts.inter(color: AppTheme.textColor),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: AppTheme.secondaryTextColor),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.secondaryTextColor)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor)),
          ),
          onChanged: (val) {
            widget.onSettingChanged(key, val);
          },
        );
      case 'list':
        List<String> currentList = (widget.settingsValues[key] as List?)?.cast<String>() ?? [];
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
                    final newList = List<String>.from(currentList)..remove(e);
                    widget.onSettingChanged(key, newList);
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
