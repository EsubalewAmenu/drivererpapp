import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/schema_models.dart';
import '../theme/app_theme.dart';
import '../providers/drive_provider.dart';
import 'dynamic_form_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _currentData = Map<String, dynamic>.from(widget.data);
  }

  @override
  void didUpdateWidget(RecordDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _currentData = Map<String, dynamic>.from(widget.data);
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
    return (resultKey != null && _currentData.containsKey(resultKey)) ? _currentData[resultKey]?.toString() ?? '' : '';
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
    final theme = Theme.of(context);
    
    final headerTitle = _resolveTitle();
    final headerSubtitle = _resolveSubtitle();
    final imageUrl = widget.detailTemplate?.imageKey != null ? (_currentData[widget.detailTemplate!.imageKey]?.toString() ?? '') : '';
    final hasImage = imageUrl.isNotEmpty && (imageUrl.startsWith('http') || imageUrl.contains('data:image'));

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
    final imageUrl = widget.detailTemplate?.imageKey != null ? (_currentData[widget.detailTemplate!.imageKey]?.toString() ?? '') : '';

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
          if (imageUrl.isNotEmpty && (imageUrl.startsWith('http') || imageUrl.contains('data:image'))) 
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
                if (imageUrl.isEmpty || !imageUrl.startsWith('http'))
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
        
        // Check for negation
        bool expectedValue = true;
        String actualDependency = dependency;
        if (dependency.startsWith('!')) {
          expectedValue = false;
          actualDependency = dependency.substring(1);
        }

        bool isTruthy = false;
        if (actualDependency.startsWith('settings.')) {
          final settingKey = actualDependency.replaceFirst('settings.', '');
          final setting = widget.settings[settingKey];
          if (setting != null) {
            final val = setting.value;
            if (val is bool) isTruthy = val;
            else if (val is String) isTruthy = val.isNotEmpty;
            else if (val is List) isTruthy = val.isNotEmpty;
            else isTruthy = val != null;
          }
        } else {
          final val = _currentData[actualDependency];
          if (val is bool) isTruthy = val;
          else if (val is String) isTruthy = val.isNotEmpty;
          else if (val is List) isTruthy = val.isNotEmpty;
          else isTruthy = val != null;
        }

        if (isTruthy != expectedValue) return false;
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
        
        if (col.type == 'table' && value is List) {
           return _buildTableField(col, value as List<Map<String, dynamic>>);
        }

        final displayValue = value?.toString() ?? 'N/A';

        if (col.type == 'image' || col.key.toLowerCase().contains('image') || col.key.toLowerCase().contains('photo')) {
           return _buildImageField(context, col.label, displayValue);
        }
        
        if (col.key.toLowerCase() == 'status') {
           return _buildStatusField(context, col.label, displayValue);
        }

        if (col.type == 'formula') {
           return _buildFormulaField(context, col.label, displayValue);
        }

        if (col.type == 'list') {
           return _buildListField(context, col.label, value);
        }

        return _buildTextField(context, col.label, displayValue);
      },
    );
  }

  Widget _buildListField(BuildContext context, String label, dynamic value) {
    if (value == null || (value is String && value.isEmpty)) {
      return _buildTextField(context, label, 'N/A');
    }

    final theme = Theme.of(context);
    List<String> items = [];

    if (value is List) {
      items = value.map((e) => e.toString()).toList();
    } else if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          items = decoded.map((e) => e.toString()).toList();
        } else {
          items = [value];
        }
      } catch (_) {
        items = [value];
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
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
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: widget.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: widget.primaryColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                item,
                style: AppTheme.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: widget.primaryColor,
                ),
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
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
          child: Text(
            value,
            style: AppTheme.inter(
              fontSize: 16,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusField(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    Color statusColor;
    switch (value.toLowerCase()) {
      case 'active':
      case 'completed':
      case 'paid':
        statusColor = theme.primaryColor;
        break;
      case 'inactive':
      case 'pending':
      case 'overdue':
        statusColor = const Color(0xFFF43F5E); // Rose
        break;
      default:
        statusColor = Colors.blue;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTheme.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: theme.textTheme.bodyMedium?.color,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withValues(alpha: 0.5)),
          ),
          child: Text(
            value.toUpperCase(),
            style: AppTheme.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: statusColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageField(BuildContext context, String label, String url) {
    final theme = Theme.of(context);
    final borderColor = theme.textTheme.bodyMedium?.color ?? AppTheme.secondaryTextColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTheme.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: theme.textTheme.bodyMedium?.color,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor.withValues(alpha: 0.2)),
          ),
          clipBehavior: Clip.antiAlias,
          child: url.startsWith('http') 
            ? Image.network(
                url, 
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Icon(Icons.broken_image_rounded, color: borderColor, size: 48),
                ),
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_not_supported_rounded, color: borderColor, size: 48),
                    const SizedBox(height: 8),
                    Text('No Image Available', style: TextStyle(color: borderColor)),
                  ],
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildFormulaField(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    final borderColor = theme.textTheme.bodyMedium?.color ?? AppTheme.secondaryTextColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
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
            color: (theme.cardTheme.color ?? theme.cardColor).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Icon(Icons.functions_rounded, size: 16, color: borderColor),
              const SizedBox(width: 8),
              Text(
                value,
                style: AppTheme.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableField(ColumnConfig col, List<Map<String, dynamic>> items) {
    return Builder(builder: (context) {
        final theme = Theme.of(context);
        final tableCols = col.columns ?? [];
        if (items.isEmpty) return _buildTextField(context, col.label, 'No items');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${items.length} items',
                    style: AppTheme.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(theme.primaryColor.withValues(alpha: 0.05)),
                  columnSpacing: 24,
                  horizontalMargin: 16,
                  columns: tableCols.map((c) => DataColumn(
                    label: Text(
                      c.label.toUpperCase(),
                      style: AppTheme.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  )).toList(),
                  rows: items.map((item) {
                    return DataRow(
                      cells: tableCols.map((c) {
                        final val = item[c.key]?.toString() ?? '-';
                        return DataCell(
                          Text(
                            val,
                            style: AppTheme.inter(
                              fontSize: 14,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        );
    });
  }

  void _editRecord(BuildContext context) async {
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
      await driveProvider.driveService!.deleteRecord(
        widget.module!.id,
        widget.module!.name,
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
