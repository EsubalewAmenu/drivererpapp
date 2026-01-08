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
  String _currentType = 'text';
  bool _isRequired = false;

  @override
  void dispose() {
    _labelController.dispose();
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
              decoration: const InputDecoration(labelText: 'Column Name'),
              autofocus: true,
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
              activeColor: theme.primaryColor,
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
            if (_labelController.text.isEmpty) return;
            
            final key = _labelController.text.toLowerCase().replaceAll(' ', '_');
            final newCol = ColumnConfig(
              key: key,
              label: _labelController.text,
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
