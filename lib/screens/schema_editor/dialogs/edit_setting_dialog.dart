import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class EditSettingDialog extends StatefulWidget {
  final String? settingKey; // Null if adding new
  final Map<String, dynamic>? settingData; // Null if adding new
  final List<String> existingKeys;

  const EditSettingDialog({
    super.key,
    this.settingKey,
    this.settingData,
    required this.existingKeys,
  });

  @override
  State<EditSettingDialog> createState() => _EditSettingDialogState();
}

class _EditSettingDialogState extends State<EditSettingDialog> {
  late TextEditingController _keyController;
  late TextEditingController _labelController;
  late String _type;
  String? _dependsOn;
  
  // For list type
  List<String> _options = [];

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: widget.settingKey ?? '');
    _labelController = TextEditingController(text: widget.settingData?['label'] ?? '');
    _type = widget.settingData?['type'] ?? 'text';
    _dependsOn = widget.settingData?['dependsOn'];
    
    if (widget.settingData?['options'] != null) {
      _options = List<String>.from(widget.settingData!['options']);
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.settingKey != null;

    return AlertDialog(
      backgroundColor: AppTheme.surfaceColor,
      title: Text(isEditing ? 'Edit Setting' : 'Add Setting', style: GoogleFonts.inter(color: AppTheme.textColor)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _keyController,
              style: TextStyle(color: AppTheme.textColor),
              decoration: const InputDecoration(
                labelText: 'Setting Key (ID)',
                helperText: 'Unique identifier (e.g. tax_rate)',
              ),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _labelController,
              style: TextStyle(color: AppTheme.textColor),
              decoration: const InputDecoration(labelText: 'Label'),
            ),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              value: _type,
              dropdownColor: AppTheme.surfaceColor,
              style: TextStyle(color: AppTheme.textColor),
              items: ['text', 'boolean', 'list', 'number']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase())))
                  .toList(),
              onChanged: (val) {
                setState(() => _type = val!);
              },
              decoration: const InputDecoration(labelText: 'Type'),
            ),
            const SizedBox(height: 16),

            TextField(
              onChanged: (val) => _dependsOn = val.isEmpty ? null : val,
              controller: TextEditingController(text: _dependsOn),
              style: TextStyle(color: AppTheme.textColor),
              decoration: const InputDecoration(
                labelText: 'Depends On (Key)',
                helperText: 'Optional: Show only if this setting is true',
              ),
            ),

            if (_type == 'list') ...[
              const SizedBox(height: 24),
              Text('Options', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.textColor)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ..._options.map((opt) => Chip(
                    label: Text(opt),
                    onDeleted: () => setState(() => _options.remove(opt)),
                  )),
                  ActionChip(
                    label: const Icon(Icons.add, size: 16),
                    onPressed: () {
                      _showAddOptionDialog(context);
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            if (_labelController.text.isEmpty) return;
            if (_keyController.text.isEmpty) return;
            
            final key = _keyController.text.toLowerCase().replaceAll(' ', '_');
            
            // Check if key exists (exclude current key if editing)
            if (widget.existingKeys.contains(key) && key != widget.settingKey) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Key already exists!')),
              );
              return;
            }

            final newSetting = {
              'label': _labelController.text,
              'type': _type,
              'dependsOn': _dependsOn,
              if (_type == 'list') 'options': _options,
              'value': null, // Reset value or keep default
            };
            
            Navigator.pop(context, {'key': key, 'data': newSetting});
          }, 
          child: const Text('Save')
        ),
      ],
    );
  }

  void _showAddOptionDialog(BuildContext context) {
    String val = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Option'),
        content: TextField(
          autofocus: true,
          onChanged: (v) => val = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Add')),
        ],
      ),
    ).then((_) {
      if (val.isNotEmpty) {
        setState(() => _options.add(val));
      }
    });
  }
}
