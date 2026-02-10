import 'package:flutter/material.dart';
import '../../../models/schema_models.dart';

class FilterEditorScreen extends StatefulWidget {
  final List<ColumnConfig> columns;
  final QuickFilter? existingFilter;

  const FilterEditorScreen({
    super.key,
    required this.columns,
    this.existingFilter,
  });

  @override
  State<FilterEditorScreen> createState() => _FilterEditorScreenState();
}

class _FilterEditorScreenState extends State<FilterEditorScreen> {
  final TextEditingController _labelController = TextEditingController();

  final List<_RuleDraft> _rules = [];

  final List<Map<String, String>> _operators = [
    {'label': 'Equals', 'value': '=='},
    {'label': 'Contains', 'value': 'contains'},
    {'label': 'Not Equals', 'value': '!='},
    {'label': 'Greater Than', 'value': '>'},
    {'label': 'Greater or Equal', 'value': '>='},
    {'label': 'Less Than', 'value': '<'},
    {'label': 'Less or Equal', 'value': '<='},
    {'label': 'Starts With', 'value': 'startsWith'},
    {'label': 'Ends With', 'value': 'endsWith'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingFilter != null) {
      _labelController.text = widget.existingFilter!.label;
      for (final rule in widget.existingFilter!.rules) {
        _rules.add(
          _RuleDraft(
            columnKey: rule.field,
            operator: rule.operator,
            controller: TextEditingController(text: rule.value?.toString() ?? ''),
          ),
        );
      }
    }

    if (_rules.isEmpty && widget.columns.isNotEmpty) {
      _rules.add(
        _RuleDraft(
          columnKey: widget.columns.first.key,
          operator: '==',
          controller: TextEditingController(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    for (final rule in _rules) {
      rule.controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    final validRules = _rules.where((r) => r.columnKey != null && r.columnKey!.isNotEmpty).toList();
    if (validRules.isEmpty) return;

    final rules = validRules.map((r) => FilterRule(
      field: r.columnKey!,
      operator: r.operator,
      value: r.controller.text,
    )).toList();

    String label = _labelController.text.trim();
    if (label.isEmpty) {
      label = rules.map((r) {
        final colLabel = widget.columns.firstWhere(
          (c) => c.key == r.field,
          orElse: () => ColumnConfig(key: r.field, label: r.field, type: 'text'),
        ).label;
        final opLabel = _operators.firstWhere(
          (element) => element['value'] == r.operator,
          orElse: () => {'label': r.operator},
        )['label'];
        return '$colLabel $opLabel ${r.value ?? ''}'.trim();
      }).join(' AND ');
    }

    final filter = QuickFilter(
      label: label,
      key: widget.existingFilter?.key ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
      rules: rules,
    );
    
    Navigator.pop(context, filter);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingFilter != null ? 'Edit Filter' : 'Add Filter'),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('Save', style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter Name', style: TextStyle(fontSize: 14, color: theme.disabledColor)),
            const SizedBox(height: 8),
            TextField(
              controller: _labelController,
              decoration: InputDecoration(
                hintText: 'Auto-generated if empty',
                filled: true,
                fillColor: theme.cardTheme.color,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.dividerColor)),
              ),
            ),
            const SizedBox(height: 24),
            Text('Rules', style: TextStyle(fontSize: 14, color: theme.disabledColor)),
            const SizedBox(height: 8),
            ..._rules.asMap().entries.map((entry) {
              final index = entry.key;
              final rule = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: rule.columnKey,
                              isExpanded: true,
                              dropdownColor: theme.cardTheme.color,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: theme.cardTheme.color,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.dividerColor)),
                              ),
                              items: [
                                ...widget.columns.map((col) {
                                  return DropdownMenuItem(
                                    value: col.key,
                                    child: Text(col.label, overflow: TextOverflow.ellipsis),
                                  );
                                }),
                                if (rule.columnKey != null && !widget.columns.any((c) => c.key == rule.columnKey))
                                  DropdownMenuItem(
                                    value: rule.columnKey,
                                    child: Text('${rule.columnKey} (Missing)', style: const TextStyle(color: Colors.red)),
                                  ),
                              ],
                              onChanged: (val) => setState(() => rule.columnKey = val),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: _rules.length <= 1 ? null : () => setState(() {
                              final removed = _rules.removeAt(index);
                              removed.controller.dispose();
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: rule.operator,
                        isExpanded: true,
                        dropdownColor: theme.cardTheme.color,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: theme.cardTheme.color,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.dividerColor)),
                        ),
                        items: _operators.map((op) {
                          return DropdownMenuItem(
                            value: op['value'],
                            child: Text(op['label']!),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => rule.operator = val ?? '=='),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: rule.controller,
                        decoration: InputDecoration(
                          hintText: 'Enter value...',
                          filled: true,
                          fillColor: theme.cardTheme.color,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.dividerColor)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  final defaultKey = widget.columns.isNotEmpty ? widget.columns.first.key : null;
                  _rules.add(_RuleDraft(columnKey: defaultKey, operator: '==', controller: TextEditingController()));
                }),
                icon: const Icon(Icons.add),
                label: const Text('Add Rule'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleDraft {
  String? columnKey;
  String operator;
  TextEditingController controller;

  _RuleDraft({
    required this.columnKey,
    required this.operator,
    required this.controller,
  });
}
