import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../models/schema_models.dart';
import '../../../services/auth_service.dart';
import '../../../services/drive_service.dart';
import '../../../theme/app_theme.dart';

class DynamicDropdownField extends StatefulWidget {
  final ColumnConfig column;
  final String? value;
  final Function(String?) onChanged;
  final Map<String, dynamic> data;
  final ModuleSchema? module;

  const DynamicDropdownField({
    super.key,
    required this.column,
    required this.value,
    required this.onChanged,
    required this.data,
    this.module,
  });

  @override
  State<DynamicDropdownField> createState() => _DynamicDropdownFieldState();
}

class _DynamicDropdownFieldState extends State<DynamicDropdownField> {
  List<String> _options = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void didUpdateWidget(DynamicDropdownField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload options if dependencies change
    if (widget.column.options is String && 
        (widget.column.options as String).contains('.')) {
       final parts = (widget.column.options as String).split('.');
       if (parts.length == 2 && parts[0] != 'settings') {
         final dependencyKey = parts[0];
         if (widget.data[dependencyKey] != oldWidget.data[dependencyKey]) {
           _loadOptions();
         }
       }
    }
  }

  Future<void> _loadOptions() async {
    if (widget.column.options is List) {
      setState(() {
        _options = (widget.column.options as List).map((e) => e.toString()).toList();
      });
      return;
    }

    if (widget.column.options is String) {
      final optionString = widget.column.options as String;
      
      // Handle settings dependency
      if (optionString.startsWith('settings.')) {
        // This is handled by the renderer passing settings, but here we might need to access it differently
        // For now, assuming settings are static or passed down. 
        // Actually, the renderer filters visibility based on settings.
        // If the options themselves come from settings (like a list in settings), we need access to settings.
        // But we don't have settings here. 
        // Let's assume for now simple list or dynamic lookup.
        return; 
      }

      // Handle dynamic lookup: "field.property"
      if (optionString.contains('.')) {
        final parts = optionString.split('.');
        if (parts.length == 2) {
          final targetFieldKey = parts[0];
          final targetProperty = parts[1];
          
          final targetValue = widget.data[targetFieldKey];
          if (targetValue == null || targetValue.toString().isEmpty) {
            setState(() => _options = []);
            return;
          }

          // We need to find which Tab the targetFieldKey refers to.
          // We can't easily know the schema of the target field here without searching the whole module.
          if (widget.module == null) return;

          // Find the column config for targetFieldKey in the current context?
          // We don't have the full list of columns here, only this column.
          // But we can search the module tabs to find where this field might be defined?
          // No, we need to know the configuration of 'targetFieldKey' to know its 'options' (which is the Tab ID).
          
          // Heuristic: Search all tabs in the module for a column with key == targetFieldKey
          String? relatedTabId;
          
          for (var tab in widget.module!.tabs) {
            // Search in tab columns
            final col = _findColumn(tab.columns, targetFieldKey);
            if (col != null && col.type == 'relation') {
              relatedTabId = col.options as String?;
              break;
            }
            // Also search in table columns
            for (var c in tab.columns) {
              if (c.type == 'table' && c.columns != null) {
                 final subCol = _findColumn(c.columns!, targetFieldKey);
                 if (subCol != null && subCol.type == 'relation') {
                   relatedTabId = subCol.options as String?;
                   break;
                 }
              }
            }
            if (relatedTabId != null) break;
          }

          if (relatedTabId != null) {
            setState(() => _isLoading = true);
            try {
              final authService = Provider.of<AuthService>(context, listen: false);
              if (authService.authClient != null) {
                final driveService = DriveService(authService.authClient!);
                final records = await driveService.fetchRecords(widget.module!.id, widget.module!.name, relatedTabId);
                
                // Find the record where the first value (or name) matches targetValue
                final record = records.firstWhere(
                  (r) => r.values.first.toString() == targetValue || r['name'] == targetValue || r['item_name'] == targetValue,
                  orElse: () => {},
                );

                if (record.isNotEmpty && record.containsKey(targetProperty)) {
                  final propValue = record[targetProperty];
                  if (propValue is String) {
                    // Try to parse if it looks like a list
                    if (propValue.startsWith('[') && propValue.endsWith(']')) {
                       // It's a stringified list, we might need to parse it.
                       // For now, let's assume it's a simple comma separated or we need a JSON parser.
                       // But fetchRecords returns Map<String, dynamic>. 
                       // If the sheet stored it as JSON string, we need to decode.
                       // But fetchRecords in DriveService currently just returns values.
                       // If it was stored as JSON string in the sheet, it comes back as string.
                       // Let's try to strip brackets and split.
                       final clean = propValue.substring(1, propValue.length - 1);
                       setState(() {
                         _options = clean.split(',').map((e) => e.trim().replaceAll('"', '')).toList();
                       });
                    } else {
                       setState(() => _options = [propValue]);
                    }
                  } else if (propValue is List) {
                    setState(() {
                      _options = propValue.map((e) => e.toString()).toList();
                    });
                  }
                } else {
                  setState(() => _options = []);
                }
              }
            } catch (e) {
              print('Error loading dynamic options: $e');
            } finally {
              if (mounted) setState(() => _isLoading = false);
            }
          }
        }
      }
    }
  }

  ColumnConfig? _findColumn(List<ColumnConfig> columns, String key) {
    for (var col in columns) {
      if (col.key == key) return col;
      if (col.columns != null) {
        final found = _findColumn(col.columns!, key);
        if (found != null) return found;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.column.label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.secondaryTextColor,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        _isLoading 
          ? const LinearProgressIndicator()
          : DropdownButtonFormField<String>(
          value: _options.contains(widget.value) ? widget.value : null,
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
          items: _options.map<DropdownMenuItem<String>>((opt) {
            return DropdownMenuItem(
              value: opt,
              child: Text(opt),
            );
          }).toList(),
          onChanged: widget.onChanged,
        ),
      ],
    );
  }
}
