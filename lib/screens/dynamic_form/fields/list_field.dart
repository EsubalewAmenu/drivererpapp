import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/schema_models.dart';
import '../../../theme/app_theme.dart';

class DynamicListField extends StatefulWidget {
  final ColumnConfig column;
  final List<String> value;
  final Color primaryColor;
  final Function(List<String>) onChanged;

  const DynamicListField({
    super.key,
    required this.column,
    required this.value,
    required this.primaryColor,
    required this.onChanged,
  });

  @override
  State<DynamicListField> createState() => _DynamicListFieldState();
}

class _DynamicListFieldState extends State<DynamicListField> {
  @override
  Widget build(BuildContext context) {
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.transparent),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...widget.value.map((e) => Chip(
                label: Text(e),
                backgroundColor: widget.primaryColor.withValues(alpha: 0.1),
                labelStyle: TextStyle(color: widget.primaryColor),
                deleteIcon: Icon(Icons.close, size: 16, color: widget.primaryColor),
                onDeleted: () {
                  final newList = List<String>.from(widget.value)..remove(e);
                  widget.onChanged(newList);
                },
              )),
              ActionChip(
                label: const Text('Add'),
                avatar: const Icon(Icons.add, size: 16),
                onPressed: () {
                  String newVal = '';
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Add ${widget.column.label}'),
                      content: TextField(
                        autofocus: true,
                        onChanged: (v) => newVal = v,
                        decoration: const InputDecoration(hintText: 'Enter value'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            if (newVal.isNotEmpty) {
                              final newList = List<String>.from(widget.value)..add(newVal);
                              widget.onChanged(newList);
                              Navigator.pop(context);
                            }
                          },
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
