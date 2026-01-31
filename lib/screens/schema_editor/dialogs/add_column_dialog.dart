import 'package:flutter/material.dart';
import '../../../models/schema_models.dart';
import '../../../theme/app_theme.dart';

class AddColumnDialog extends StatefulWidget {
  const AddColumnDialog({super.key});

  @override
  State<AddColumnDialog> createState() => _AddColumnDialogState();
}

class _AddColumnDialogState extends State<AddColumnDialog> {
  final _labelController = TextEditingController();
  final _keyController = TextEditingController();
  bool _isKeyManuallyEdited = false;
  String _currentType = 'text';
  bool _isRequired = false;

  @override
  void initState() {
    super.initState();
    _labelController.addListener(_onLabelChanged);
  }

  void _onLabelChanged() {
    if (!_isKeyManuallyEdited) {
      _keyController.text = _labelController.text
          .toLowerCase()
          .trim()
          .replaceAll(RegExp(r'\s+'), '_')
          .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    }
  }

  @override
  void dispose() {
    _labelController.removeListener(_onLabelChanged);
    _labelController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      backgroundColor: theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
      title: Text('Add Column', style: AppTheme.inter(color: theme.textTheme.titleLarge?.color)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _labelController,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: const InputDecoration(
                labelText: 'Column Name',
                hintText: 'e.g. Unit Price',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _keyController,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: const InputDecoration(
                labelText: 'Column Key (Database/Spreadsheet)',
                hintText: 'e.g. unit_price',
                helperText: 'Used as the column header in your spreadsheet.',
              ),
              onChanged: (val) {
                if (val.isNotEmpty) {
                  _isKeyManuallyEdited = true;
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _currentType,
              dropdownColor: theme.cardTheme.color,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              items: {
                'text', 'number', 'date', 'select', 'boolean', 'image', 'scanner', 'currency', 'formula', 'relation', 'table', 'email', 'phone'
              }
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase())))
                  .toList(),
              onChanged: (val) {
                setState(() => _currentType = val!);
              },
              decoration: const InputDecoration(labelText: 'Data Type'),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Is Required'),
              value: _isRequired,
              activeThumbColor: theme.primaryColor,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) {
                setState(() => _isRequired = val);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            if (_labelController.text.isEmpty || _keyController.text.isEmpty) return;
            
            final newCol = ColumnConfig(
              key: _keyController.text.trim(),
              label: _labelController.text.trim(),
              type: _currentType,
              isRequired: _isRequired,
            );
            
            Navigator.pop(context, newCol);
          }, 
          child: const Text('Add')
        ),
      ],
    );
  }
}
