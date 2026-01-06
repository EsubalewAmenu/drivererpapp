import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    if (widget.controller != null) {
        if (_controller != widget.controller) {
            _controller = widget.controller!;
            // Ensure newly passed controller has text if needed, but usually controller is source of truth
        }
    }
    // Only update text if value changed from outside (and not from our own typing which updates controller)
    if (_controller.text != widget.value) {
       // Check if this update is just a loop back from setState
       // But wait, if controller.text is '10', onChange -> setState -> widget.value = '10'
       // loop is safe normally.
       // But if widget.value changes to '10a' externally?
       // Let's keep existing logic but be careful.
       if (widget.value != _controller.text) {
          // If the values are different, update controller to match widget.value
          // This handles external updates (e.g. from backend/logic)
           
          // If we are typing, controller.text is ahead/current. widget.value lags slightly behind setState.
          // BUT, if we use the SHARED controller, the typing updates it directly.
          
          // If we use shared controller: 
          // User types 'A'. Controller -> 'A'. onChange -> 'A'. Widget rebuilds with value='A'.
          // widget.value == _controller.text ('A' == 'A'). No change.
          
          // This logic is mostly for when _controller is local or if external change happens.
           _controller.text = widget.value;
           _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
       }
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
    final isCurrency = widget.column.type == 'currency';
    final maxLines = widget.column.type == 'longtext' ? 4 : 1;

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
          keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
          maxLines: maxLines,
          style: AppTheme.inter(color: textColor),
          decoration: InputDecoration(
            filled: true,
            fillColor: fillColor,
            hintText: 'Enter ${widget.column.label.toLowerCase()}',
            hintStyle: TextStyle(color: hintColor),
            prefixText: isCurrency ? '\$ ' : null,
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
            return null;
          },
        ),
      ],
    );
  }
}
