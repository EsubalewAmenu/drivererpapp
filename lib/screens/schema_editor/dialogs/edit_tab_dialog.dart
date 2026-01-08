import 'package:flutter/material.dart';
import '../../../models/schema_models.dart';
import '../../../theme/app_theme.dart';

class EditTabDialog extends StatefulWidget {
  final TabConfig tab;

  const EditTabDialog({super.key, required this.tab});

  @override
  State<EditTabDialog> createState() => _EditTabDialogState();
}

class _EditTabDialogState extends State<EditTabDialog> {
  late TextEditingController _labelController;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.tab.label);
  }

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
      title: Text('Edit Tab', style: AppTheme.inter(color: theme.textTheme.titleLarge?.color)),
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
            
            final updatedTab = TabConfig(
              id: widget.tab.id,
              label: _labelController.text,
              columns: widget.tab.columns,
              quickFilters: widget.tab.quickFilters,
            );
            
            Navigator.pop(context, updatedTab);
          }, 
          child: const Text('Save')
        ),
      ],
    );
  }
}
