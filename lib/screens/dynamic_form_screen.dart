import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/schema_models.dart';
import '../services/drive_service.dart';
import '../theme/app_theme.dart';

class DynamicFormScreen extends StatefulWidget {
  final TabConfig tab;
  final Color primaryColor;
  final Map<String, dynamic>? initialData;

  const DynamicFormScreen({
    super.key,
    required this.tab,
    required this.primaryColor,
    this.initialData,
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
      final initialValue = widget.initialData?[col.key];
      _formData[col.key] = initialValue;
      
      if (col.type != 'image' && col.type != 'date') {
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
      case 'formula':
        return _buildFormulaField(column);
      case 'relation':
        return _buildRelationPicker(column);
      case 'number':
      case 'currency':
        return _buildTextField(column, isNumeric: true);
      case 'longtext':
        return _buildTextField(column, maxLines: 4);
      default:
        return _buildTextField(column);
    }
  }

  Widget _buildTextField(ColumnConfig column, {bool isNumeric = false, int maxLines = 1}) {
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
          height: 80,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.secondaryTextColor.withOpacity(0.2)),
          ),
          child: InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scanner integration coming soon')));
            },
            borderRadius: BorderRadius.circular(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_scanner_rounded, size: 24, color: AppTheme.secondaryTextColor),
                const SizedBox(width: 12),
                Text(
                  'Scan Barcode/QR',
                  style: GoogleFonts.inter(color: AppTheme.secondaryTextColor),
                ),
              ],
            ),
          ),
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
          onTap: () {
            // TODO: Implement Entity Lookup
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entity lookup coming soon')));
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.link_rounded, color: AppTheme.secondaryTextColor, size: 20),
                const SizedBox(width: 12),
                Text(
                  'Select ${column.label}',
                  style: GoogleFonts.inter(
                    color: AppTheme.secondaryTextColor.withOpacity(0.5),
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
        final driveService = DriveService();
        
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

  Widget _buildDropdown(ColumnConfig column) {
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
          items: (column.options ?? []).map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
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
