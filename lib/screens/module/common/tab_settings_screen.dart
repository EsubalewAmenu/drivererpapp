import 'package:flutter/material.dart';
import '../../../models/schema_models.dart';
import '../../../theme/app_theme.dart';
import '../filter/filter_editor_screen.dart';
part 'tab_settings/save.dart';
part 'tab_settings/list.dart';
part 'tab_settings/detail.dart';
part 'tab_settings/filters.dart';

class TabSettingsScreen extends StatefulWidget {
  final TabConfig tab;
  final Color primaryColor;
  final Function(Map<String, dynamic>)? onSave;

  const TabSettingsScreen({
    super.key,
    required this.tab,
    required this.primaryColor,
    this.onSave,
  });

  @override
  State<TabSettingsScreen> createState() => _TabSettingsScreenState();
}

class _TabSettingsScreenState extends State<TabSettingsScreen> with SingleTickerProviderStateMixin, _TabSettingsListMixin, _TabSettingsDetailMixin, _TabSettingsFiltersMixin, _TabSettingsSaveMixin {
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

  // Conditional Logic State (List)
  bool _listUseConditionalTitle = false;
  String? _listTitleLogicCondition;
  String? _listTitleLogicTruthy;
  String? _listTitleLogicFalsy;

  bool _listUseConditionalSubtitle = false;
  String? _listSubtitleLogicCondition;
  String? _listSubtitleLogicTruthy;
  String? _listSubtitleLogicFalsy;

  bool _listUseConditionalTrailing = false;
  String? _listTrailingLogicCondition;
  String? _listTrailingLogicTruthy;
  String? _listTrailingLogicFalsy;

  // Conditional Logic State (Detail)
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

    // Initialize list logic
    if (config?.titleLogic != null) {
      _listUseConditionalTitle = true;
      _listTitleLogicCondition = config!.titleLogic!.conditionKey;
      _listTitleLogicTruthy = config.titleLogic!.truthyKey;
      _listTitleLogicFalsy = config.titleLogic!.falsyKey;
    }
    if (config?.subtitleLogic != null) {
      _listUseConditionalSubtitle = true;
      _listSubtitleLogicCondition = config!.subtitleLogic!.conditionKey;
      _listSubtitleLogicTruthy = config.subtitleLogic!.truthyKey;
      _listSubtitleLogicFalsy = config.subtitleLogic!.falsyKey;
    }
    if (config?.trailingLogic != null) {
      _listUseConditionalTrailing = true;
      _listTrailingLogicCondition = config!.trailingLogic!.conditionKey;
      _listTrailingLogicTruthy = config.trailingLogic!.truthyKey;
      _listTrailingLogicFalsy = config.trailingLogic!.falsyKey;
    }

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
}

