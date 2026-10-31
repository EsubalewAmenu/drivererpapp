import 'package:flutter/material.dart';

class CalculationEditor extends StatelessWidget {
  final Map<String, dynamic> value;
  final ValueChanged<Map<String, dynamic>> onChanged;
  const CalculationEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final operation = value['operation'] ?? 'multiply';
    final labels = <String, String>{
      'multiply': 'Multiply fields',
      'sum': 'Add and subtract fields',
      'days_between': 'Days between dates',
      'book_value': 'Straight-line asset value',
      'nested_sum': 'Total nested items',
      'lookup': 'Read a related record field',
      'variant_name': 'Inventory variant name',
    };
    final keys = switch (operation) {
      'multiply' => ['fields'],
      'sum' => ['fields', 'subtract'],
      'days_between' => ['start', 'end'],
      'book_value' => ['cost', 'life', 'date'],
      'nested_sum' => ['collection_field', 'field'],
      'lookup' => ['relation', 'collection', 'field'],
      'variant_name' => [
        'relation',
        'collection',
        'label',
        'variants',
        'fields',
      ],
      _ => <String>[],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: operation,
          decoration: const InputDecoration(labelText: 'Calculation'),
          items: labels.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) => onChanged({...value, 'operation': v}),
        ),
        for (final key in keys)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextFormField(
              key: ValueKey('$operation:$key'),
              initialValue: value[key] is List
                  ? (value[key] as List).join(', ')
                  : value[key]?.toString() ?? '',
              decoration: InputDecoration(
                labelText: switch (key) {
                  'fields' => 'Field keys, separated by commas',
                  'subtract' => 'Fields to subtract, separated by commas',
                  'collection_field' => 'Nested items field',
                  'relation' => 'Relation field key',
                  'collection' => 'Related collection key',
                  'field' => 'Source field key',
                  'start' => 'Start date field',
                  'end' => 'End date field',
                  'cost' => 'Cost field',
                  'life' => 'Useful life field',
                  'date' => 'Purchase date field',
                  'label' => 'Related name field',
                  'variants' => 'Related variants flag',
                  _ => key,
                },
              ),
              onChanged: (text) => onChanged({
                ...value,
                key: ['fields', 'subtract'].contains(key)
                    ? text
                          .split(',')
                          .map((v) => v.trim())
                          .where((v) => v.isNotEmpty)
                          .toList()
                    : text.trim(),
              }),
            ),
          ),
        if (operation == 'days_between')
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Include both start and end days'),
            value: value['inclusive'] == true,
            onChanged: (v) => onChanged({...value, 'inclusive': v}),
          ),
      ],
    );
  }
}
