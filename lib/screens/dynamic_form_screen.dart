import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/schema_models.dart';
import '../providers/drive_provider.dart';
import '../providers/sync_provider.dart';
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
      
      // Update: Don't exclude 'list' (and potentially other types like 'table') if they need text controllers
      // But typically, 'list' handles its own state. 
      // The issue is likely that fields backed by controllers update the controller but NOT the _formData
      // unless onFieldChanged is explicitly called.
      // For TextFields, we usually listen to controller changes or use onChanged.
      
      if (col.type != 'image' && col.type != 'date' && col.type != 'list' && col.type != 'boolean' && col.type != 'table') {
        final ctrl = TextEditingController(text: initialValue?.toString() ?? '');
        ctrl.addListener(() {
          _formData[col.key] = ctrl.text;
        });
        _controllers[col.key] = ctrl;
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
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          isEditing ? 'EDIT ${widget.tab.label.toUpperCase()}' : 'NEW ${widget.tab.label.toUpperCase()}',
          style: AppTheme.inter(fontWeight: FontWeight.w900, letterSpacing: 1.0, color: theme.textTheme.titleLarge?.color),
        ),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: theme.iconTheme,
        actions: [
          TextButton(
            onPressed: _saveForm,
            child: Text(
              'SAVE',
              style: AppTheme.inter(
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
        final driveProvider = Provider.of<DriveProvider>(context, listen: false);
        final syncProvider = Provider.of<SyncProvider>(context, listen: false);
        
        if (widget.module == null) throw Exception("Module context missing");

        // Try direct save if online
        if (driveProvider.driveService != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Saving to Drive...'), duration: Duration(seconds: 1)),
            );
          }

          try {
            await driveProvider.driveService!.saveRecord(
              widget.module!.id,
              widget.module!.name,
              widget.tab.id,
              _formData,
            );
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Record saved successfully')));
              Navigator.pop(context);
            }
            return;
          } catch (e) {
            // Direct save failed, fallback to queue
          }
        }

        // Fallback to queue if offline or direct save failed
        syncProvider.addToQueue(
          widget.module!.id,
          widget.module!.name,
          widget.tab.id,
          _formData,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Offline: Record added to sync queue')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

}
