import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/schema_models.dart';
import '../../../theme/app_theme.dart';

class EditColumnDialog extends StatefulWidget {
  final ColumnConfig column;
  final TabConfig tab;
  final Map<String, dynamic>? rawSettings;

  const EditColumnDialog({
    super.key,
    required this.column,
    required this.tab,
    this.rawSettings,
  });

  @override
  State<EditColumnDialog> createState() => _EditColumnDialogState();
}

class _EditColumnDialogState extends State<EditColumnDialog> {
  late TextEditingController _labelController;
  late String _currentType;
  String? _currentDependsOn;
  late bool _isHidden;
  
  bool _isDynamicOptions = false;
  List<String> _staticOptions = [];
  String _dynamicOptionPath = '';

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.column.label);
    _currentType = widget.column.type;
    _currentDependsOn = widget.column.dependsOn;
    _isHidden = widget.column.hidden ?? false;

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
    return AlertDialog(
      backgroundColor: AppTheme.surfaceColor,
      title: Text('Edit Column', style: GoogleFonts.inter(color: AppTheme.textColor)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _labelController,
              style: TextStyle(color: AppTheme.textColor),
              decoration: const InputDecoration(labelText: 'Column Name'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _currentType,
              dropdownColor: AppTheme.surfaceColor,
              style: TextStyle(color: AppTheme.textColor),
              items: {
                'text', 'number', 'date', 'select', 'boolean', 'image', 'scanner', 'currency', 'formula', 'relation', 'table',
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
              title: Text('Hidden (Don\'t show on form)', style: TextStyle(color: AppTheme.textColor)),
              value: _isHidden,
              onChanged: (val) => setState(() => _isHidden = val),
              activeColor: AppTheme.primaryColor,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _currentDependsOn,
              dropdownColor: AppTheme.surfaceColor,
              style: TextStyle(color: AppTheme.textColor),
              decoration: const InputDecoration(labelText: 'Depends On (Optional)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                ...widget.tab.columns
                    .where((c) => c.key != widget.column.key)
                    .map((c) => DropdownMenuItem(value: c.key, child: Text(c.label))),
                if (_getAvailableBooleanSettings().isNotEmpty) ...[
                   const DropdownMenuItem(value: '__divider__', enabled: false, child: Divider()),
                   const DropdownMenuItem(value: '__header__', enabled: false, child: Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                   ..._getAvailableBooleanSettings().map((s) => DropdownMenuItem(value: s, child: Text(s))),
                ],
                if (_currentDependsOn != null && 
                    !widget.tab.columns.any((c) => c.key == _currentDependsOn) &&
                    !_getAvailableBooleanSettings().contains(_currentDependsOn))
                  DropdownMenuItem(value: _currentDependsOn, child: Text('$_currentDependsOn (Missing)')),
              ],
              onChanged: (val) => setState(() => _currentDependsOn = val),
            ),
            
            if (_currentType == 'select') ...[
              const SizedBox(height: 24),
              Text('Options Source', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.textColor)),
              Row(
                children: [
                  Expanded(child: RadioListTile<bool>(
                    title: Text('Static', style: TextStyle(color: AppTheme.textColor)),
                    value: false,
                    groupValue: _isDynamicOptions,
                    onChanged: (v) => setState(() => _isDynamicOptions = v!),
                    activeColor: AppTheme.primaryColor,
                    contentPadding: EdgeInsets.zero,
                  )),
                  Expanded(child: RadioListTile<bool>(
                    title: Text('Dynamic', style: TextStyle(color: AppTheme.textColor)),
                    value: true,
                    groupValue: _isDynamicOptions,
                    onChanged: (v) => setState(() => _isDynamicOptions = v!),
                    activeColor: AppTheme.primaryColor,
                    contentPadding: EdgeInsets.zero,
                  )),
                ],
              ),
              
              if (_isDynamicOptions)
                DropdownButtonFormField<String>(
                  value: _getAvailableListSettings().contains(_dynamicOptionPath.replaceFirst('settings.', '')) 
                      ? _dynamicOptionPath.replaceFirst('settings.', '') 
                      : null,
                  dropdownColor: AppTheme.surfaceColor,
                  style: TextStyle(color: AppTheme.textColor),
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
              key: widget.column.key,
              label: _labelController.text,
              type: _currentType,
              dependsOn: _currentDependsOn,
              hidden: _isHidden,
              options: _currentType == 'select' 
                  ? (_isDynamicOptions ? _dynamicOptionPath : _staticOptions)
                  : null,
            );
            
            Navigator.pop(context, newCol);
          }, 
          child: const Text('Save')
        ),
      ],
    );
  }
}
