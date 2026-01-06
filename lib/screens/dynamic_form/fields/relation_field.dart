import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../models/schema_models.dart';
import '../../../services/auth_service.dart';
import '../../../services/drive_service.dart';
import '../../../theme/app_theme.dart';

class DynamicRelationField extends StatefulWidget {
  final ColumnConfig column;
  final String? value;
  final ModuleSchema? module;
  final Function(String) onChanged;
  final Map<String, dynamic> data;

  const DynamicRelationField({
    super.key,
    required this.column,
    required this.value,
    required this.module,
    required this.onChanged,
    required this.data,
  });

  @override
  State<DynamicRelationField> createState() => _DynamicRelationFieldState();
}

class _DynamicRelationFieldState extends State<DynamicRelationField> {
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
        InkWell(
          onTap: () async {
            // Check dependency first
            if (widget.column.dependsOn != null) {
              final parentKey = widget.column.dependsOn!;
              // Check if it's a field dependency (not settings)
              if (!parentKey.startsWith('settings.')) {
                 final parentValue = widget.data[parentKey];
                 if (parentValue == null || parentValue.toString().isEmpty) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select a value for $parentKey first')));
                   return;
                 }
              }
            }

            // If we have a module and the column specifies a related tab (via options)
            if (widget.module != null && widget.column.options is String) {
              final relatedTabId = widget.column.options as String;
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
                
                var items = await driveService.fetchRecords(widget.module!.id, widget.module!.name, relatedTabId);
                
                if (!mounted) return;

                // Filter items if dependency exists
                if (widget.column.dependsOn != null && !widget.column.dependsOn!.startsWith('settings.')) {
                   final parentKey = widget.column.dependsOn!;
                   final parentValue = widget.data[parentKey];
                   
                   // Filter items where item[parentKey] == parentValue
                   items = items.where((item) => item[parentKey]?.toString() == parentValue?.toString()).toList();
                }

                // Show selection dialog
                if (!mounted) return;
                final selected = await showDialog<String>(
                  context: this.context,
                  builder: (context) => AlertDialog(
                    title: Text('Select ${relatedTab.label}'),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: items.isEmpty 
                        ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('No items found matching selection'),
                          )
                        : ListView.builder(
                        shrinkWrap: true,
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          // Try to find a meaningful label (first text column)
                          String label = item.values.first.toString();
                          // Or look for specific keys like 'name', 'item_name'
                          if (item.containsKey('item_name')) {
                            label = item['item_name'];
                          } else if (item.containsKey('name')) {
                            label = item['name'];
                          }
                          
                          return ListTile(
                            title: Text(label),
                            onTap: () => Navigator.pop(context, label),
                          );
                        },
                      ),
                    ),
                  ),
                );
                
                if (selected != null && mounted) {
                  widget.onChanged(selected);
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
                const Icon(Icons.link_rounded, color: AppTheme.secondaryTextColor, size: 20),
                const SizedBox(width: 12),
                Text(
                  widget.value?.toString() ?? 'Select ${widget.column.label}',
                  style: GoogleFonts.inter(
                    color: widget.value != null ? AppTheme.textColor : AppTheme.secondaryTextColor.withValues(alpha: 0.5),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.secondaryTextColor),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
