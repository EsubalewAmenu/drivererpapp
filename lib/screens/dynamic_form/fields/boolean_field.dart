import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              column.label,
              style: AppTheme.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.textColor,
              ),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: primaryColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
