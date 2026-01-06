import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          column.label.toUpperCase(),
          style: AppTheme.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.secondaryTextColor,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.dark(
                      primary: primaryColor,
                      onPrimary: AppTheme.backgroundColor,
                      surface: AppTheme.surfaceColor,
                      onSurface: AppTheme.textColor,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (date != null) {
              onChanged(date.toIso8601String().split('T')[0]);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.transparent),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, color: AppTheme.secondaryTextColor, size: 20),
                const SizedBox(width: 12),
                Text(
                  value ?? 'Select Date',
                  style: AppTheme.inter(
                    color: value != null ? AppTheme.textColor : AppTheme.secondaryTextColor.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
