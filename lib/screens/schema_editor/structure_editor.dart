import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/schema_models.dart';
import '../../theme/app_theme.dart';

class StructureEditor extends StatefulWidget {
  final List<TabConfig> tabs;
  final Map<String, dynamic>? rawSettings;
  final Function(List<TabConfig>) onTabsChanged;

  const StructureEditor({
    super.key,
    required this.tabs,
    required this.rawSettings,
    required this.onTabsChanged,
  });

  @override
  State<StructureEditor> createState() => _StructureEditorState();
}

class _StructureEditorState extends State<StructureEditor> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.tabs.length + 1,
      itemBuilder: (context, index) {
        if (index == widget.tabs.length) {
          return _buildAddButton('Add New Tab', () {
            _showAddTabDialog();
          });
        }
        return _buildTabEditorCard(widget.tabs[index]);
      },
    );
  }

  Widget _buildTabEditorCard(TabConfig tab) {
    return Card(
      color: AppTheme.surfaceColor,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        title: Text(tab.label, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppTheme.textColor)),
        subtitle: Text('${tab.columns.length} Columns', style: GoogleFonts.inter(color: AppTheme.secondaryTextColor)),
        iconColor: AppTheme.primaryColor,
        collapsedIconColor: AppTheme.secondaryTextColor,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ...tab.columns.map((col) => _buildColumnRow(tab, col)),
                const SizedBox(height: 16),
                _buildAddButton('Add Column', () {
                  _showAddColumnDialog(tab);
                }, isSmall: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnRow(TabConfig tab, ColumnConfig col) {
    final isHidden = col.hidden == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(_getIconForType(col.type), size: 16, color: AppTheme.secondaryTextColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              col.label, 
              style: GoogleFonts.inter(
                color: isHidden ? AppTheme.secondaryTextColor : AppTheme.textColor,
                decoration: isHidden ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (isHidden)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('HIDDEN', style: GoogleFonts.sourceCodePro(fontSize: 9, color: Colors.orange)),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.secondaryTextColor.withOpacity(0.3)),
            ),
            child: Text(col.type.toUpperCase(), style: GoogleFonts.sourceCodePro(fontSize: 10, color: AppTheme.secondaryTextColor)),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 16),
            color: AppTheme.primaryColor,
            onPressed: () {
              _showEditColumnDialog(tab, col);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            color: Colors.red,
            onPressed: () {
              _confirmDeleteColumn(tab, col);
            },
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'text': return Icons.text_fields;
      case 'number': return Icons.numbers;
      case 'date': return Icons.calendar_today;
      case 'select': return Icons.list;
      case 'formula': return Icons.functions;
      case 'scanner': return Icons.qr_code_scanner;
      case 'currency': return Icons.attach_money;
      case 'boolean': return Icons.check_box;
      case 'image': return Icons.image;
      default: return Icons.short_text;
    }
  }

  void _confirmDeleteColumn(TabConfig tab, ColumnConfig col) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text('Delete Column', style: TextStyle(color: AppTheme.textColor)),
        content: Text('Are you sure you want to delete "${col.label}"? This cannot be undone.', style: TextStyle(color: AppTheme.secondaryTextColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final newTabs = List<TabConfig>.from(widget.tabs);
              final tabIndex = newTabs.indexOf(tab);
              newTabs[tabIndex].columns.remove(col);
              widget.onTabsChanged(newTabs);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddTabDialog() {
    final labelController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text('Add New Tab', style: GoogleFonts.inter(color: AppTheme.textColor)),
        content: TextField(
          controller: labelController,
          style: TextStyle(color: AppTheme.textColor),
          decoration: const InputDecoration(labelText: 'Tab Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (labelController.text.isEmpty) return;
              
              final id = labelController.text.toLowerCase().replaceAll(' ', '_');
              final newTab = TabConfig(
                id: id,
                label: labelController.text,
                columns: [],
              );
              
              final newTabs = List<TabConfig>.from(widget.tabs);
              newTabs.add(newTab);
              
              widget.onTabsChanged(newTabs);
              Navigator.pop(context);
            }, 
            child: const Text('Add')
          ),
        ],
      ),
    );
  }

  void _showAddColumnDialog(TabConfig tab) {
    final labelController = TextEditingController();
    String currentType = 'text';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppTheme.surfaceColor,
            title: Text('Add Column', style: GoogleFonts.inter(color: AppTheme.textColor)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: labelController,
                    style: TextStyle(color: AppTheme.textColor),
                    decoration: const InputDecoration(labelText: 'Column Name'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: currentType,
                    dropdownColor: AppTheme.surfaceColor,
                    style: TextStyle(color: AppTheme.textColor),
                    items: {
                      'text', 'number', 'date', 'select', 'boolean', 'image', 'scanner', 'currency', 'formula', 'relation', 'table'
                    }
                        .map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase())))
                        .toList(),
                    onChanged: (val) {
                      setState(() => currentType = val!);
                    },
                    decoration: const InputDecoration(labelText: 'Data Type'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  if (labelController.text.isEmpty) return;
                  
                  final key = labelController.text.toLowerCase().replaceAll(' ', '_');
                  final newCol = ColumnConfig(
                    key: key,
                    label: labelController.text,
                    type: currentType,
                  );
                  
                  final newTabs = List<TabConfig>.from(widget.tabs);
                  final tabIndex = newTabs.indexOf(tab);
                  newTabs[tabIndex].columns.add(newCol);
                  
                  widget.onTabsChanged(newTabs);
                  Navigator.pop(context);
                }, 
                child: const Text('Add')
              ),
            ],
          );
        }
      ),
    );
  }

  void _showEditColumnDialog(TabConfig tab, ColumnConfig col) {
    final labelController = TextEditingController(text: col.label);
    String currentType = col.type;
    String? currentDependsOn = col.dependsOn;
    bool isHidden = col.hidden ?? false;
    
    // Handle options
    bool isDynamicOptions = false;
    List<String> staticOptions = [];
    String dynamicOptionPath = '';

    if (col.options is List) {
      staticOptions = List<String>.from(col.options);
    } else if (col.options is String) {
      isDynamicOptions = true;
      dynamicOptionPath = col.options;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppTheme.surfaceColor,
            title: Text('Edit Column', style: GoogleFonts.inter(color: AppTheme.textColor)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: labelController,
                    style: TextStyle(color: AppTheme.textColor),
                    decoration: const InputDecoration(labelText: 'Column Name'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: currentType,
                    dropdownColor: AppTheme.surfaceColor,
                    style: TextStyle(color: AppTheme.textColor),
                    items: {
                      'text', 'number', 'date', 'select', 'boolean', 'image', 'scanner', 'currency', 'formula', 'relation', 'table',
                      currentType // Ensure current value is always in the list
                    }
                        .map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase())))
                        .toList(),
                    onChanged: (val) {
                      setState(() => currentType = val!);
                    },
                    decoration: const InputDecoration(labelText: 'Data Type'),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text('Hidden (Don\'t show on form)', style: TextStyle(color: AppTheme.textColor)),
                    value: isHidden,
                    onChanged: (val) => setState(() => isHidden = val),
                    activeColor: AppTheme.primaryColor,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: currentDependsOn,
                    dropdownColor: AppTheme.surfaceColor,
                    style: TextStyle(color: AppTheme.textColor),
                    decoration: const InputDecoration(labelText: 'Depends On (Optional)'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      ...tab.columns
                          .where((c) => c.key != col.key) // Exclude self
                          .map((c) => DropdownMenuItem(value: c.key, child: Text(c.label))),
                      if (_getAvailableBooleanSettings().isNotEmpty) ...[
                         const DropdownMenuItem(value: '__divider__', enabled: false, child: Divider()),
                         const DropdownMenuItem(value: '__header__', enabled: false, child: Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                         ..._getAvailableBooleanSettings().map((s) => DropdownMenuItem(value: s, child: Text(s))),
                      ],
                      if (currentDependsOn != null && 
                          !tab.columns.any((c) => c.key == currentDependsOn) &&
                          !_getAvailableBooleanSettings().contains(currentDependsOn))
                        DropdownMenuItem(value: currentDependsOn, child: Text('$currentDependsOn (Missing)')),
                    ],
                    onChanged: (val) => setState(() => currentDependsOn = val),
                  ),
                  
                  if (currentType == 'select') ...[
                    const SizedBox(height: 24),
                    Text('Options Source', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.textColor)),
                    Row(
                      children: [
                        Expanded(child: RadioListTile<bool>(
                          title: Text('Static', style: TextStyle(color: AppTheme.textColor)),
                          value: false,
                          groupValue: isDynamicOptions,
                          onChanged: (v) => setState(() => isDynamicOptions = v!),
                          activeColor: AppTheme.primaryColor,
                          contentPadding: EdgeInsets.zero,
                        )),
                        Expanded(child: RadioListTile<bool>(
                          title: Text('Dynamic', style: TextStyle(color: AppTheme.textColor)),
                          value: true,
                          groupValue: isDynamicOptions,
                          onChanged: (v) => setState(() => isDynamicOptions = v!),
                          activeColor: AppTheme.primaryColor,
                          contentPadding: EdgeInsets.zero,
                        )),
                      ],
                    ),
                    
                    if (isDynamicOptions)
                      DropdownButtonFormField<String>(
                        value: _getAvailableListSettings().contains(dynamicOptionPath.replaceFirst('settings.', '')) 
                            ? dynamicOptionPath.replaceFirst('settings.', '') 
                            : null,
                        dropdownColor: AppTheme.surfaceColor,
                        style: TextStyle(color: AppTheme.textColor),
                        items: _getAvailableListSettings().map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (val) => setState(() => dynamicOptionPath = val != null ? 'settings.$val' : ''),
                        decoration: const InputDecoration(labelText: 'Select Setting List'),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            children: [
                              ...staticOptions.map((opt) => Chip(
                                label: Text(opt),
                                onDeleted: () => setState(() => staticOptions.remove(opt)),
                              )),
                              ActionChip(
                                label: const Icon(Icons.add, size: 16),
                                onPressed: () {
                                  _showAddOptionDialog(context, (newOpt) {
                                    setState(() => staticOptions.add(newOpt));
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
                  // Save logic
                  final newCol = ColumnConfig(
                    key: col.key,
                    label: labelController.text,
                    type: currentType,
                    dependsOn: currentDependsOn,
                    hidden: isHidden,
                    options: currentType == 'select' 
                        ? (isDynamicOptions ? dynamicOptionPath : staticOptions)
                        : null,
                  );
                  
                  // Update state
                  final newTabs = List<TabConfig>.from(widget.tabs);
                  final tabIndex = newTabs.indexOf(tab);
                  final colIndex = newTabs[tabIndex].columns.indexOf(col);
                  newTabs[tabIndex].columns[colIndex] = newCol;
                  
                  widget.onTabsChanged(newTabs);
                  
                  Navigator.pop(context);
                }, 
                child: const Text('Save')
              ),
            ],
          );
        }
      ),
    );
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

  Widget _buildAddButton(String label, VoidCallback onTap, {bool isSmall = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: isSmall ? 12 : 16),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.secondaryTextColor.withOpacity(0.3), style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: AppTheme.secondaryTextColor, size: isSmall ? 16 : 24),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.inter(color: AppTheme.secondaryTextColor, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
