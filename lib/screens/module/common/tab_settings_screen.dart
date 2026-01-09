import 'package:flutter/material.dart';
import '../../../models/schema_models.dart';
import '../../../theme/app_theme.dart';
import '../filter/filter_editor_screen.dart';

class TabSettingsScreen extends StatefulWidget {
  final TabConfig tab;
  final Color primaryColor;

  const TabSettingsScreen({
    super.key,
    required this.tab,
    required this.primaryColor,
  });

  @override
  State<TabSettingsScreen> createState() => _TabSettingsScreenState();
}

class _TabSettingsScreenState extends State<TabSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Filter State
  late List<QuickFilter> _filters;
  late bool _filtersEnabled;
  
  // Display State (List)
  late String _selectedTemplate;
  String? _titleKey;
  String? _subtitleKey;
  String? _trailingKey;
  List<String> _detailKeys = [];

  // Detail State (Item)
  late String _selectedDetailTemplate;
  String? _detailTitleKey;
  String? _detailSubtitleKey;
  String? _detailImageKey;
  late bool _detailShowAll;
  List<String> _detailFields = [];

  // Conditional Logic State
  bool _useConditionalTitle = false;
  String? _titleLogicCondition;
  String? _titleLogicTruthy;
  String? _titleLogicFalsy;

  bool _useConditionalSubtitle = false;
  String? _subtitleLogicCondition;
  String? _subtitleLogicTruthy;
  String? _subtitleLogicFalsy;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Initialize Filters
    _filters = List.from(widget.tab.quickFilters ?? []);
    _filtersEnabled = widget.tab.enableCustomFilters ?? true;
    
    // Initialize Display
    final config = widget.tab.listTemplate;
    _selectedTemplate = config?.template ?? 'high_density';
    _titleKey = config?.titleKey ?? (widget.tab.columns.isNotEmpty ? widget.tab.columns[0].key : null);
    _subtitleKey = config?.subtitleKey ?? (widget.tab.columns.length > 1 ? widget.tab.columns[1].key : null);
    _trailingKey = config?.trailingKey;
    _detailKeys = List.from(config?.detailKeys ?? []);

    // Initialize Detail
    final detailConfig = widget.tab.detailTemplate;
    _selectedDetailTemplate = detailConfig?.template ?? 'standard';
    _detailTitleKey = detailConfig?.titleKey ?? _titleKey;
    _detailSubtitleKey = detailConfig?.subtitleKey ?? _subtitleKey;
    
    // Auto-detect image key if not set
    if (detailConfig?.imageKey != null) {
      _detailImageKey = detailConfig!.imageKey;
    } else {
      try {
        _detailImageKey = widget.tab.columns.firstWhere((c) => c.type == 'image').key;
      } catch (_) {
        _detailImageKey = null;
      }
    }
    
    _detailShowAll = detailConfig?.showAllFields ?? true;
    _detailFields = List.from(detailConfig?.detailKeys ?? []);

    // Initialize logic
    if (detailConfig?.titleLogic != null) {
      _useConditionalTitle = true;
      _titleLogicCondition = detailConfig!.titleLogic!.conditionKey;
      _titleLogicTruthy = detailConfig.titleLogic!.truthyKey;
      _titleLogicFalsy = detailConfig.titleLogic!.falsyKey;
    }
    if (detailConfig?.subtitleLogic != null) {
      _useConditionalSubtitle = true;
      _subtitleLogicCondition = detailConfig!.subtitleLogic!.conditionKey;
      _subtitleLogicTruthy = detailConfig.subtitleLogic!.truthyKey;
      _subtitleLogicFalsy = detailConfig.subtitleLogic!.falsyKey;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop({
      'enableFilters': _filtersEnabled,
      'filters': _filters,
      'listTemplate': ListTemplateConfig(
        template: _selectedTemplate,
        titleKey: _titleKey,
        subtitleKey: _subtitleKey,
        trailingKey: _trailingKey,
        detailKeys: _detailKeys,
      ),
      'detailTemplate': DetailTemplateConfig(
        template: _selectedDetailTemplate,
        titleKey: _useConditionalTitle ? null : _detailTitleKey,
        titleLogic: _useConditionalTitle && _titleLogicCondition != null 
          ? ConditionalLogic(
              conditionKey: _titleLogicCondition!, 
              truthyKey: _titleLogicTruthy ?? '', 
              falsyKey: _titleLogicFalsy ?? ''
            ) 
          : null,
        subtitleKey: _useConditionalSubtitle ? null : _detailSubtitleKey,
        subtitleLogic: _useConditionalSubtitle && _subtitleLogicCondition != null
          ? ConditionalLogic(
              conditionKey: _subtitleLogicCondition!, 
              truthyKey: _subtitleLogicTruthy ?? '', 
              falsyKey: _subtitleLogicFalsy ?? ''
            )
          : null,
        imageKey: _detailImageKey,
        showAllFields: _detailShowAll,
        detailKeys: _detailFields,
      ),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('${widget.tab.label} Settings', style: AppTheme.inter(fontWeight: FontWeight.w700, fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: widget.primaryColor,
          unselectedLabelColor: theme.textTheme.bodyMedium?.color,
          indicatorColor: widget.primaryColor,
          tabs: const [
            Tab(text: 'Filters'),
            Tab(text: 'List'),
            Tab(text: 'Details'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('Save', style: TextStyle(color: widget.primaryColor, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      floatingActionButton: _tabController.index == 0 && _filtersEnabled
        ? FloatingActionButton(
            onPressed: _addFilter,
            backgroundColor: widget.primaryColor,
            child: const Icon(Icons.add, color: Colors.white),
          )
        : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFiltersTab(theme),
          _buildDisplayTab(theme),
          _buildDetailTab(theme),
        ],
      ),
    );
  }

  // --- Display Settings UI (List) ---

  Widget _buildDisplayTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CHOOSE TEMPLATE', style: _sectionHeaderStyle(theme)),
          const SizedBox(height: 16),
          _buildTemplateOption(
            'high_density', 
            'High Density', 
            'Compact rows with status indicator', 
            Icons.reorder_rounded
          ),
          const SizedBox(height: 12),
          _buildTemplateOption(
            'standard', 
            'Standard Card', 
            'Detailed cards with trailing info and labels', 
            Icons.view_agenda_rounded
          ),
          const SizedBox(height: 32),
          
          Text('COLUMN MAPPING', style: _sectionHeaderStyle(theme)),
          const SizedBox(height: 16),
          _buildColumnDropdown('Title Column', _titleKey, (val) => setState(() => _titleKey = val)),
          const SizedBox(height: 16),
          _buildColumnDropdown('Subtitle Column', _subtitleKey, (val) => setState(() => _subtitleKey = val)),
          
          if (_selectedTemplate == 'standard') ...[
            const SizedBox(height: 16),
            _buildColumnDropdown('Trailing Column (Badge)', _trailingKey, (val) => setState(() => _trailingKey = val), isOptional: true),
            const SizedBox(height: 32),
            Text('EXTRA DETAILS', style: _sectionHeaderStyle(theme)),
            const SizedBox(height: 8),
            ...widget.tab.columns.map((col) {
              if (col.key == _titleKey || col.key == _subtitleKey || col.key == _trailingKey) {
                return const SizedBox.shrink();
              }
              return CheckboxListTile(
                title: Text(col.label, style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
                value: _detailKeys.contains(col.key),
                activeColor: widget.primaryColor,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _detailKeys.add(col.key);
                    } else {
                      _detailKeys.remove(col.key);
                    }
                  });
                },
              );
            }),
          ],
        ],
      ),
    );
  }

  // --- Detail Settings UI (Item) ---

  Widget _buildDetailTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CHOOSE LAYOUT', style: _sectionHeaderStyle(theme)),
          const SizedBox(height: 16),
          _buildDetailTemplateOption(
            'standard', 
            'Standard Card', 
            'Classic centered header with rounded borders', 
            Icons.crop_16_9_rounded
          ),
          const SizedBox(height: 12),
          _buildDetailTemplateOption(
            'modern', 
            'Modern Visual', 
            'Full-width image header with integrated titles', 
            Icons.view_quilt_rounded
          ),
          const SizedBox(height: 32),
          
          Text('HEADER CONFIGURATION', style: _sectionHeaderStyle(theme)),
          const SizedBox(height: 16),
          
          // Conditional Title
          SwitchListTile(
            title: const Text('Conditional Title'),
            subtitle: const Text('Change title based on record data'),
            value: _useConditionalTitle,
            activeColor: widget.primaryColor,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => setState(() => _useConditionalTitle = val),
          ),
          if (_useConditionalTitle) ...[
            const SizedBox(height: 8),
            _buildColumnDropdown('Condition (e.g. Is Individual?)', _titleLogicCondition, (val) => setState(() => _titleLogicCondition = val)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildColumnDropdown('If True', _titleLogicTruthy, (val) => setState(() => _titleLogicTruthy = val))),
                const SizedBox(width: 12),
                Expanded(child: _buildColumnDropdown('If False', _titleLogicFalsy, (val) => setState(() => _titleLogicFalsy = val))),
              ],
            ),
          ] else
            _buildColumnDropdown('Main Title', _detailTitleKey, (val) => setState(() => _detailTitleKey = val)),
          
          const SizedBox(height: 24),
          
          // Conditional Subtitle
          SwitchListTile(
            title: const Text('Conditional Subtitle'),
            subtitle: const Text('Change subtitle based on record data'),
            value: _useConditionalSubtitle,
            activeColor: widget.primaryColor,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => setState(() => _useConditionalSubtitle = val),
          ),
          if (_useConditionalSubtitle) ...[
            const SizedBox(height: 8),
            _buildColumnDropdown('Condition Column', _subtitleLogicCondition, (val) => setState(() => _subtitleLogicCondition = val)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildColumnDropdown('If True', _subtitleLogicTruthy, (val) => setState(() => _subtitleLogicTruthy = val))),
                const SizedBox(width: 12),
                Expanded(child: _buildColumnDropdown('If False', _subtitleLogicFalsy, (val) => setState(() => _subtitleLogicFalsy = val))),
              ],
            ),
          ] else
            _buildColumnDropdown('Subtitle', _detailSubtitleKey, (val) => setState(() => _detailSubtitleKey = val), isOptional: true),
          
          const SizedBox(height: 24),
          _buildColumnDropdown('Header Image', _detailImageKey, (val) => setState(() => _detailImageKey = val), isOptional: true),
          
          const SizedBox(height: 32),
          Text('FIELD VISIBILITY', style: _sectionHeaderStyle(theme)),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Show All Fields'),
            subtitle: const Text('Automatically display all visible columns'),
            value: _detailShowAll,
            activeColor: widget.primaryColor,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => setState(() => _detailShowAll = val),
          ),
          
          if (!_detailShowAll) ...[
            const SizedBox(height: 16),
            ...widget.tab.columns.where((c) => c.hidden != true).map((col) {
              return CheckboxListTile(
                title: Text(col.label, style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
                value: _detailFields.contains(col.key),
                activeColor: widget.primaryColor,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _detailFields.add(col.key);
                    } else {
                      _detailFields.remove(col.key);
                    }
                  });
                },
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailTemplateOption(String value, String title, String subtitle, IconData icon) {
    final isSelected = _selectedDetailTemplate == value;
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: () => setState(() => _selectedDetailTemplate = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? widget.primaryColor.withValues(alpha: 0.1) : theme.cardTheme.color,
          border: Border.all(
            color: isSelected ? widget.primaryColor : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? widget.primaryColor : theme.iconTheme.color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.inter(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? widget.primaryColor : theme.textTheme.bodyLarge?.color,
                  )),
                  Text(subtitle, style: AppTheme.inter(
                    fontSize: 12,
                    color: theme.textTheme.bodyMedium?.color,
                  )),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: widget.primaryColor, size: 20),
          ],
        ),
      ),
    );
  }

  TextStyle _sectionHeaderStyle(ThemeData theme) => AppTheme.inter(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
    letterSpacing: 1.2
  );

  Widget _buildTemplateOption(String value, String title, String subtitle, IconData icon) {
    final isSelected = _selectedTemplate == value;
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: () => setState(() => _selectedTemplate = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? widget.primaryColor.withValues(alpha: 0.1) : theme.cardTheme.color,
          border: Border.all(
            color: isSelected ? widget.primaryColor : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? widget.primaryColor : theme.iconTheme.color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.inter(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? widget.primaryColor : theme.textTheme.bodyLarge?.color,
                  )),
                  Text(subtitle, style: AppTheme.inter(
                    fontSize: 12,
                    color: theme.textTheme.bodyMedium?.color,
                  )),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: widget.primaryColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildColumnDropdown(String label, String? value, Function(String?) onChanged, {bool isOptional = false}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.cardTheme.color,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          items: [
            if (isOptional) const DropdownMenuItem(value: null, child: Text('None')),
            ...widget.tab.columns.map((col) => DropdownMenuItem(
              value: col.key,
              child: Text(col.label),
            )).toList(),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }

  // --- Filter Settings UI ---

  Widget _buildFiltersTab(ThemeData theme) {
    // We update FAB visibility when switching to this tab
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    return ListView(
      children: [
        SwitchListTile(
          title: const Text('Enable Filtering'),
          subtitle: const Text('Show filter options for this tab'),
          value: _filtersEnabled,
          activeColor: widget.primaryColor,
          onChanged: (val) {
            setState(() => _filtersEnabled = val);
          },
        ),
        if (_filtersEnabled) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('ACTIVE QUICK FILTERS', style: _sectionHeaderStyle(theme)),
          ),
          if (_filters.isEmpty)
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
          ..._filters.asMap().entries.map((entry) {
            final index = entry.key;
            final filter = entry.value;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: widget.primaryColor.withValues(alpha: 0.1),
                child: Icon(Icons.filter_alt_outlined, color: widget.primaryColor, size: 20),
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
        _filters.add(result);
      });
    }
  }

  void _editFilter(int index) async {
    final result = await Navigator.push<QuickFilter>(
      context,
      MaterialPageRoute(
        builder: (context) => FilterEditorScreen(
          columns: widget.tab.columns,
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
}

