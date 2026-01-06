import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../models/schema_models.dart';
import '../../../providers/drive_provider.dart';
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
  bool _isVisible = true;
  String _label = '';

  @override
  void initState() {
    super.initState();
    _label = widget.column.label;
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
          if (widget.module == null) {
             return;
          }

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
              final driveService = Provider.of<DriveProvider>(context, listen: false).driveService;
              if (driveService != null) {
                final records = await driveService.fetchRecords(widget.module!.id, widget.module!.name, relatedTabId);
                
                // Find the record where the first value (or name) matches targetValue
                final record = records.firstWhere(
                  (r) {
                    final val = targetValue.toString().toLowerCase().trim();
                    final first = r.values.first.toString().toLowerCase().trim();
                    final name = r['name']?.toString().toLowerCase().trim();
                    final itemName = r['item_name']?.toString().toLowerCase().trim();
                    
                    return first == val || name == val || itemName == val;
                  },
                  orElse: () => {},
                );

                // Check for generic dependency logic based on target column schema
                final relatedTab = widget.module!.tabs.firstWhere(
                  (t) => t.id == relatedTabId, 
                  orElse: () => widget.module!.tabs.first
                );
                final targetColumn = _findColumn(relatedTab.columns, targetProperty);

                if (targetColumn?.dependsOn != null) {
                   final dependencyKey = targetColumn!.dependsOn!;
                   if (record.containsKey(dependencyKey)) {
                     final depValue = record[dependencyKey];
                     bool isActive = true;
                     if (depValue is bool) {
                       isActive = depValue;
                     } else if (depValue is String) {
                       isActive = depValue.toLowerCase() == 'true';
                     } else if (depValue == null) {
                       isActive = false;
                     }
                     
                     if (!isActive) {
                       setState(() {
                         _options = [];
                         _isVisible = false;
                       });
                       return;
                     }
                   }
                }
                
                // Update label if dynamicLabel is configured
                if (widget.column.dynamicLabel != null && widget.column.dynamicLabel!.contains('.')) {
                   final parts = widget.column.dynamicLabel!.split('.');
                   if (parts.length == 2) {
                     final labelProperty = parts[1];
                     
                     // Case-insensitive key lookup
                     final key = record.keys.firstWhere(
                       (k) => k.toLowerCase() == labelProperty.toLowerCase(),
                       orElse: () => '',
                     );

                     if (key.isNotEmpty) {
                        final val = record[key];
                        if (val != null && val.toString().isNotEmpty) {
                          setState(() => _label = val.toString());
                        } else {
                          setState(() => _label = widget.column.label);
                        }
                     } else {
                       setState(() => _label = widget.column.label);
                     }
                   }
                } else {
                   setState(() => _label = widget.column.label);
                }
                
                setState(() => _isVisible = true);

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
              debugPrint('Error loading dynamic options: $e');
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
    if (!_isVisible) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _label.toUpperCase(),
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
          initialValue: _options.contains(widget.value) ? widget.value : null,
          dropdownColor: AppTheme.surfaceColor,
          style: const TextStyle(color: AppTheme.textColor),
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
