import 'package:flutter/material.dart';
import '../../../models/schema_models.dart';
import '../../../theme/app_theme.dart';
import 'filter_editor_screen.dart';

class FilterManagementScreen extends StatefulWidget {
  final List<ColumnConfig> columns;
  final List<QuickFilter> initialFilters;
  final bool initialEnabled;

  const FilterManagementScreen({
    super.key,
    required this.columns,
    required this.initialFilters,
    required this.initialEnabled,
  });

  @override
  State<FilterManagementScreen> createState() => _FilterManagementScreenState();
}

class _FilterManagementScreenState extends State<FilterManagementScreen> {
  late List<QuickFilter> _filters;
  late bool _isEnabled;

  @override
  void initState() {
    super.initState();
    _filters = List.from(widget.initialFilters);
    _isEnabled = widget.initialEnabled;
  }

  void _addFilter() async {
    final result = await Navigator.push<QuickFilter>(
      context,
      MaterialPageRoute(
        builder: (context) => FilterEditorScreen(columns: widget.columns),
      ),
    );

    if (result != null) {
      setState(() {
        _filters.add(result);
      });
    }
  }

  void _editFilter(int index) async {
    final result = await Navigator.push<QuickFilter>(
      context,
      MaterialPageRoute(
        builder: (context) => FilterEditorScreen(
          columns: widget.columns,
          existingFilter: _filters[index],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _filters[index] = result;
      });
    }
  }

  void _removeFilter(int index) {
    setState(() {
      _filters.removeAt(index);
    });
  }

  void _onPop() {
    Navigator.of(context).pop({
      'enabled': _isEnabled,
      'filters': _filters,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Filter Settings'),
        ),
        floatingActionButton: _isEnabled 
          ? FloatingActionButton(
              onPressed: _addFilter,
              backgroundColor: theme.primaryColor,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
        body: ListView(
          children: [
            SwitchListTile(
              title: const Text('Enable Filtering'),
              subtitle: const Text('Show filter options for this tab'),
              value: _isEnabled,
              activeColor: theme.primaryColor,
              onChanged: (val) {
                setState(() => _isEnabled = val);
              },
            ),
            if (_isEnabled) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Active Filters', style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold)),
              ),
              if (_filters.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('No custom filters added yet.', style: TextStyle(color: theme.disabledColor, fontStyle: FontStyle.italic)),
                ),
              ..._filters.asMap().entries.map((entry) {
                final index = entry.key;
                final filter = entry.value;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                    child: Icon(Icons.filter_alt_outlined, color: theme.primaryColor, size: 20),
                  ),
                  title: Text(filter.label),
                  subtitle: Text('${filter.field} ${filter.operator} ${filter.value}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editFilter(index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _removeFilter(index),
                      ),
                    ],
                  ),
                );
              }),
            ] else ...[
               Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(
                  child: Text(
                    'Filters are disabled for this view.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.disabledColor),
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
