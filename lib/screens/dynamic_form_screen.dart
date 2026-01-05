import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/schema_models.dart';
import '../services/auth_service.dart';
import '../services/drive_service.dart';
import '../theme/app_theme.dart';

class DynamicFormScreen extends StatefulWidget {
  final TabConfig tab;
  final Color primaryColor;
  final Map<String, dynamic>? initialData;
  final Map<String, SettingItem> settings;
  final ModuleSchema? module;

  const DynamicFormScreen({
    super.key,
    required this.tab,
    required this.primaryColor,
    this.initialData,
    this.settings = const {},
    this.module,
  });

  @override
  State<DynamicFormScreen> createState() => _DynamicFormScreenState();
}

class _DynamicFormScreenState extends State<DynamicFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formData = {};
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    // Initialize form data and controllers
    for (var col in widget.tab.columns) {
      var initialValue = widget.initialData?[col.key];
      
      // Apply default value if no initial data and default exists
      if (initialValue == null && col.defaultValue != null) {
        initialValue = col.defaultValue;
      }

      _formData[col.key] = initialValue;
      
      if (col.type != 'image' && col.type != 'date' && col.type != 'list') {
        _controllers[col.key] = TextEditingController(text: initialValue?.toString() ?? '');
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
    final isEditing = widget.initialData != null;
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          isEditing ? 'EDIT ${widget.tab.label.toUpperCase()}' : 'NEW ${widget.tab.label.toUpperCase()}',
          style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 1.0),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saveForm,
            child: Text(
              'SAVE',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: widget.primaryColor,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: widget.tab.columns.length,
            separatorBuilder: (context, index) => const SizedBox(height: 24),
            itemBuilder: (context, index) {
              final column = widget.tab.columns[index];
              return _buildField(column);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildField(ColumnConfig column) {
    // Handle visibility based on dependsOn
    if (column.dependsOn != null) {
      bool isVisible = true;
      if (column.dependsOn!.startsWith('settings.')) {
        final settingKey = column.dependsOn!.split('.')[1];
        final setting = widget.settings[settingKey];
        // Check if setting exists and is false (assuming boolean dependency for now)
        if (setting != null && setting.value == false) {
          isVisible = false;
        }
      } else {
        // Depends on another field in the form
        final dependentValue = _formData[column.dependsOn];
        // If dependent value is null or false (for boolean), hide
        if (dependentValue == null || dependentValue == false) {
          isVisible = false;
        }
      }
      
      if (!isVisible) {
        return const SizedBox.shrink();
      }
    }

    switch (column.type.toLowerCase()) {
      case 'date':
        return _buildDatePicker(column);
      case 'image':
        return _buildImagePicker(column);
      case 'scanner':
        return _buildScanner(column);
      case 'signature':
        return _buildSignaturePad(column);
      case 'select':
      case 'dropdown':
        return _buildDropdown(column);
      case 'list':
        return _buildListEditor(column);
      case 'boolean':
        return _buildSwitch(column);
      case 'formula':
        return _buildFormulaField(column);
      case 'relation':
        return _buildRelationPicker(column);
      case 'number':
        return _buildTextField(column, isNumeric: true);
      case 'currency':
        return _buildTextField(column, isNumeric: true, isCurrency: true);
      case 'longtext':
        return _buildTextField(column, maxLines: 4);
      default:
        return _buildTextField(column);
    }
  }

  Widget _buildTextField(ColumnConfig column, {bool isNumeric = false, bool isCurrency = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          column.label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.secondaryTextColor,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _controllers[column.key],
          keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
          maxLines: maxLines,
          style: GoogleFonts.inter(color: AppTheme.textColor),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.surfaceColor,
            hintText: 'Enter ${column.label.toLowerCase()}',
            hintStyle: TextStyle(color: AppTheme.secondaryTextColor.withOpacity(0.5)),
            prefixText: isCurrency ? '\$ ' : null,
            prefixStyle: TextStyle(color: AppTheme.textColor, fontWeight: FontWeight.bold),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: widget.primaryColor),
            ),
          ),
          onChanged: (value) {
            // Trigger rebuild for formulas
            setState(() {});
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter ${column.label.toLowerCase()}';
            }
            return null;
          },
          onSaved: (value) => _formData[column.key] = value,
        ),
      ],
    );
  }

  Widget _buildDatePicker(ColumnConfig column) {
    final value = _formData[column.key] as String?;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          column.label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.secondaryTextColor,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.dark(
                      primary: widget.primaryColor,
                      onPrimary: AppTheme.backgroundColor,
                      surface: AppTheme.surfaceColor,
                      onSurface: AppTheme.textColor,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (date != null) {
              setState(() {
                _formData[column.key] = date.toIso8601String().split('T')[0];
              });
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.transparent),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, color: AppTheme.secondaryTextColor, size: 20),
                const SizedBox(width: 12),
                Text(
                  value ?? 'Select Date',
                  style: GoogleFonts.inter(
                    color: value != null ? AppTheme.textColor : AppTheme.secondaryTextColor.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePicker(ColumnConfig column) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          column.label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.secondaryTextColor,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.secondaryTextColor.withOpacity(0.2), style: BorderStyle.solid),
          ),
          child: InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Camera integration coming soon')));
            },
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt_rounded, size: 32, color: AppTheme.secondaryTextColor),
                const SizedBox(height: 8),
                Text(
                  'Tap to capture',
                  style: GoogleFonts.inter(color: AppTheme.secondaryTextColor),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScanner(ColumnConfig column) {
    final controller = _controllers[column.key];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          column.label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.secondaryTextColor,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                style: GoogleFonts.inter(color: AppTheme.textColor),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.surfaceColor,
                  hintText: 'Scan or enter code',
                  hintStyle: TextStyle(color: AppTheme.secondaryTextColor.withOpacity(0.5)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(Icons.qr_code, color: AppTheme.secondaryTextColor),
                ),
                onChanged: (val) => _formData[column.key] = val,
                onSaved: (val) => _formData[column.key] = val,
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: () {
                // Mock scanner action
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scanner started...')));
                // Simulate scan result
                setState(() {
                  final mockCode = 'SCAN-${DateTime.now().millisecondsSinceEpoch}';
                  controller?.text = mockCode;
                  _formData[column.key] = mockCode;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: widget.primaryColor),
                ),
                child: Icon(Icons.qr_code_scanner_rounded, color: widget.primaryColor),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSignaturePad(ColumnConfig column) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          column.label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.secondaryTextColor,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.secondaryTextColor.withOpacity(0.2)),
          ),
          child: InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signature pad coming soon')));
            },
            borderRadius: BorderRadius.circular(12),
            child: Center(
              child: Text(
                'Tap to sign',
                style: GoogleFonts.inter(color: AppTheme.secondaryTextColor),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRelationPicker(ColumnConfig column) {
    final currentValue = _formData[column.key];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          column.label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.secondaryTextColor,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            // If we have a module and the column specifies a related tab (via options)
            if (widget.module != null && column.options is String) {
              final relatedTabId = column.options as String;
              final relatedTab = widget.module!.tabs.firstWhere(
                (t) => t.id == relatedTabId, 
                orElse: () => widget.module!.tabs.first
              );
              
              // Fetch data for the related tab
              final authService = Provider.of<AuthService>(context, listen: false);
              if (authService.authClient != null) {
                final driveService = DriveService(authService.authClient!);
                // Show loading
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Loading items...'), duration: Duration(milliseconds: 500)));
                
                final items = await driveService.readSheet('Default Workspace', relatedTabId);
                
                if (mounted) {
                  // Show selection dialog
                  final selected = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Select ${relatedTab.label}'),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            // Try to find a meaningful label (first text column)
                            String label = item.values.first.toString();
                            // Or look for specific keys like 'name', 'item_name'
                            if (item.containsKey('item_name')) label = item['item_name'];
                            else if (item.containsKey('name')) label = item['name'];
                            
                            return ListTile(
                              title: Text(label),
                              onTap: () => Navigator.pop(context, label),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                  
                  if (selected != null) {
                    setState(() {
                      _formData[column.key] = selected;
                    });
                  }
                }
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entity lookup configuration missing')));
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.transparent),
            ),
            child: Row(
              children: [
                Icon(Icons.link_rounded, color: AppTheme.secondaryTextColor, size: 20),
                const SizedBox(width: 12),
                Text(
                  currentValue?.toString() ?? 'Select ${column.label}',
                  style: GoogleFonts.inter(
                    color: currentValue != null ? AppTheme.textColor : AppTheme.secondaryTextColor.withOpacity(0.5),
                  ),
                ),
                const Spacer(),
                Icon(Icons.arrow_drop_down_rounded, color: AppTheme.secondaryTextColor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _saveForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      try {
        // Save to DriveService (Mock for now)
        // We assume the sheet name is the tab ID for simplicity in this mock
        final sheetName = widget.tab.id;
        final authService = Provider.of<AuthService>(context, listen: false);
        if (authService.authClient == null) throw Exception("Not authenticated");
        final driveService = DriveService(authService.authClient!);
        
        // Read existing data
        final currentData = await driveService.readSheet('Default Workspace', sheetName);
        
        // Append new record
        currentData.add(_formData);
        
        // Write back
        await driveService.writeSheet('Default Workspace', sheetName, currentData);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Record saved to Drive')));
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
        }
      }
    }
  }

  Widget _buildSwitch(ColumnConfig column) {
    final value = _formData[column.key] == true;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              column.label,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.textColor,
              ),
            ),
          ),
          Switch(
            value: value,
            activeColor: widget.primaryColor,
            onChanged: (val) {
              setState(() {
                _formData[column.key] = val;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildListEditor(ColumnConfig column) {
    List<String> currentList = [];
    if (_formData[column.key] is List) {
      currentList = List<String>.from(_formData[column.key]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          column.label.toUpperCase(),
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
              ...currentList.map((e) => Chip(
                label: Text(e),
                backgroundColor: widget.primaryColor.withOpacity(0.1),
                labelStyle: TextStyle(color: widget.primaryColor),
                deleteIcon: Icon(Icons.close, size: 16, color: widget.primaryColor),
                onDeleted: () {
                  setState(() {
                    currentList.remove(e);
                    _formData[column.key] = currentList;
                  });
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
                      title: Text('Add ${column.label}'),
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
                              setState(() {
                                currentList.add(newVal);
                                _formData[column.key] = currentList;
                              });
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

  Widget _buildDropdown(ColumnConfig column) {
    List<dynamic> optionsList = [];
    if (column.options is List) {
      optionsList = column.options as List;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          column.label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.secondaryTextColor,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _formData[column.key],
          dropdownColor: AppTheme.surfaceColor,
          style: TextStyle(color: AppTheme.textColor),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          items: optionsList.map<DropdownMenuItem<String>>((opt) {
            final strVal = opt.toString();
            return DropdownMenuItem<String>(value: strVal, child: Text(strVal));
          }).toList(),
          onChanged: (val) {
            setState(() {
              _formData[column.key] = val;
            });
          },
        ),
      ],
    );
  }

  Widget _buildFormulaField(ColumnConfig column) {
    String value = '0.00';
    if (column.formula != null) {
      if (column.formula!.contains('*')) {
        final parts = column.formula!.split('*').map((e) => e.trim()).toList();
        if (parts.length == 2) {
          final key1 = parts[0];
          final key2 = parts[1];
          
          double val1 = double.tryParse(_controllers[key1]?.text ?? '') ?? 0;
          double val2 = double.tryParse(_controllers[key2]?.text ?? '') ?? 0;
          
          value = (val1 * val2).toStringAsFixed(2);
          _formData[column.key] = value;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          column.label.toUpperCase(),
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.secondaryTextColor.withOpacity(0.1)),
          ),
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor,
            ),
          ),
        ),
      ],
    );
  }
}
