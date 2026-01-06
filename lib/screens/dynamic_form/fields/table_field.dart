import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/schema_models.dart';
import '../../../theme/app_theme.dart';
import '../dynamic_form_renderer.dart';

class DynamicTableField extends StatefulWidget {
  final ColumnConfig column;
  final List<Map<String, dynamic>> value;
  final Color primaryColor;
  final Function(List<Map<String, dynamic>>) onChanged;
  final ModuleSchema? module;

  const DynamicTableField({
    super.key,
    required this.column,
    required this.value,
    required this.primaryColor,
    required this.onChanged,
    this.module,
  });

  @override
  State<DynamicTableField> createState() => _DynamicTableFieldState();
}

class _DynamicTableFieldState extends State<DynamicTableField> {
  void _editRow(int index) async {
    final rowData = widget.value[index];
    // We need to open a dialog or a new screen to edit this row.
    // Since the row itself is defined by `widget.column.columns`, we can reuse DynamicFormScreen logic
    // or a simplified version of it.
    // For now, let's assume we push a new DynamicFormScreen but in "dialog" mode or similar.
    // However, DynamicFormScreen expects a full SchemaSection or similar structure.
    // Let's construct a temporary schema for the row editing.

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: _RowEditor(
          columns: widget.column.columns ?? [],
          initialData: rowData,
          primaryColor: widget.primaryColor,
          title: 'Edit ${widget.column.label} Item',
          module: widget.module,
        ),
      ),
    );

    if (result != null) {
      final newList = List<Map<String, dynamic>>.from(widget.value);
      newList[index] = result;
      widget.onChanged(newList);
    }
  }

  void _addRow() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: _RowEditor(
          columns: widget.column.columns ?? const [],
          initialData: const {},
          primaryColor: widget.primaryColor,
          title: 'Add ${widget.column.label} Item',
          module: widget.module,
        ),
      ),
    );

    if (result != null) {
      final newList = List<Map<String, dynamic>>.from(widget.value)..add(result);
      widget.onChanged(newList);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.column.label.toUpperCase(),
              style: AppTheme.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.secondaryTextColor,
                letterSpacing: 1.0,
              ),
            ),
            TextButton.icon(
              onPressed: _addRow,
              icon: Icon(Icons.add, size: 16, color: widget.primaryColor),
              label: Text(
                'Add Item',
                style: TextStyle(color: widget.primaryColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.value.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: const Center(
              child: Text(
                'No items added yet',
                style: TextStyle(color: AppTheme.secondaryTextColor),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.value.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = widget.value[index];
                // Try to find a meaningful label for the row
                String title = 'Item ${index + 1}';
                String subtitle = '';
                
                // Simple heuristic to find a title field
                for (var col in (widget.column.columns ?? [])) {
                  if (col.type == 'text' || col.type == 'relation') {
                    if (item[col.key] != null) {
                      title = item[col.key].toString();
                      break;
                    }
                  }
                }

                return ListTile(
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _editRow(index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                        onPressed: () {
                          final newList = List<Map<String, dynamic>>.from(widget.value)..removeAt(index);
                          widget.onChanged(newList);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// A simple internal widget to handle row editing using the same DynamicFormScreen logic would be ideal,
// but to avoid circular dependencies or complex state passing, we can create a mini-form here
// or reuse DynamicFormScreen if we refactor it to be embeddable.
// For now, I'll create a simplified _RowEditor that mimics the main form's behavior for these fields.
// Ideally, DynamicFormScreen should be reusable.

class _RowEditor extends StatefulWidget {
  final List<ColumnConfig> columns;
  final Map<String, dynamic> initialData;
  final Color primaryColor;
  final String title;
  final ModuleSchema? module;

  const _RowEditor({
    required this.columns,
    required this.initialData,
    required this.primaryColor,
    required this.title,
    this.module,
  });

  @override
  State<_RowEditor> createState() => _RowEditorState();
}

class _RowEditorState extends State<_RowEditor> {
  late Map<String, dynamic> _formData;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _formData = Map.from(widget.initialData);
    _initializeControllers();
  }

  void _initializeControllers() {
    for (var col in widget.columns) {
      if (['text', 'number', 'currency'].contains(col.type)) {
        _controllers[col.key] = TextEditingController(
          text: _formData[col.key]?.toString() ?? '',
        );
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: DynamicFormRenderer(
                  columns: widget.columns,
                  data: _formData,
                  primaryColor: widget.primaryColor,
                  controllers: _controllers,
                  module: widget.module,
                  onFieldChanged: (key, value) {
                    setState(() {
                      _formData[key] = value;
                    });
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context, _formData);
                  },
                  child: const Text(
                    'Save Item',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
