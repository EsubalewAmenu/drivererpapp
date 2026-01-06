import 'package:flutter/material.dart';
import '../../../models/schema_models.dart';
import '../../../theme/app_theme.dart';

class DynamicFormulaField extends StatelessWidget {
  final ColumnConfig column;
  final Map<String, TextEditingController> controllers;
  final Function(String) onCalculated;

  const DynamicFormulaField({
    super.key,
    required this.column,
    required this.controllers,
    required this.onCalculated,
  });

  @override
  Widget build(BuildContext context) {
    String value = '0.00';
    if (column.formula != null) {
      if (column.formula!.contains('*')) {
        final parts = column.formula!.split('*').map((e) => e.trim()).toList();
        if (parts.length == 2) {
          final key1 = parts[0];
          final key2 = parts[1];
          
          double val1 = double.tryParse(controllers[key1]?.text ?? '') ?? 0;
          double val2 = double.tryParse(controllers[key2]?.text ?? '') ?? 0;
          
          value = (val1 * val2).toStringAsFixed(2);
          // Notify parent of calculated value
          WidgetsBinding.instance.addPostFrameCallback((_) {
             onCalculated(value);
          });
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          column.label.toUpperCase(),
          style: AppTheme.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).textTheme.bodyMedium?.color,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color?.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Text(
            value,
            style: AppTheme.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ),
      ],
    );
  }
}
