import 'package:flutter/material.dart';
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
          title: 'Edit ${widget.column.label}',
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
          title: 'Add New ${widget.column.label}',
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
    final theme = Theme.of(context);
    final borderColor = theme.textTheme.bodyMedium?.color ?? AppTheme.secondaryTextColor;

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
                color: theme.textTheme.bodySmall?.color,
                letterSpacing: 1.0,
              ),
            ),
            TextButton.icon(
              onPressed: _addRow,
              icon: Icon(Icons.add, size: 16, color: widget.primaryColor),
              label: Text(
                'Add',
                style: TextStyle(color: widget.primaryColor, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.value.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor.withValues(alpha: 0.1)),
            ),
            child: Center(
              child: Column(
                children: [
                   Icon(Icons.list_alt_rounded, color: borderColor.withValues(alpha: 0.5), size: 32),
                   const SizedBox(height: 8),
                   Text(
                    'No ${widget.column.label.toLowerCase()} added yet',
                    style: TextStyle(color: borderColor.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor.withValues(alpha: 0.2)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.value.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = widget.value[index];
                final subCols = widget.column.columns ?? [];
                
                // Refined heuristic to find meaningful labels
                final titleKeys = ['phone', 'email', 'name', 'title', 'label', 'value'];
                final subtitleKeys = ['type', 'category', 'status', 'tag'];
                
                String? foundTitle;
                String? foundSubtitle;

                // 1. Try preferred title keys
                for (var key in titleKeys) {
                  final col = subCols.where((c) => c.key.toLowerCase().contains(key)).firstOrNull;
                  if (col != null && item[col.key] != null && item[col.key].toString().trim().isNotEmpty) {
                    foundTitle = item[col.key].toString();
                    break;
                  }
                }

                // 2. Try preferred subtitle keys (ensure it's different from title)
                for (var key in subtitleKeys) {
                  final col = subCols.where((c) => c.key.toLowerCase().contains(key)).firstOrNull;
                  if (col != null && item[col.key] != null && item[col.key].toString().trim().isNotEmpty) {
                    final val = item[col.key].toString();
                    if (val != foundTitle) {
                      foundSubtitle = val;
                      break;
                    }
                  }
                }

                // 3. Fallback title: first non-hidden field with data
                if (foundTitle == null) {
                  for (var col in subCols) {
                    if (col.hidden != true && item[col.key] != null && item[col.key].toString().trim().isNotEmpty) {
                      foundTitle = item[col.key].toString();
                      break;
                    }
                  }
                }

                final title = foundTitle ?? '${widget.column.label} ${index + 1}';
                final subtitle = foundSubtitle ?? '';

                return ListTile(
                  title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
                  subtitle: subtitle.isNotEmpty ? Text(subtitle, style: TextStyle(color: theme.textTheme.bodyMedium?.color)) : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        color: widget.primaryColor,
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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(widget.title, style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleLarge?.color,
                  )),
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
                  child: Text(
                    widget.title.startsWith('Add') ? 'Add' : 'Save Changes',
                    style: const TextStyle(
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
