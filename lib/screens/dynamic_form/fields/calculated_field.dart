import 'package:flutter/material.dart';
import '../../../models/schema_models.dart';

/// Calculations are authoritative on the server; the form shows a local preview.
class DynamicCalculatedField extends StatelessWidget {
  final FieldDefinition column;
  final Map<String, TextEditingController> controllers;
  final ValueChanged<String> onCalculated;
  const DynamicCalculatedField({
    super.key,
    required this.column,
    required this.controllers,
    required this.onCalculated,
  });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge(controllers.values.toList()),
    builder: (context, _) {
      final c = column.calculation ?? {};
      double number(String key) =>
          double.tryParse(controllers[key]?.text ?? '') ?? 0;
      final fields = (c['fields'] as List? ?? []).cast<String>();
      String value = 'Calculated when saved';
      if (c['operation'] == 'multiply') {
        value = fields
            .fold<double>(1, (a, k) => a * number(k))
            .toStringAsFixed(2);
      }
      if (c['operation'] == 'sum') {
        value =
            (fields.fold<double>(0, (a, k) => a + number(k)) -
                    (c['subtract'] as List? ?? []).fold<double>(
                      0,
                      (a, k) => a + number(k),
                    ))
                .toStringAsFixed(2);
      }
      return InputDecorator(
        decoration: InputDecoration(
          labelText: column.label,
          helperText: 'Computed by the company backend',
        ),
        child: Text(value),
      );
    },
  );
}
