import 'package:flutter/material.dart';
import '../../../models/schema_models.dart';
import '../../../theme/app_theme.dart';

class DynamicTextField extends StatefulWidget {
  final ColumnConfig column;
  final String value;
  final Color primaryColor;
  final Function(String) onChanged;
  final TextEditingController? controller;

  const DynamicTextField({
    super.key,
    required this.column,
    required this.value,
    required this.primaryColor,
    required this.onChanged,
    this.controller,
  });

  @override
  State<DynamicTextField> createState() => _DynamicTextFieldState();
}

class _DynamicTextFieldState extends State<DynamicTextField> {
  late TextEditingController _controller;
  bool _localController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController(text: widget.value);
      _localController = true;
    }
  }

  @override
  void didUpdateWidget(covariant DynamicTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null && _controller != widget.controller) {
      _controller = widget.controller!;
    }
    
    // If we are using an external controller, it's the source of truth.
    // We should NOT overwrite its text from widget.value unless they are out of sync 
    // AND we are NOT using an external controller (local controller case).
    // Actually, if using external controller, the parent 'data' Map is just a copy.
    if (_localController && widget.value != _controller.text) {
       _controller.text = widget.value;
       _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
    }
  }

  @override
  void dispose() {
    if (_localController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNumeric = widget.column.type == 'number' || widget.column.type == 'currency';
    final isEmail = widget.column.type == 'email';
    final isPhone = widget.column.type == 'phone';
    final isCurrency = widget.column.type == 'currency';
    final isLongText = widget.column.type == 'long_text' || widget.column.type == 'longtext';
    final maxLines = isLongText ? 4 : 1;

    final textColor = theme.textTheme.bodyMedium?.color ?? AppTheme.textColor;
    final hintColor = theme.disabledColor;
    final fillColor = theme.cardTheme.color ?? theme.cardColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.column.label.toUpperCase(),
          style: AppTheme.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: theme.textTheme.bodySmall?.color,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _controller,
          keyboardType: isNumeric 
            ? TextInputType.number 
            : (isEmail 
                ? TextInputType.emailAddress 
                : (isPhone 
                    ? TextInputType.phone 
                    : (isLongText ? TextInputType.multiline : TextInputType.text))),
          maxLines: maxLines,
          style: AppTheme.inter(color: textColor),
          decoration: InputDecoration(
            filled: true,
            fillColor: fillColor,
            hintText: 'Enter ${widget.column.label.toLowerCase()}',
            hintStyle: TextStyle(color: hintColor),
            prefixText: isCurrency ? '${widget.column.currencySymbol ?? '\$'} ' : null,
            prefixStyle: TextStyle(color: textColor, fontWeight: FontWeight.bold),
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
            if (widget.column.isRequired == true) {
              if (value == null || value.isEmpty) {
                return 'This field is required';
              }
            }
            if (isNumeric && value != null && value.isNotEmpty) {
              if (double.tryParse(value) == null) {
                return 'Please enter a valid number';
              }
            }
            if (widget.column.type == 'email' && value != null && value.isNotEmpty) {
              final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!emailRegex.hasMatch(value)) {
                return 'Please enter a valid email';
              }
            }
            if (widget.column.type == 'phone' && value != null && value.isNotEmpty) {
              // Basic phone validation: allows +, digits, spaces, dashes
              final phoneRegex = RegExp(r'^\+?[\d\s-]{7,15}$');
              if (!phoneRegex.hasMatch(value)) {
                return 'Please enter a valid phone number';
              }
            }
            return null;
          },
        ),
      ],
    );
  }
}
