import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceColor,
      title: Text('Add Column', style: GoogleFonts.inter(color: AppTheme.textColor)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _labelController,
              style: TextStyle(color: AppTheme.textColor),
              decoration: const InputDecoration(labelText: 'Column Name'),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _currentType,
              dropdownColor: AppTheme.surfaceColor,
              style: TextStyle(color: AppTheme.textColor),
              items: {
                'text', 'number', 'date', 'select', 'boolean', 'image', 'scanner', 'currency', 'formula', 'relation', 'table'
              }
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase())))
                  .toList(),
              onChanged: (val) {
                setState(() => _currentType = val!);
              },
              decoration: const InputDecoration(labelText: 'Data Type'),
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
            );
            
            Navigator.pop(context, newCol);
          }, 
          child: const Text('Add')
        ),
      ],
    );
  }
}
