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

  const DynamicRelationField({
    super.key,
    required this.column,
    required this.value,
    required this.module,
    required this.onChanged,
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
                
                final items = await driveService.fetchRecords(widget.module!.id, widget.module!.name, relatedTabId);
                
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
                    widget.onChanged(selected);
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
                  widget.value?.toString() ?? 'Select ${widget.column.label}',
                  style: GoogleFonts.inter(
                    color: widget.value != null ? AppTheme.textColor : AppTheme.secondaryTextColor.withOpacity(0.5),
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
}
