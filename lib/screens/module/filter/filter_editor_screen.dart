import 'package:flutter/material.dart';
import '../../../models/schema_models.dart';
import '../../../theme/app_theme.dart';

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
  String? _selectedColumnKey;
  String _selectedOperator = '==';
  final TextEditingController _valueController = TextEditingController();

  final List<Map<String, String>> _operators = [
    {'label': 'Equals', 'value': '=='},
    {'label': 'Contains', 'value': 'contains'},
    {'label': 'Not Equals', 'value': '!='},
    {'label': 'Greater Than', 'value': '>'},
    {'label': 'Less Than', 'value': '<'},
    {'label': 'Starts With', 'value': 'startsWidth'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingFilter != null) {
      _selectedColumnKey = widget.existingFilter!.field;
      _selectedOperator = widget.existingFilter!.operator;
      _valueController.text = widget.existingFilter!.value;
    } else if (widget.columns.isNotEmpty) {
      _selectedColumnKey = widget.columns.first.key;
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  void _save() {
    if (_selectedColumnKey == null) return;
    
    final col = widget.columns.firstWhere((c) => c.key == _selectedColumnKey);
    final opLabel = _operators.firstWhere((element) => element['value'] == _selectedOperator)['label'];
    
    final filter = QuickFilter(
      label: '${col.label} $opLabel ${_valueController.text}', 
      key: widget.existingFilter?.key ?? 'custom_${DateTime.now().millisecondsSinceEpoch}', 
      field: _selectedColumnKey!, 
      operator: _selectedOperator,
      value: _valueController.text,
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
            Text('Column', style: TextStyle(fontSize: 14, color: theme.disabledColor)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedColumnKey,
              isExpanded: true,
              dropdownColor: theme.cardTheme.color,
              decoration: InputDecoration(
                filled: true,
                fillColor: theme.cardTheme.color,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.dividerColor)),
              ),
              items: widget.columns.map((col) {
                return DropdownMenuItem(
                  value: col.key,
                  child: Text(col.label, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => _selectedColumnKey = val);
              },
            ),
            const SizedBox(height: 24),
            
            Text('Operator', style: TextStyle(fontSize: 14, color: theme.disabledColor)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedOperator,
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
              onChanged: (val) {
                setState(() => _selectedOperator = val!);
              },
            ),
            const SizedBox(height: 24),

            Text('Value', style: TextStyle(fontSize: 14, color: theme.disabledColor)),
            const SizedBox(height: 8),
            TextField(
              controller: _valueController,
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
  }
}
