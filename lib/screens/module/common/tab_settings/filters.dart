part of 'package:drivererpapp/screens/module/common/tab_settings_screen.dart';

mixin _TabSettingsFiltersMixin on State<TabSettingsScreen> {
  Widget _buildFiltersTab(ThemeData theme) {
    // We update FAB visibility when switching to this tab
    (this as _TabSettingsScreenState)._tabController.addListener(() {
      if (mounted) setState(() {});
    });

    return ListView(
      children: [
        SwitchListTile(
          title: const Text('Enable Filtering'),
          subtitle: const Text('Show filter options for this tab'),
          value: (this as _TabSettingsScreenState)._filtersEnabled,
          activeThumbColor: widget.primaryColor,
          onChanged: (val) {
            setState(() => (this as _TabSettingsScreenState)._filtersEnabled = val);
          },
        ),
        if ((this as _TabSettingsScreenState)._filtersEnabled) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('ACTIVE QUICK FILTERS', style: (this as _TabSettingsScreenState)._sectionHeaderStyle(theme)),
          ),
          if ((this as _TabSettingsScreenState)._filters.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(Icons.filter_list_off_rounded, size: 48, color: theme.disabledColor),
                  const SizedBox(height: 16),
                  Text('No custom filters added yet.', style: TextStyle(color: theme.disabledColor, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ...(this as _TabSettingsScreenState)._filters.asMap().entries.map((entry) {
            final index = entry.key;
            final filter = entry.value;
            return ListTile(
                leading: CircleAvatar(
                backgroundColor: widget.primaryColor.withValues(alpha: 0.1),
                child: Icon(Icons.filter_alt_outlined, color: widget.primaryColor, size: 20),
              ),
              title: Text(filter.label),
              subtitle: Text(_formatFilterRules(filter)),
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
            padding: const EdgeInsets.all(48.0),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.visibility_off_outlined, size: 64, color: theme.disabledColor.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'Filters are disabled for this tab.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.disabledColor),
                  ),
                ],
              ),
            ),
          ),
        ]
      ],
    );
  }

  void _addFilter() async {
    final result = await Navigator.push<QuickFilter>(
      context,
      MaterialPageRoute(
        builder: (context) => FilterEditorScreen(columns: widget.tab.columns),
      ),
    );

    if (result != null) {
      setState(() {
        (this as _TabSettingsScreenState)._filters.add(result);
      });
    }
  }

  void _editFilter(int index) async {
    final result = await Navigator.push<QuickFilter>(
      context,
      MaterialPageRoute(
        builder: (context) => FilterEditorScreen(
          columns: widget.tab.columns,
          existingFilter: (this as _TabSettingsScreenState)._filters[index],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        (this as _TabSettingsScreenState)._filters[index] = result;
      });
    }
  }

  void _removeFilter(int index) {
    setState(() {
      (this as _TabSettingsScreenState)._filters.removeAt(index);
    });
  }

  String _formatFilterRules(QuickFilter filter) {
    if (filter.rules.isEmpty) return '';
    return filter.rules.map((rule) {
      final colLabel = widget.tab.columns.firstWhere(
        (c) => c.key == rule.field,
        orElse: () => ColumnConfig(key: rule.field, label: rule.field, type: 'text'),
      ).label;
      return '$colLabel ${rule.operator} ${rule.value ?? ''}'.trim();
    }).join(' AND ');
  }
}
