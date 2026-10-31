import 'package:flutter/material.dart';
import 'package:drivererpapp/theme/app_theme.dart';
import '../../../models/schema_models.dart';

class ColumnListItem extends StatelessWidget {
  final FieldDefinition column;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ColumnListItem({
    super.key,
    required this.column,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHidden = column.hidden == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(
            _getIconForType(column.type),
            size: 16,
            color: theme.textTheme.bodyMedium?.color ?? Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  column.label,
                  style: AppTheme.inter(
                    color: isHidden
                        ? (theme.textTheme.bodyMedium?.color ?? Colors.grey)
                        : (theme.textTheme.bodyLarge?.color),
                    decoration: isHidden ? TextDecoration.lineThrough : null,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  column.key,
                  style: AppTheme.sourceCodePro(
                    fontSize: 10,
                    color: (theme.textTheme.bodyMedium?.color ?? Colors.grey)
                        .withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          if (isHidden)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'HIDDEN',
                style: AppTheme.sourceCodePro(
                  fontSize: 9,
                  color: Colors.orange,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (theme.textTheme.bodyMedium?.color ?? Colors.grey)
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              column.type.toUpperCase(),
              style: AppTheme.sourceCodePro(
                fontSize: 10,
                color: theme.textTheme.bodyMedium?.color ?? Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 16),
            color: theme.primaryColor,
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            color: Colors.red,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'text':
        return Icons.text_fields;
      case 'number':
        return Icons.numbers;
      case 'date':
        return Icons.calendar_today;
      case 'select':
        return Icons.list;
      case 'calculated':
        return Icons.functions;
      case 'scanner':
        return Icons.qr_code_scanner;
      case 'currency':
        return Icons.attach_money;
      case 'boolean':
        return Icons.check_box;
      case 'image':
        return Icons.image;
      default:
        return Icons.short_text;
    }
  }
}
