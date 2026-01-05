import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/schema_models.dart';
import '../services/auth_service.dart';
import '../services/drive_service.dart';
import '../theme/app_theme.dart';
import 'dynamic_form/dynamic_form_renderer.dart';

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: DynamicFormRenderer(
              columns: widget.tab.columns,
              data: _formData,
              primaryColor: widget.primaryColor,
              onFieldChanged: (key, value) {
                setState(() {
                  _formData[key] = value;
                });
              },
              controllers: _controllers,
              module: widget.module,
              settings: widget.settings,
            ),
          ),
        ),
      ),
    );
  }

  void _saveForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        if (authService.authClient == null) throw Exception("Not authenticated");
        
        if (widget.module == null) throw Exception("Module context missing");

        final driveService = DriveService(authService.authClient!);
        
        // Show loading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saving to Drive...'), duration: Duration(seconds: 1)),
          );
        }

        await driveService.saveRecord(
          widget.module!.id, // Module Folder ID
          widget.module!.name, // Spreadsheet Name (e.g. Inventory)
          widget.tab.id, // Sheet Name (e.g. items)
          _formData,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Record saved successfully')));
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
        }
      }
    }
  }

}
