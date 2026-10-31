import 'package:flutter/material.dart';
import '../../models/schema_models.dart';
import '../../services/backend/backend_session.dart';

/// Shared, recursive display for schema fields, nested rows, and lists.
class RecordFieldValue extends StatelessWidget {
  final FieldDefinition field;
  final dynamic value;
  const RecordFieldValue({super.key, required this.field, required this.value});
  String _label(String key) => key
      .replaceAll('_', ' ')
      .split(' ')
      .map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');
  Widget _object(BuildContext context, Map<dynamic, dynamic> object) {
    final definitions = field.fields;
    final fields =
        definitions?.where((f) => f.hidden != true).toList() ??
        [
          for (final key in object.keys)
            FieldDefinition(
              key: key.toString(),
              label: _label(key.toString()),
              type: 'text',
            ),
        ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final nested in fields)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (fields.length > 1)
                  Text(
                    nested.label,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                RecordFieldValue(field: nested, value: object[nested.key]),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (value == null || value == '') return const Text('—');
    if (value is List) {
      final items = value as List;
      if (items.isEmpty) return const Text('No items');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in items)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: item is Map
                  ? _object(context, item)
                  : RecordFieldValue(field: field, value: item),
            ),
        ],
      );
    }
    if (value is Map) return _object(context, value as Map);
    if (['image', 'signature'].contains(field.type)) {
      final url = BackendSession.mediaUrl(value.toString());
      return Image.network(
        url,
        headers: BackendSession.mediaHeaders(url),
        height: 180,
        fit: BoxFit.contain,
        errorBuilder: (_, e, s) => const Text('Image unavailable'),
      );
    }
    if (value is bool) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            value ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(value ? 'Yes' : 'No'),
        ],
      );
    }
    if (field.type == 'currency' && num.tryParse(value.toString()) != null) {
      return SelectableText(
        '${field.currencySymbol ?? ''}${num.parse(value.toString()).toStringAsFixed(2)}',
      );
    }
    return SelectableText(value.toString());
  }
}
