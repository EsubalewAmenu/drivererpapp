import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/schema_models.dart';
import '../../../theme/app_theme.dart';

class DynamicDropdownField extends StatelessWidget {
  final ColumnConfig column;
  final String? value;
  final Function(String?) onChanged;

  const DynamicDropdownField({
    super.key,
    required this.column,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    List<dynamic> optionsList = [];
    if (column.options is List) {
      optionsList = column.options as List;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          column.label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.secondaryTextColor,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          dropdownColor: AppTheme.surfaceColor,
          style: TextStyle(color: AppTheme.textColor),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          items: optionsList.map<DropdownMenuItem<String>>((opt) {
            final strVal = opt.toString();
            return DropdownMenuItem<String>(value: strVal, child: Text(strVal));
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
