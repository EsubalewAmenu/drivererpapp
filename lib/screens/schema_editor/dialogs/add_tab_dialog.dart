import 'package:flutter/material.dart';
import '../../../models/schema_models.dart';
import '../../../theme/app_theme.dart';

class AddTabDialog extends StatefulWidget {
  const AddTabDialog({super.key});

  @override
  State<AddTabDialog> createState() => _AddTabDialogState();
}

class _AddTabDialogState extends State<AddTabDialog> {
  final _labelController = TextEditingController();

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
      title: Text('Add New Tab', style: AppTheme.inter(color: theme.textTheme.titleLarge?.color)),
      content: TextField(
        controller: _labelController,
        style: TextStyle(color: theme.textTheme.bodyLarge?.color),
        decoration: const InputDecoration(labelText: 'Tab Name'),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_labelController.text.isEmpty) return;
            
            final id = _labelController.text.toLowerCase().replaceAll(' ', '_');
            final newTab = TabConfig(
              id: id,
              label: _labelController.text,
              columns: [],
            );
            
            Navigator.pop(context, newTab);
          }, 
          child: const Text('Add')
        ),
      ],
    );
  }
}
