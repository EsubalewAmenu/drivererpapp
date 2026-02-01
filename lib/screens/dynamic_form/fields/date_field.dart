import 'package:flutter/material.dart';
import '../../../models/schema_models.dart';
import '../../../theme/app_theme.dart';

class DynamicDateField extends StatelessWidget {
  final ColumnConfig column;
  final String? value;
  final Color primaryColor;
  final Function(String) onChanged;

  const DynamicDateField({
    super.key,
    required this.column,
    required this.value,
    required this.primaryColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return FormField<String>(
      initialValue: value,
      validator: (val) {
        if (column.isRequired == true) {
          if (val == null || val.isEmpty) {
            return 'Date is required';
          }
        }
        return null;
      },
      builder: (state) {
        final borderColor = state.hasError 
           ? theme.colorScheme.error 
           : (theme.textTheme.bodyMedium?.color ?? AppTheme.secondaryTextColor);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              column.label.toUpperCase(),
              style: AppTheme.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: theme.textTheme.bodySmall?.color,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: column.readonly == true ? null : () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  builder: (context, child) {
                    return Theme(
                      data: theme.copyWith(
                        colorScheme: theme.colorScheme.copyWith(
                          primary: primaryColor,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (date != null) {
                  final str = date.toIso8601String().split('T')[0];
                  onChanged(str);
                  state.didChange(str);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: column.readonly == true ? theme.dividerColor.withValues(alpha: 0.05) : theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                  // Show red border if error
                  border: state.hasError 
                      ? Border.all(color: theme.colorScheme.error)
                      : Border.all(color: Colors.transparent),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, color: column.readonly == true ? borderColor.withValues(alpha: 0.5) : borderColor, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      state.value ?? 'Select Date',
                      style: AppTheme.inter(
                        color: column.readonly == true 
                            ? (state.value != null ? theme.textTheme.titleMedium?.color?.withValues(alpha: 0.6) : theme.disabledColor) 
                            : (state.value != null ? theme.textTheme.titleMedium?.color : theme.disabledColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 8),
                child: Text(
                  state.errorText!,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      }
    );
  }
}
