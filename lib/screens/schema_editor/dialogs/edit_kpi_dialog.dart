import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/schema_models.dart';
import '../../../theme/app_theme.dart';

class EditKpiDialog extends StatefulWidget {
  final KpiCard? kpi; // Null if adding new

  const EditKpiDialog({super.key, this.kpi});

  @override
  State<EditKpiDialog> createState() => _EditKpiDialogState();
}

class _EditKpiDialogState extends State<EditKpiDialog> {
  late TextEditingController _labelController;
  late TextEditingController _calculationController;
  String _format = 'number';

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.kpi?.label ?? '');
    _calculationController = TextEditingController(text: widget.kpi?.calculation ?? '');
    _format = widget.kpi?.format ?? 'number';
  }

  @override
  void dispose() {
    _labelController.dispose();
    _calculationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.kpi != null;

    return AlertDialog(
      backgroundColor: AppTheme.surfaceColor,
      title: Text(isEditing ? 'Edit KPI Card' : 'Add KPI Card', style: GoogleFonts.inter(color: AppTheme.textColor)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _labelController,
              style: const TextStyle(color: AppTheme.textColor),
              decoration: const InputDecoration(
                labelText: 'Label',
                helperText: 'Display name (e.g. Total Revenue)',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _calculationController,
              style: const TextStyle(color: AppTheme.textColor),
              decoration: const InputDecoration(
                labelText: 'Calculation Formula',
                helperText: 'e.g. SUM(amount) or COUNT(id)',
              ),
            ),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              initialValue: _format,
              dropdownColor: AppTheme.surfaceColor,
              style: const TextStyle(color: AppTheme.textColor),
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
            if (_calculationController.text.isEmpty) return;
            
            final newKpi = KpiCard(
              label: _labelController.text,
              calculation: _calculationController.text,
              format: _format,
            );
            
            Navigator.pop(context, newKpi);
          }, 
          child: const Text('Save')
        ),
      ],
    );
  }
}
