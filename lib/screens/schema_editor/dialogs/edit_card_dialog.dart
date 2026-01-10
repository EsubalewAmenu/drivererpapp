import 'package:flutter/material.dart';
import '../../../models/schema_models.dart';
import '../../../theme/app_theme.dart';

class EditCardDialog extends StatefulWidget {
  final DashboardCard? card; // Null if adding new

  const EditCardDialog({super.key, this.card});

  @override
  State<EditCardDialog> createState() => _EditCardDialogState();
}

class _EditCardDialogState extends State<EditCardDialog> {
  late TextEditingController _labelController;
  late TextEditingController _formulaController;
  String _format = 'number';

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.card?.label ?? '');
    _formulaController = TextEditingController(text: widget.card?.formula ?? '');
    _format = widget.card?.format ?? 'number';
  }

  @override
  void dispose() {
    _labelController.dispose();
    _formulaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.card != null;

    return AlertDialog(
      backgroundColor: theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
      title: Text(isEditing ? 'Edit Card' : 'Add Card', style: AppTheme.inter(color: theme.textTheme.titleLarge?.color)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _labelController,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: const InputDecoration(
                labelText: 'Label',
                helperText: 'Display name (e.g. Total Revenue)',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _formulaController,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: const InputDecoration(
                labelText: 'Rule / Formula',
                helperText: 'e.g. =COUNTIF(sheet!A:A, "<5")',
              ),
            ),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              initialValue: _format,
              dropdownColor: theme.cardTheme.color,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              items: ['number', 'currency', 'percent']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase())))
                  .toList(),
              onChanged: (val) {
                setState(() => _format = val!);
              },
              decoration: const InputDecoration(labelText: 'Format'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            if (_labelController.text.isEmpty) return;
            if (_formulaController.text.isEmpty) return;
            
            final newCard = DashboardCard(
              label: _labelController.text,
              formula: _formulaController.text, // Updated from calculation
              format: _format,
            );
            
            Navigator.pop(context, newCard);
          }, 
          child: const Text('Save')
        ),
      ],
    );
  }
}
