import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/schema_models.dart';
import '../../../providers/drive_provider.dart';
import '../../../providers/schema_provider.dart';
import '../../../providers/workspace_provider.dart';
import '../../../theme/app_theme.dart';
import '../conditional_utils.dart';

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
  String? _displayLabel;

  @override
  void initState() {
    super.initState();
    if (widget.value != null) {
      // Try to resolve the label for the provided id
      _resolveLabelForValue(widget.value);
    }
  }

  @override
  void didUpdateWidget(covariant DynamicRelationField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _resolveLabelForValue(widget.value);
    }
  }

  Future<void> _resolveLabelForValue(String? id) async {
    if (id == null) return;
    try {
      final relatedTabId = widget.column.options is String ? widget.column.options as String : null;
      if (relatedTabId == null) return;
      final driveService = Provider.of<DriveProvider>(context, listen: false).driveService;
      final schemaProvider = Provider.of<SchemaProvider>(context, listen: false);
      if (driveService == null) return;

      // Try to find module that owns the tab
      ModuleSchema? targetModule = schemaProvider.findModuleByTabId(relatedTabId) ?? schemaProvider.findModuleByIdOrName(relatedTabId);
      if (targetModule != null) {
        final tab = targetModule.tabs.firstWhere((t) => t.id == relatedTabId, orElse: () => targetModule!.tabs.first);
        final fileId = tab.fileId;
        List<Map<String, dynamic>> records = [];
        
        if (fileId != null && fileId.isNotEmpty) {
          records = await driveService.fetchRecordsBySpreadsheetId(fileId, tab.id, limit: 1000);
        }

        final match = records.firstWhere((r) => (r['record_id']?.toString() == id.toString()) || (r['id']?.toString() == id.toString()), orElse: () => {});
        if (match.isNotEmpty) {
          final label = match['item_name']?.toString() ?? match['name']?.toString() ?? match.values.first.toString();
          if (mounted) setState(() => _displayLabel = label);
          return;
        }
      }
    } catch (_) {}
  }
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
                  // Settings dependency handled as before
                  if (parentKey.startsWith('settings.')) {
                    // Leave check to renderer/settings; allow dialog to open
                  } else {
                     final parentValue = widget.data[parentKey];
                     if (widget.column.dependsValue != null) {
                       final ok = evaluateDependency(parentValue, widget.column.dependsValue, widget.column.dependsOperator);
                       if (!ok) {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select an appropriate value for $parentKey first')));
                         return;
                       }
                     } else {
                       if (parentValue == null || parentValue.toString().isEmpty) {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select a value for $parentKey first')));
                         return;
                       }
                    }
                  }
                 }

            // If column.options is a String, interpret it as a related tab id or module key
            if (widget.column.options is String) {
              final relatedTabId = widget.column.options as String;
              final driveService = Provider.of<DriveProvider>(context, listen: false).driveService;
              final schemaProvider = Provider.of<SchemaProvider>(context, listen: false);

              // Show search dialog that queries when user types >=2 chars (limit 10)
              Future<void> _showSearchDialog(String title, ModuleSchema? moduleHint, String tabId) async {
                if (!mounted) return;
                List<Map<String, dynamic>> results = [];
                bool loading = false;
                String query = '';

                Future<void> doSearch() async {
                  if (!mounted) return;
                  if (query.length < 2) {
                    // Use the StatefulBuilder's setState via closure below
                    // but here we just ensure results cleared before showing dialog
                    results = [];
                    return;
                  }
                  loading = true;
                  debugPrint('RelationField: searching "$query" for tab $tabId (hint ${moduleHint?.id})');
                  try {
                    List<Map<String, dynamic>> fetched = [];

                    ModuleSchema? targetModule = moduleHint;

                    // Try module hint first
                    if (targetModule != null && driveService != null) {
                      try {
                        final tab = targetModule.tabs.firstWhere((t) => t.id == tabId, orElse: () => targetModule!.tabs.first);
                        final fileId = tab.fileId;
                        if (fileId != null && fileId.isNotEmpty) {
                          fetched = await driveService.fetchRecordsBySpreadsheetId(fileId, tab.id, searchQuery: query, limit: 10);
                        }
                      } catch (_) {
                        fetched = [];
                      }
                    }

                    // If none and we have cached schemas, try to find another module
                    if ((fetched.isEmpty) && schemaProvider != null) {
                      try {
                        targetModule = schemaProvider.findModuleByTabId(tabId) ?? schemaProvider.findModuleByIdOrName(tabId);
                        if (targetModule != null && driveService != null) {
                          final tab = targetModule.tabs.firstWhere((t) => t.id == tabId, orElse: () => targetModule!.tabs.first);
                          final fileId = tab.fileId;
                          if (fileId != null && fileId.isNotEmpty) {
                            fetched = await driveService.fetchRecordsBySpreadsheetId(fileId, tab.id, searchQuery: query, limit: 10);
                          }
                        }
                      } catch (_) {}
                    }

                    // Dependency filter
                    if (fetched.isNotEmpty && widget.column.dependsOn != null && !widget.column.dependsOn!.startsWith('settings.')) {
                      final parentKey = widget.column.dependsOn!;
                      final parentValue = widget.data[parentKey];
                      fetched = fetched.where((item) => item[parentKey]?.toString() == parentValue?.toString()).toList();
                    }

                    debugPrint('RelationField: fetched ${fetched.length} results for query "$query"');

                    // Fallback: if server-side returned nothing, try a local fetch and client-side filter
                    if (fetched.isEmpty) {
                      try {
                        ModuleSchema? fallbackModule;
                        try {
                          fallbackModule = schemaProvider.findModuleByTabId(tabId) ?? schemaProvider.findModuleByIdOrName(tabId);
                        } catch (_) {}

                        final useModule = fallbackModule ?? moduleHint;
                        if (useModule != null && driveService != null) {
                          debugPrint('RelationField: server search empty, performing local fallback fetch for tab $tabId');
                          final tab = useModule.tabs.firstWhere((t) => t.id == tabId, orElse: () => useModule.tabs.first);
                          final fileId = tab.fileId;
                          List<Map<String, dynamic>> local = [];
                          if (fileId != null && fileId.isNotEmpty) {
                             local = await driveService.fetchRecordsBySpreadsheetId(fileId, tab.id, limit: 200);
                          }
                          
                          final lowered = query.toLowerCase();
                          final filtered = local.where((item) {
                            try {
                              if (item.containsKey('item_name') && item['item_name'] != null && item['item_name'].toString().toLowerCase().contains(lowered)) return true;
                              if (item.containsKey('name') && item['name'] != null && item['name'].toString().toLowerCase().contains(lowered)) return true;
                              return item.values.any((v) => v != null && v.toString().toLowerCase().contains(lowered));
                            } catch (_) {
                              return false;
                            }
                          }).toList();
                          debugPrint('RelationField: fallback found ${filtered.length} items');
                          fetched = filtered.take(10).toList();
                        }
                      } catch (e) {
                        debugPrint('RelationField: fallback fetch error: $e');
                      }
                    }

                    // update outer vars; the StatefulBuilder below will call setState to refresh UI
                    results = fetched;
                  } catch (e) {
                    debugPrint('Search error: $e');
                  } finally {
                    loading = false;
                  }
                }

                Timer? debounce;
                await showDialog<String>(
                  context: context,
                  builder: (context) {
                    return StatefulBuilder(builder: (context, setState) {

                      // Build dialog UI
                      return AlertDialog(
                        title: Text('Search $title'),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                autofocus: true,
                                decoration: const InputDecoration(hintText: 'Type to search (min 2 chars)'),
                                onChanged: (v) {
                                  query = v.trim();
                                  // debounce user input before searching
                                  try { debounce?.cancel(); } catch (_) {}
                                  debounce = Timer(const Duration(milliseconds: 600), () async {
                                    if (!mounted) return;
                                    setState(() => loading = true);
                                    await doSearch();
                                    if (mounted) setState(() {});
                                  });
                                  setState(() {});
                                },
                              ),
                              const SizedBox(height: 12),
                              if (loading) const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())),
                              if (!loading && results.isEmpty) const Padding(padding: EdgeInsets.all(8.0), child: Text('No results')),
                              if (results.isNotEmpty)
                                Flexible(
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: results.length,
                                    itemBuilder: (context, idx) {
                                      final item = results[idx];
                                      String label = item.values.first.toString();
                                      if (item.containsKey('item_name')) label = item['item_name']?.toString() ?? label;
                                      else if (item.containsKey('name')) label = item['name']?.toString() ?? label;
                                      final recordId = item['record_id']?.toString() ?? item['id']?.toString();
                                      return ListTile(
                                        title: Text(label),
                                        onTap: () {
                                          if (mounted) setState(() => _displayLabel = label);
                                          Navigator.pop(context, recordId ?? label);
                                        },
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
                        ],
                      );
                    });
                  },
                ).then((selected) {
                  if (selected != null && mounted) widget.onChanged(selected);
                }).whenComplete(() {
                  try { debounce?.cancel(); } catch (_) {}
                });
              }

              // Determine a module hint (current module if it has the tab)
              ModuleSchema? moduleHint;
              try {
                if (widget.module != null && widget.module!.tabs.any((t) => t.id == relatedTabId)) moduleHint = widget.module;
              } catch (_) {}

              // Launch search dialog with the hint
              await _showSearchDialog(relatedTabId, moduleHint, relatedTabId);
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
                  _displayLabel ?? widget.value?.toString() ?? 'Select ${widget.column.label}',
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
