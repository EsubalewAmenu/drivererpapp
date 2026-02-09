import 'package:flutter/material.dart';
import '../../../models/schema_models.dart';
import '../../../theme/app_theme.dart';

class DynamicBooleanField extends StatelessWidget {
  final ColumnConfig column;
  final bool value;
  final Color primaryColor;
  final Function(bool) onChanged;

  const DynamicBooleanField({
    super.key,
    required this.column,
    required this.value,
    required this.primaryColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isReadonly = column.readonly == true;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isReadonly ? theme.dividerColor.withValues(alpha: 0.05) : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  column.label,
                  style: AppTheme.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isReadonly ? theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.6) : theme.textTheme.bodyLarge?.color,
                  ),
                ),
                if (column.help != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      column.help!,
                      style: AppTheme.inter(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: primaryColor,
            onChanged: isReadonly ? null : onChanged,
          ),
        ],
      ),
    );
  }
}
