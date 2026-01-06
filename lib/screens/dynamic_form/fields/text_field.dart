import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/schema_models.dart';
import '../../../theme/app_theme.dart';

class DynamicTextField extends StatefulWidget {
  final ColumnConfig column;
  final String value;
  final Color primaryColor;
  final Function(String) onChanged;

  const DynamicTextField({
    super.key,
    required this.column,
    required this.value,
    required this.primaryColor,
    required this.onChanged,
  });

  @override
  State<DynamicTextField> createState() => _DynamicTextFieldState();
}

class _DynamicTextFieldState extends State<DynamicTextField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant DynamicTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
      _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNumeric = widget.column.type == 'number' || widget.column.type == 'currency';
    final isCurrency = widget.column.type == 'currency';
    final maxLines = widget.column.type == 'longtext' ? 4 : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.column.label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.secondaryTextColor,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _controller,
          keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
          maxLines: maxLines,
          style: GoogleFonts.inter(color: AppTheme.textColor),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.surfaceColor,
            hintText: 'Enter ${widget.column.label.toLowerCase()}',
            hintStyle: TextStyle(color: AppTheme.secondaryTextColor.withValues(alpha: 0.5)),
            prefixText: isCurrency ? '\$ ' : null,
            prefixStyle: const TextStyle(color: AppTheme.textColor, fontWeight: FontWeight.bold),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: widget.primaryColor),
            ),
          ),
          onChanged: widget.onChanged,
          validator: (value) {
            if (value == null || value.isEmpty) {
              // return 'Please enter ${widget.column.label.toLowerCase()}';
            }
            return null;
          },
        ),
      ],
    );
  }
}
