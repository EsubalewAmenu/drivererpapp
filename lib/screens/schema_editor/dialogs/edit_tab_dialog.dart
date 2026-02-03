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
  late String _template;
  late bool _loadAuto;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.tab.label);
    _template = widget.tab.detailTemplate?.template ?? 'standard';
    _loadAuto = widget.tab.loadSubTableDataAutomatically ?? true;
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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _labelController,
            style: TextStyle(color: theme.textTheme.bodyLarge?.color),
            decoration: const InputDecoration(labelText: 'Tab Name'),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _template,
            decoration: const InputDecoration(labelText: 'Detail Template'),
            dropdownColor: theme.cardColor,
            style: TextStyle(color: theme.textTheme.bodyLarge?.color),
            items: const [
              DropdownMenuItem(value: 'standard', child: Text('Standard')),
              DropdownMenuItem(value: 'modern', child: Text('Modern Visual')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _template = val);
            },
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Auto-load Sub-tables'),
            subtitle: const Text('Fetch sub-data automatically on entry'),
            value: _loadAuto,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => setState(() => _loadAuto = val),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_labelController.text.isEmpty) return;
            
            final updatedTab = widget.tab.copyWith(
              label: _labelController.text,
              detailTemplate: (widget.tab.detailTemplate ?? DetailTemplateConfig()).copyWith(
                template: _template,
              ),
              loadSubTableDataAutomatically: _loadAuto,
            );
            
            Navigator.pop(context, updatedTab);
          }, 
          child: const Text('Save')
        ),
      ],
    );
  }
}
