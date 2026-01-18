import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/schema_models.dart';
import '../../../providers/drive_provider.dart';
import '../../../providers/schema_provider.dart';
import '../../../providers/workspace_provider.dart';
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.column.label.toUpperCase(),
          style: AppTheme.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: theme.textTheme.bodyMedium?.color,
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

            // If column.options is a String, interpret it as a related tab id or module key
            if (widget.column.options is String) {
              final relatedTabId = widget.column.options as String;
              final driveService = Provider.of<DriveProvider>(context, listen: false).driveService;
              final schemaProvider = Provider.of<SchemaProvider>(context, listen: false);

              // Helper to show items in dialog
              Future<void> _showItemsDialog(List<Map<String, dynamic>> items, String title) async {
                if (!mounted) return;
                final selected = await showDialog<String>(
                  context: this.context,
                  builder: (context) => AlertDialog(
                    title: Text('Select $title'),
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
                          String label = item.values.first.toString();
                          if (item.containsKey('item_name')) {
                            label = item['item_name']?.toString() ?? label;
                          } else if (item.containsKey('name')) {
                            label = item['name']?.toString() ?? label;
                          }
                          final recordId = item['record_id']?.toString() ?? item['id']?.toString();
                          return ListTile(
                            title: Text(label),
                            onTap: () => Navigator.pop(context, recordId ?? label),
                          );
                        },
                      ),
                    ),
                  ),
                );
                if (selected != null && mounted) widget.onChanged(selected);
              }

              // First, try to resolve relatedTab within the current module (backwards compatible)
              if (widget.module != null) {
                try {
                  final relatedTab = widget.module!.tabs.firstWhere((t) => t.id == relatedTabId);
                  if (driveService != null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Loading items...'), duration: Duration(milliseconds: 500)));
                    var items = await driveService.fetchRecords(widget.module!.id, widget.module!.name, relatedTabId);
                    if (!mounted) return;
                    // apply dependency filter
                    if (widget.column.dependsOn != null && !widget.column.dependsOn!.startsWith('settings.')) {
                      final parentKey = widget.column.dependsOn!;
                      final parentValue = widget.data[parentKey];
                      items = items.where((item) => item[parentKey]?.toString() == parentValue?.toString()).toList();
                    }
                    await _showItemsDialog(items, relatedTab.label);
                    return;
                  }
                } catch (_) {}
              }

              // Next, check cached schemas for a module that contains the tab or matches the name/key
              try {
                ModuleSchema? targetModule;
                try {
                  targetModule = schemaProvider.findModuleByTabId(relatedTabId);
                } catch (_) {}
                targetModule ??= schemaProvider.findModuleByIdOrName(relatedTabId);

                if (targetModule != null && driveService != null) {
                  // Determine tab label if available
                  final tab = targetModule.tabs.firstWhere((t) => t.id == relatedTabId, orElse: () => targetModule!.tabs.first);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Loading items...'), duration: Duration(milliseconds: 500)));
                  var items = await driveService.fetchRecords(targetModule.id, targetModule.name, tab.id);
                  if (!mounted) return;
                  if (widget.column.dependsOn != null && !widget.column.dependsOn!.startsWith('settings.')) {
                    final parentKey = widget.column.dependsOn!;
                    final parentValue = widget.data[parentKey];
                    items = items.where((item) => item[parentKey]?.toString() == parentValue?.toString()).toList();
                  }
                  await _showItemsDialog(items, tab.label);
                  return;
                }
              } catch (_) {}

              // Finally, if we have workspace context, scan installed modules (Drive folders) to find a sheet with that name
              if (driveService != null) {
                final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
                final workspaceId = workspaceProvider.currentWorkspace?.id as String?;
                if (workspaceId != null) {
                  try {
                    final modules = await driveService.listModules(workspaceId);
                    for (var mod in modules) {
                      try {
                        final fileId = await driveService.getFileId(mod.id!, relatedTabId);
                        if (fileId != null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Loading items...'), duration: Duration(milliseconds: 500)));
                          var items = await driveService.fetchRecords(mod.id!, mod.name ?? '', relatedTabId);
                          if (widget.column.dependsOn != null && !widget.column.dependsOn!.startsWith('settings.')) {
                            final parentKey = widget.column.dependsOn!;
                            final parentValue = widget.data[parentKey];
                            items = items.where((item) => item[parentKey]?.toString() == parentValue?.toString()).toList();
                          }
                          await _showItemsDialog(items, relatedTabId);
                          return;
                        }
                      } catch (e) {
                        // ignore and continue
                      }
                    }
                  } catch (e) {
                    debugPrint('Error scanning modules for related tab: $e');
                  }
                }
              }

              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entity lookup configuration missing or no data found')));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entity lookup configuration missing')));
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.transparent),
            ),
            child: Row(
              children: [
                Icon(Icons.link_rounded, color: theme.textTheme.bodyMedium?.color, size: 20),
                const SizedBox(width: 12),
                Text(
                  widget.value?.toString() ?? 'Select ${widget.column.label}',
                  style: AppTheme.inter(
                    color: widget.value != null ? theme.textTheme.bodyLarge?.color : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                  ),
                ),
                const Spacer(),
                Icon(Icons.arrow_drop_down_rounded, color: theme.textTheme.bodyMedium?.color),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
