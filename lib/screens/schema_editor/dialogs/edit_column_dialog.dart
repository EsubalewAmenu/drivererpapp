import 'package:flutter/material.dart';
import '../../../models/schema_models.dart';
import '../../../theme/app_theme.dart';

class EditColumnDialog extends StatefulWidget {
  final ColumnConfig column;
  final TabConfig? tab;
  final List<ColumnConfig>? siblingColumns;
  final Map<String, dynamic>? rawSettings;

  const EditColumnDialog({
    super.key,
    required this.column,
    this.tab,
    this.siblingColumns,
    this.rawSettings,
  }) : assert(tab != null || siblingColumns != null, 'Either tab or siblingColumns must be provided');

  @override
  State<EditColumnDialog> createState() => _EditColumnDialogState();
}

class _EditColumnDialogState extends State<EditColumnDialog> {
  late TextEditingController _labelController;
  late TextEditingController _keyController;
  late String _currentType;
  String? _currentDependsOn;
  late bool _isHidden;
  late bool _isRequired;
  String _currencySymbol = '\$';
  
  bool _isDynamicOptions = false;
  List<String> _staticOptions = [];
  String _dynamicOptionPath = '';

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.column.label);
    _keyController = TextEditingController(text: widget.column.key);
    _currentType = widget.column.type;
    _currentDependsOn = widget.column.dependsOn;
    _isHidden = widget.column.hidden ?? false;
    _isRequired = widget.column.isRequired ?? false;
    _currencySymbol = widget.column.currencySymbol ?? '\$';

    if (widget.column.options is List) {
      _staticOptions = List<String>.from(widget.column.options);
    } else if (widget.column.options is String) {
      _isDynamicOptions = true;
      _dynamicOptionPath = widget.column.options;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  List<String> _getAvailableListSettings() {
    if (widget.rawSettings == null) return [];
    return widget.rawSettings!.entries
        .where((e) => (e.value as Map)['type'] == 'list')
        .map((e) => e.key)
        .toList();
  }

  List<String> _getAvailableBooleanSettings() {
    if (widget.rawSettings == null) return [];
    return widget.rawSettings!.entries
        .where((e) => (e.value as Map)['type'] == 'boolean')
        .map((e) => 'settings.${e.key}')
        .toList();
  }
  
  List<ColumnConfig> _getSiblingColumns() {
    return widget.siblingColumns ?? widget.tab?.columns ?? [];
  }

  void _showAddOptionDialog(BuildContext context, Function(String) onAdd) {
    String val = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Option'),
        content: TextField(
          autofocus: true,
          onChanged: (v) => val = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Add')),
        ],
      ),
    ).then((_) {
      if (val.isNotEmpty) onAdd(val);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      backgroundColor: theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
      title: Text('Edit Column', style: AppTheme.inter(color: theme.textTheme.titleLarge?.color)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _labelController,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: const InputDecoration(labelText: 'Column Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _keyController,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: const InputDecoration(
                labelText: 'Column Key',
                helperText: 'Unique ID used in spreadsheet and formulas.',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _currentType,
              dropdownColor: theme.cardTheme.color,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              items: {
                'text', 'number', 'date', 'select', 'boolean', 'image', 'scanner', 'currency', 'formula', 'relation', 'table', 'email', 'phone',
                _currentType
              }
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase())))
                  .toList(),
              onChanged: (val) {
                setState(() => _currentType = val!);
              },
              decoration: const InputDecoration(labelText: 'Data Type'),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text('Is Required', style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
              value: _isRequired,
              onChanged: (val) => setState(() => _isRequired = val),
              activeColor: theme.primaryColor,
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: Text('Hidden (Don\'t show on form)', style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
              value: _isHidden,
              onChanged: (val) => setState(() => _isHidden = val),
              activeThumbColor: theme.primaryColor,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _currentDependsOn,
              dropdownColor: theme.cardTheme.color,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: const InputDecoration(labelText: 'Depends On (Optional)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                ..._getSiblingColumns()
                    .where((c) => c.key != widget.column.key)
                    .map((c) => DropdownMenuItem(value: c.key, child: Text(c.label))),
                if (_getAvailableBooleanSettings().isNotEmpty) ...[
                   const DropdownMenuItem(value: '__divider__', enabled: false, child: Divider()),
                   const DropdownMenuItem(value: '__header__', enabled: false, child: Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                   ..._getAvailableBooleanSettings().map((s) => DropdownMenuItem(value: s, child: Text(s))),
                ],
                if (_currentDependsOn != null && 
                    !_getSiblingColumns().any((c) => c.key == _currentDependsOn) &&
                    !_getAvailableBooleanSettings().contains(_currentDependsOn))
                  DropdownMenuItem(value: _currentDependsOn, child: Text('$_currentDependsOn (Missing)')),
              ],
              onChanged: (val) => setState(() => _currentDependsOn = val),
            ),
            
            if (_currentType == 'table') ...[
              const SizedBox(height: 24),
              Text('Table Structure', style: AppTheme.inter(fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
              const SizedBox(height: 8),
              if ((widget.column.columns ?? []).isEmpty)
                  Text('No columns defined. Save this dialog and use the "Add Sub-Column" button in the list view to add columns.', style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 13))
              else
                 Wrap(
                    spacing: 8,
                    children: (widget.column.columns!).map((c) => Chip(
                      label: Text(c.label),
                      backgroundColor: theme.scaffoldBackgroundColor,
                      labelStyle: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    )).toList(),
                 ),
               const SizedBox(height: 8),
                Text('NOTE: Use the arrow in the main list to expand this table and edit its columns.', style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 11, fontStyle: FontStyle.italic)),
            ],

            if (_currentType == 'currency') ...[
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                initialValue: _currencySymbol,
                dropdownColor: theme.cardTheme.color,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                decoration: const InputDecoration(labelText: 'Currency Symbol'),
                items: const [
                  DropdownMenuItem(value: '\$', child: Text('USD (\$)')),
                  DropdownMenuItem(value: '€', child: Text('EUR (€)')),
                  DropdownMenuItem(value: '£', child: Text('GBP (£)')),
                  DropdownMenuItem(value: 'Br', child: Text('ETB (Br)')),
                  DropdownMenuItem(value: '¥', child: Text('JPY/CNY (¥)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _currencySymbol = val);
                },
              ),
            ],

            if (_currentType == 'select') ...[
              const SizedBox(height: 24),
              Text('Options Source', style: AppTheme.inter(fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
              Row(
                children: [
                  Expanded(child: RadioListTile<bool>(
                    title: Text('Static', style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
                    value: false,
                    groupValue: _isDynamicOptions,
                    onChanged: (v) => setState(() => _isDynamicOptions = v!),
                    activeColor: theme.primaryColor,
                    contentPadding: EdgeInsets.zero,
                  )),
                  Expanded(child: RadioListTile<bool>(
                    title: Text('Dynamic', style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
                    value: true,
                    groupValue: _isDynamicOptions,
                    onChanged: (v) => setState(() => _isDynamicOptions = v!),
                    activeColor: theme.primaryColor,
                    contentPadding: EdgeInsets.zero,
                  )),
                ],
              ),
              
              if (_isDynamicOptions)
                DropdownButtonFormField<String>(
                  initialValue: _getAvailableListSettings().contains(_dynamicOptionPath.replaceFirst('settings.', '')) 
                      ? _dynamicOptionPath.replaceFirst('settings.', '') 
                      : null,
                  dropdownColor: theme.cardTheme.color,
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  items: _getAvailableListSettings().map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) => setState(() => _dynamicOptionPath = val != null ? 'settings.$val' : ''),
                  decoration: const InputDecoration(labelText: 'Select Setting List'),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        ..._staticOptions.map((opt) => Chip(
                          label: Text(opt),
                          backgroundColor: theme.scaffoldBackgroundColor,
                          labelStyle: TextStyle(color: theme.textTheme.bodyLarge?.color),
                          onDeleted: () => setState(() => _staticOptions.remove(opt)),
                        )),
                        ActionChip(
                          label: const Icon(Icons.add, size: 16),
                          onPressed: () {
                            _showAddOptionDialog(context, (newOpt) {
                              setState(() => _staticOptions.add(newOpt));
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                )
            ]
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            final newCol = ColumnConfig(
              key: _keyController.text,
              label: _labelController.text,
              type: _currentType,
              dependsOn: _currentDependsOn,
              hidden: _isHidden,
              isRequired: _isRequired,
              currencySymbol: _currentType == 'currency' ? _currencySymbol : null,
              options: _currentType == 'select' 
                  ? (_isDynamicOptions ? _dynamicOptionPath : _staticOptions)
                  : null,
              columns: widget.column.columns,
            );
            
            Navigator.pop(context, newCol);
          }, 
          child: const Text('Save')
        ),
      ],
    );
  }
}
