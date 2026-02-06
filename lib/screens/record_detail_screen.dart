import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/schema_models.dart';
import '../theme/app_theme.dart';
import '../providers/drive_provider.dart';
import '../providers/schema_provider.dart';
import 'dynamic_form_screen.dart';
import 'dynamic_form/conditional_utils.dart';
import 'record_detail/table_field_view.dart';
import 'record_detail/text_field_view.dart';
import 'record_detail/list_field_view.dart';
import 'record_detail/status_field_view.dart';
import 'record_detail/image_field_view.dart';
import 'record_detail/formula_field_view.dart';

class RecordDetailScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final List<ColumnConfig> columns;
  final Color primaryColor;
  final String title;
  final Map<String, SettingItem> settings;
  final DetailTemplateConfig? detailTemplate;
  final TabConfig tab;
  final ModuleSchema? module;

  const RecordDetailScreen({
    super.key,
    required this.data,
    required this.columns,
    required this.primaryColor,
    required this.title,
    required this.tab,
    this.settings = const {},
    this.detailTemplate,
    this.module,
  });

  @override
  State<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends State<RecordDetailScreen> {
  late Map<String, dynamic> _currentData;
  bool _wasEdited = false;
  final Map<String, String> _relationLabels = {};
  final Set<String> _loadingTableFields = {};
  final Set<String> _attemptedTableFields = {};

  @override
  void initState() {
    super.initState();
    _currentData = Map<String, dynamic>.from(widget.data);
    _resolveRelationLabels();
  }

  @override
  void didUpdateWidget(RecordDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _currentData = Map<String, dynamic>.from(widget.data);
      _resolveRelationLabels();
    }
  }

  void _resolveRelationLabels() {
    // Resolve labels for relation columns asynchronously after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final col in widget.columns) {
        if (col.type == 'relation' && _currentData.containsKey(col.key) && _currentData[col.key] != null) {
          final rawVal = _currentData[col.key];
          final id = rawVal?.toString();
          if (id != null && id.isNotEmpty) {
            _resolveLabelForColumn(col, id);
          }
        }
      }
    });
  }

  Future<void> _resolveLabelForColumn(ColumnConfig col, String id) async {
    try {
      final driveService = Provider.of<DriveProvider>(context, listen: false).driveService;
      final schemaProvider = Provider.of<SchemaProvider>(context, listen: false);
      if (driveService == null) return;

      final relatedTabId = col.options is String ? col.options as String : null;
      if (relatedTabId == null) return;

      // Try current module first
      ModuleSchema? targetModule;
      if (widget.module != null) {
        try {
          final hasTab = widget.module!.tabs.any((t) => t.id == relatedTabId);
          if (hasTab) targetModule = widget.module;
        } catch (_) {}
      }

      // Try cached schemas
      targetModule ??= schemaProvider.findModuleByTabId(relatedTabId) ?? schemaProvider.findModuleByIdOrName(relatedTabId);

      if (targetModule != null) {
        final tab = targetModule.tabs.firstWhere((t) => t.id == relatedTabId, orElse: () => targetModule!.tabs.first);
        try {
          final fileId = tab.fileId;
          List<Map<String, dynamic>> records = [];
          
          if (fileId != null && fileId.isNotEmpty) {
            records = await driveService.fetchRecordsBySpreadsheetId(fileId, tab.id, limit: 1000, fetchSubTables: false);
          }

          final match = records.firstWhere((r) => (r['record_id']?.toString() == id) || (r['id']?.toString() == id), orElse: () => {});
          if (match.isNotEmpty) {
            final label = match['item_name']?.toString() ?? match['name']?.toString() ?? match.values.first.toString();
            if (mounted) setState(() => _relationLabels[col.key] = label);
            return;
          }
        } catch (_) {}
      }

      // Fallback: do nothing (leave raw id shown)
    } catch (e) {
      debugPrint('Error resolving relation label for ${col.key}: $e');
    }
  }

  String _resolveTitle() {
    if (widget.detailTemplate?.titleLogic != null) {
      return _getValueFromLogic(widget.detailTemplate!.titleLogic!);
    }
    if (widget.detailTemplate?.titleKey != null) {
      return _currentData[widget.detailTemplate!.titleKey]?.toString() ?? widget.title;
    }
    return widget.title;
  }

  String _resolveSubtitle() {
    if (widget.detailTemplate?.subtitleLogic != null) {
      return _getValueFromLogic(widget.detailTemplate!.subtitleLogic!);
    }
    if (widget.detailTemplate?.subtitleKey != null) {
      return _currentData[widget.detailTemplate!.subtitleKey]?.toString() ?? '';
    }
    return '';
  }

  String _resolveImageUrl(String? rawValue) {
    if (rawValue == null || rawValue.isEmpty) return '';
    if (rawValue.startsWith('http') || rawValue.contains('data:image')) {
      return rawValue;
    }
    // Assume it's a Drive File ID
    return 'https://drive.google.com/uc?export=view&id=$rawValue';
  }

  String _getValueFromLogic(ConditionalLogic logic) {
    final conditionValue = _currentData[logic.conditionKey];
    bool isTruthy = false;

    if (conditionValue is bool) {
      isTruthy = conditionValue;
    } else if (conditionValue is String) {
      final s = conditionValue.toLowerCase().trim();
      isTruthy = s.isNotEmpty && s != 'false' && s != '0';
    } else if (conditionValue is List) {
      isTruthy = conditionValue.isNotEmpty;
    } else if (conditionValue is num) {
      isTruthy = conditionValue != 0;
    } else if (conditionValue != null) {
      isTruthy = true;
    }

    final resultKey = isTruthy ? logic.truthyKey : logic.falsyKey;
    return (_currentData.containsKey(resultKey)) ? _currentData[resultKey]?.toString() ?? '' : '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isModern = widget.detailTemplate?.template == 'modern';

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        Navigator.of(context).pop(_wasEdited);
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        extendBodyBehindAppBar: isModern,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_wasEdited),
          ),
          title: Text(
            'DETAILS',
            style: AppTheme.inter(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              fontSize: 16,
              color: isModern ? Colors.white : theme.textTheme.titleMedium?.color,
            ),
          ),
          backgroundColor: isModern ? Colors.transparent : null,
          elevation: 0,
          iconTheme: IconThemeData(color: isModern ? Colors.white : theme.iconTheme.color),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.edit_outlined, color: isModern ? Colors.white : theme.iconTheme.color),
              onPressed: () => _editRecord(context),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: isModern ? Colors.white : Colors.redAccent),
              onPressed: () => _confirmDelete(context),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          top: !isModern,
          child: SingleChildScrollView(
            padding: isModern ? EdgeInsets.zero : const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isModern) _buildModernHeader(context) else _buildHeader(context),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: _buildFieldsList(context),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeader(BuildContext context) {
    
    final headerTitle = _resolveTitle();
    final headerSubtitle = _resolveSubtitle();
    final rawImage = widget.detailTemplate?.imageKey != null ? (_currentData[widget.detailTemplate!.imageKey]?.toString() ?? '') : '';
    final imageUrl = _resolveImageUrl(rawImage);
    final hasImage = imageUrl.isNotEmpty;

    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        color: widget.primaryColor,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage) 
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.black.withValues(alpha: 0.2),
                child: const Icon(Icons.broken_image_rounded, color: Colors.white24, size: 64),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.4),
                  Colors.black.withValues(alpha: 0.0),
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RECORD ENTRY',
                  style: AppTheme.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.7),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  headerTitle,
                  style: AppTheme.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                if (headerSubtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    headerSubtitle,
                    style: AppTheme.inter(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.cardTheme.color;
    
    final headerTitle = _resolveTitle();
    final headerSubtitle = _resolveSubtitle();
    final rawImage = widget.detailTemplate?.imageKey != null ? (_currentData[widget.detailTemplate!.imageKey]?.toString() ?? '') : '';
    final imageUrl = _resolveImageUrl(rawImage);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: widget.primaryColor.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.isNotEmpty) 
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
              ),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: widget.primaryColor.withValues(alpha: 0.05),
                  child: Icon(Icons.broken_image_rounded, color: widget.primaryColor.withValues(alpha: 0.4), size: 48),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                if (imageUrl.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: widget.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.description_rounded, color: widget.primaryColor, size: 32),
                  ),
                if (imageUrl.isEmpty || !imageUrl.startsWith('http'))
                  const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RECORD ENTRY',
                        style: AppTheme.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        headerTitle,
                        style: AppTheme.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: theme.textTheme.titleLarge?.color,
                        ),
                      ),
                      if (headerSubtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          headerSubtitle,
                          style: AppTheme.inter(
                            fontSize: 16,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldsList(BuildContext context) {
    // 1. Determine which columns to show
    List<ColumnConfig> visibleColumns;
    
    if (widget.detailTemplate?.showAllFields ?? true) {
      visibleColumns = widget.columns;
    } else {
      final keys = widget.detailTemplate?.detailKeys ?? [];
      visibleColumns = widget.columns.where((c) => keys.contains(c.key)).toList();
    }

    // 2. Filter based on logic dependencies
    final filteredColumns = visibleColumns.where((col) {
      if (col.hidden == true) return false;
      
      // Don't show header fields in the list if already in header
      if (col.key == widget.detailTemplate?.titleKey || col.key == widget.detailTemplate?.subtitleKey || col.key == widget.detailTemplate?.imageKey) {
        return false;
      }

      // Also hide fields used in conditional logic to avoid duplication
      if (widget.detailTemplate?.titleLogic != null) {
        final logic = widget.detailTemplate!.titleLogic!;
        if (col.key == logic.truthyKey || col.key == logic.falsyKey) return false;
      }
      if (widget.detailTemplate?.subtitleLogic != null) {
        final logic = widget.detailTemplate!.subtitleLogic!;
        if (col.key == logic.truthyKey || col.key == logic.falsyKey) return false;
      }

      if (col.dependsOn != null && col.dependsOn!.isNotEmpty) {
        final dependency = col.dependsOn!;

        // Support negation prefix (e.g. '!field')
        bool negate = false;
        String actualDependency = dependency;
        if (dependency.startsWith('!')) {
          negate = true;
          actualDependency = dependency.substring(1);
        }

        // If dependency references settings, evaluate against setting value
        if (actualDependency.startsWith('settings.')) {
          final settingKey = actualDependency.split('.').length > 1 ? actualDependency.split('.')[1] : '';
          final setting = widget.settings[settingKey];
          final dependentValue = setting?.value;

          if (col.dependsValue != null) {
            final match = evaluateDependency(dependentValue, col.dependsValue, col.dependsOperator);
            if (negate ? !match : match) {
              // ok
            } else {
              return false;
            }
          } else {
            bool isTruthy = false;
            if (dependentValue is bool) {
              isTruthy = dependentValue;
            } else if (dependentValue is String) isTruthy = dependentValue.isNotEmpty;
            else if (dependentValue is List) isTruthy = dependentValue.isNotEmpty;
            else isTruthy = dependentValue != null;

            if (isTruthy != !negate) return false;
          }
        } else {
          final dependentValue = _currentData[actualDependency];

          if (col.dependsValue != null) {
            final match = evaluateDependency(dependentValue, col.dependsValue, col.dependsOperator);
            if (negate ? !match : match) {
              // ok
            } else {
              return false;
            }
          } else {
            bool isTruthy = false;
            if (dependentValue is bool) {
              isTruthy = dependentValue;
            } else if (dependentValue is String) isTruthy = dependentValue.isNotEmpty;
            else if (dependentValue is List) isTruthy = dependentValue.isNotEmpty;
            else isTruthy = dependentValue != null;

            if (isTruthy != !negate) return false;
          }
        }
      }
      return true;
    }).toList();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredColumns.length,
      separatorBuilder: (context, index) => const SizedBox(height: 24),
      itemBuilder: (context, index) {
        final col = filteredColumns[index];
        final value = _currentData[col.key];

        if (col.type == 'table') {
           // Support table values as List, Map or JSON-encoded String so
           // table fields persist when stored/loaded as strings.
           List<Map<String, dynamic>> itemsList = [];

           if (value is List) {
             itemsList = value.map((e) => e is Map ? Map<String, dynamic>.from(e) : { 'value': e?.toString() ?? '' }).toList();
           } else if (value is String) {
             try {
               final decoded = jsonDecode(value);
               if (decoded is List) {
                 itemsList = decoded.map((e) => e is Map ? Map<String, dynamic>.from(e) : { 'value': e?.toString() ?? '' }).toList();
               }
             } catch (_) {
               // ignore parse errors and fall through to empty list
             }
           } else if (value is Map) {
             itemsList = [Map<String, dynamic>.from(value)];
           }

           return _buildTableField(col, itemsList);
        }

        // Relation fields: prefer resolved human label when available.
        // While unresolved, show a small CircularProgressIndicator inside
        // the same styled container used by TextFieldView.
        if (col.type == 'relation') {
          if (value == null) {
            return TextFieldView(label: col.label, value: 'N/A');
          }

          if (_relationLabels.containsKey(col.key)) {
            return TextFieldView(label: col.label, value: _relationLabels[col.key]!);
          }

          // Loading state
          final theme = Theme.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                col.label.toUpperCase(),
                style: AppTheme.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: theme.textTheme.bodyMedium?.color,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 12),
                  ],
                ),
              ),
            ],
          );
        }

        // Non-relation fields
        String displayValue = value?.toString() ?? 'N/A';

        if (col.type == 'image' || col.key.toLowerCase().contains('image') || col.key.toLowerCase().contains('photo')) {
          return ImageFieldView(label: col.label, rawValue: displayValue, primaryColor: widget.primaryColor);
        }

        if (col.key.toLowerCase() == 'status') {
          return StatusFieldView(label: col.label, value: displayValue);
        }

        if (col.type == 'formula') {
          return FormulaFieldView(label: col.label, value: displayValue);
        }

        if (col.type == 'list') {
          return ListFieldView(label: col.label, value: value, primaryColor: widget.primaryColor);
        }

        return TextFieldView(label: col.label, value: displayValue);
      },
    );
  }


  

  Widget _buildTableField(ColumnConfig col, dynamic items) {
    List<Map<String, dynamic>> itemsList = [];

    if (items is List) {
      itemsList = items.map((e) => e is Map ? Map<String, dynamic>.from(e) : { 'value': e?.toString() ?? '' }).toList();
    } else if (items is String) {
      try {
        final decoded = jsonDecode(items);
        if (decoded is List) {
          itemsList = decoded.map((e) => e is Map ? Map<String, dynamic>.from(e) : { 'value': e?.toString() ?? '' }).toList();
        }
      } catch (_) {}
    } else if (items is Map) {
      itemsList = [Map<String, dynamic>.from(items)];
    }

    final fieldKey = col.key;
    final isLoading = _loadingTableFields.contains(fieldKey);
    final isAttempted = _attemptedTableFields.contains(fieldKey);

    // Auto-load if enabled and not already attempted/loading
    if (itemsList.isEmpty && 
        !isLoading && 
        !isAttempted && 
        (widget.tab.loadSubTableDataAutomatically ?? true) &&
        _currentData['record_id'] != null) {
      // Use addPostFrameCallback to avoid calling setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadSubTableField(fieldKey, col);
      });
    }

    return TableFieldView(
      col: col,
      items: itemsList,
      isLoading: isLoading,
      isAttempted: isAttempted,
      onLoad: () => _loadSubTableField(fieldKey, col),
    );
  }

  Future<void> _loadSubTableField(String fieldKey, ColumnConfig col) async {
    final driveService = Provider.of<DriveProvider>(context, listen: false).driveService;
    if (driveService == null || widget.module == null || _currentData['record_id'] == null) return;

    if (_loadingTableFields.contains(fieldKey)) return;

    if (mounted) {
      setState(() {
        _loadingTableFields.add(fieldKey);
        _attemptedTableFields.add(fieldKey);
      });
    }

    final childTabId = '${widget.tab.id}.$fieldKey';
    final fileId = widget.tab.fileId;
    final recordIdStr = _currentData['record_id']?.toString();

    if (recordIdStr == null || recordIdStr.isEmpty) {
      if (mounted) setState(() { _currentData[fieldKey] = []; });
      return;
    }

    try {
      List<Map<String, dynamic>> recs = [];
      if (fileId != null && fileId.isNotEmpty) {
        try {
          // Use server-side search by parent_record_id for efficiency
          recs = await driveService.fetchRecordsBySpreadsheetId(
            fileId, 
            childTabId, 
            fetchSubTables: false,
            quickFilter: {'field': 'parent_record_id', 'operator': '==', 'value': recordIdStr},
            limit: 1000, 
          );
          
        } catch (e) {
          debugPrint('Sub-sheet $childTabId search failed or not found: $e. Falling back to inline data.');
          recs = [];
        }
      }

      final normalized = recs.map((e) => Map<String, dynamic>.from(e)).toList();

      if (normalized.isNotEmpty) {
        if (mounted) {
          setState(() {
            _currentData[fieldKey] = normalized;
          });
        }
      } else {
        // Fallback to inline data already in _currentData or attempt a single record re-fetch
        // Check if _currentData already has a JSON string that needs decoding
        final existingValue = _currentData[fieldKey];
        if (existingValue is String && existingValue.trim().startsWith('[')) {
          try {
            final decoded = jsonDecode(existingValue);
            if (decoded is List) {
              final norm = decoded.map((e) => e is Map ? Map<String, dynamic>.from(e) : {'value': e?.toString() ?? ''}).toList();
              if (mounted) setState(() => _currentData[fieldKey] = norm);
              return;
            }
          } catch (_) {}
        }

        // If not found in child sheet and not found inline, final check of main tab (limit to JUST this record's potential data)
        // We only do this if we suspect the initial fetch was missing columns or bloat.
        // For efficiency, we only fetch if we don't already have a value.
        if (existingValue == null || (existingValue is String && existingValue.isEmpty)) {
            if (mounted) setState(() => _currentData[fieldKey] = []);
        }
      }
    } catch (e) {
      debugPrint('Error loading sub-table field $fieldKey: $e');
      if (mounted) setState(() => _currentData[fieldKey] = []);
    } finally {
      if (mounted) {
        setState(() {
          _loadingTableFields.remove(fieldKey);
        });
      }
    }
  }

  void _editRecord(BuildContext context) async {
    // Ensure all table fields are loaded before editing to prevent data loss or empty items in form
    final tableCols = widget.columns.where((c) => c.type == 'table').toList();
    final List<Future<void>> loadTasks = [];

    for (var col in tableCols) {
      if (!_attemptedTableFields.contains(col.key)) {
        loadTasks.add(_loadSubTableField(col.key, col));
      }
    }

    if (loadTasks.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preparing record for edit...'), duration: Duration(seconds: 2)),
      );
      await Future.wait(loadTasks);
    }

    if (!mounted) return;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => DynamicFormScreen(
          tab: widget.tab,
          primaryColor: widget.primaryColor,
          initialData: _currentData,
          settings: widget.settings,
          module: widget.module,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _currentData = result;
        _wasEdited = true;
      });
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record'),
        content: const Text('Are you sure you want to delete this record? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteRecord(context);
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRecord(BuildContext context) async {
    final driveProvider = Provider.of<DriveProvider>(context, listen: false);
    final recordId = _currentData['record_id']?.toString();
    
    // Capture states before async gaps
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    
    if (recordId == null || widget.module == null) {
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Cannot delete: Record ID missing')));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final spreadsheetId = widget.tab.fileId;
      if (spreadsheetId == null || spreadsheetId.isEmpty) {
        throw Exception("Spreadsheet ID missing for this tab");
      }

      await (driveProvider.driveService as dynamic).deleteRecordBySpreadsheetId(
        spreadsheetId,
        widget.tab.id,
        recordId,
      );

      if (mounted) {
        // Close loading dialog using the captured root navigator
        rootNavigator.pop();
        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Record deleted successfully')));
        // Close detail screen using the captured local navigator
        navigator.pop(true);
      }
    } catch (e) {
      if (mounted) {
        rootNavigator.pop();
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error deleting record: $e')));
      }
    }
  }
}
