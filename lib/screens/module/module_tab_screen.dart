import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/schema_models.dart';
import '../../providers/drive_provider.dart';
import '../../providers/schema_provider.dart'; // Add this
import '../../services/drive_service.dart';
import '../../theme/app_theme.dart';
import '../dynamic_form_screen.dart';
import '../record_detail_screen.dart';
import 'common/tab_settings_screen.dart';

class ModuleTabScreen extends StatefulWidget {
  final TabConfig tab;
  final Color primaryColor;
  final Map<String, SettingItem> settings;
  final ModuleSchema? module;

  const ModuleTabScreen({
    super.key, 
    required this.tab, 
    required this.primaryColor,
    this.settings = const {},
    this.module,
  });

  @override
  State<ModuleTabScreen> createState() => _ModuleTabScreenState();
}

class _ModuleTabScreenState extends State<ModuleTabScreen> {
  late final DriveService _driveService;
  
  List<Map<String, dynamic>> _allData = [];
  List<Map<String, dynamic>> _filteredData = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _hasErrorLoadingMore = false;
  int _currentOffset = 0;
  static const int _pageSize = 20;

  String? _errorMessage;
  String _searchQuery = '';
  String? _activeFilter;
  List<QuickFilter> _activeFilters = [];
  bool _showFilters = true;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _driveService = Provider.of<DriveProvider>(context, listen: false).driveService!;
    _activeFilters = List.from(widget.tab.quickFilters ?? []);
    _showFilters = widget.tab.enableCustomFilters ?? true;
    // Delay loading to keep navigation smooth
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _loadData(refresh: true);
    });
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9) {
      final isFilterEmpty = _activeFilter == null || _activeFilter == 'all';
      if (!_isLoading && !_isLoadingMore && !_hasErrorLoadingMore && _hasMore && _searchQuery.isEmpty && isFilterEmpty) {
        _loadData(refresh: false);
      }
    }
  }

  @override
  void didUpdateWidget(ModuleTabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the tab config or module schema changed, we might need to update state
    if (oldWidget.tab != widget.tab || oldWidget.module != widget.module) {
      debugPrint('Tab or Module schema updated for ${widget.tab.id}, updating sync state...');
      
      setState(() {
        _activeFilters = List.from(widget.tab.quickFilters ?? []);
        _showFilters = widget.tab.enableCustomFilters ?? true;
        
        // Reset active filter if it no longer exists in the new list
        if (_activeFilter != 'all' && _activeFilter != null) {
          bool exists = _activeFilters.any((f) => f.key == _activeFilter);
          if (!exists) _activeFilter = 'all';
        }
      });
      
      // If critical fields changed, reload data
      if (oldWidget.tab.id != widget.tab.id) {
        _loadData(refresh: true);
      } else {
        _applyFilters();
      }
    }
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {
        _searchQuery = _searchController.text;
        _applyFilters();
      });
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool refresh = false}) async {
    if (widget.module == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (refresh) {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
          _allData = [];
          _filteredData = [];
          _currentOffset = 0;
          _hasMore = true;
          _hasErrorLoadingMore = false;
        });
      }
    } else {
      if (mounted) setState(() {
         _isLoadingMore = true;
         _hasErrorLoadingMore = false;
      });
    }

    // Fetch fresh data from DriveService
    try {
      final fetchedData = await _driveService.fetchRecords(
        widget.module!.id, 
        widget.module!.name, 
        widget.tab.id,
        offset: _currentOffset,
        limit: _pageSize,
        fetchSubTables: false, // Performance optimization for List View
        descending: true,
      );
      
      if (mounted) {
        setState(() {
          if (refresh) {
            _allData = fetchedData;
          } else {
            _allData.addAll(fetchedData);
          }
          
          if (fetchedData.length < _pageSize) {
            _hasMore = false;
          } else {
            _currentOffset += _pageSize;
          }
          
          _applyFilters();
          _isLoading = false;
          _isLoadingMore = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('Error fetching data for ${widget.tab.id}: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          // In pagination, stop loading more spinner
          _isLoadingMore = false;
          
          if (refresh) {
            // Check for network related errors
            final errorString = e.toString().toLowerCase();
            if (errorString.contains('socketexception') || 
                errorString.contains('failed host lookup') || 
                errorString.contains('network is unreachable') ||
                errorString.contains('offline')) {
              _errorMessage = 'Records unavailable (Offline)';
            } else {
              _errorMessage = 'Failed to load records. Please try again.';
            }
          } else {
             _hasErrorLoadingMore = true;
          }
        });
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredData = _allData.where((item) {
        // Search Filter
        final matchesSearch = item.values.any((val) => 
          val.toString().toLowerCase().contains(_searchQuery.toLowerCase())
        );
        
        // Quick Filter
        bool matchesQuickFilter = true;
        if (_activeFilter != null && _activeFilter != 'all') {
           try {
             // Look in active filters
             final filter = _activeFilters.firstWhere((f) => f.key == _activeFilter);
             
             final itemValue = item[filter.field];
             final filterVal = filter.value.toString().toLowerCase();
             final itemValStr = itemValue?.toString().toLowerCase() ?? '';

             if (filter.operator == '==') {
               matchesQuickFilter = itemValStr == filterVal;
             } else if (filter.operator == '!=') { 
               matchesQuickFilter = itemValStr != filterVal;
             } else if (filter.operator == 'contains') {
               matchesQuickFilter = itemValStr.contains(filterVal);
             } else if (filter.operator == 'startsWidth') {
               matchesQuickFilter = itemValStr.startsWith(filterVal);
             } else if (filter.operator == '>') {
                // Try numeric comparison first
                final numItem = num.tryParse(itemValStr);
                final numFilter = num.tryParse(filterVal);
                if (numItem != null && numFilter != null) {
                  matchesQuickFilter = numItem > numFilter;
                } else {
                  matchesQuickFilter = itemValStr.compareTo(filterVal) > 0;
                }
             } else if (filter.operator == '<') {
                final numItem = num.tryParse(itemValStr);
                final numFilter = num.tryParse(filterVal);
                if (numItem != null && numFilter != null) {
                  matchesQuickFilter = numItem < numFilter;
                } else {
                  matchesQuickFilter = itemValStr.compareTo(filterVal) < 0;
                }
             }
           } catch (e) {
             // Filter not found or error
             matchesQuickFilter = true;
           }
        }

        return matchesSearch && matchesQuickFilter;
      }).toList();

      // Sort by record_id in descending order (newest first)
      _filteredData.sort((a, b) {
        final aId = a['record_id']?.toString() ?? '';
        final bId = b['record_id']?.toString() ?? '';
        // If record_id is missing, fallback to empty string
        return bId.compareTo(aId);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Note: removed full-screen loading check to allow shell to render

    final theme = Theme.of(context);

    if (_errorMessage != null && _allData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: AppTheme.inter(color: theme.textTheme.bodyMedium?.color),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _loadData(refresh: true), 
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _buildSearchBar(),
          _buildQuickFilters(),
          Expanded(child: _buildListView()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: widget.primaryColor,
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DynamicFormScreen(
                tab: widget.tab,
                primaryColor: widget.primaryColor,
                settings: widget.settings,
                module: widget.module,
              ),
            ),
          );
          // Refresh data on return
          if (_currentOffset == 0) _loadData(refresh: true);
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: AppTheme.inter(color: theme.textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                hintText: 'Search ${widget.tab.label.toLowerCase()}...',
                hintStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                prefixIcon: Icon(Icons.search_rounded, color: theme.textTheme.bodyMedium?.color),
                filled: true,
                fillColor: theme.cardTheme.color,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: _openSettings,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.tune_rounded, color: widget.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  void _openSettings() async {
    // Get latest tab configuration
    final latestModule = context.read<SchemaProvider>().getFromMemory(widget.module?.id ?? '');
    final currentTab = latestModule?.tabs.firstWhere((t) => t.id == widget.tab.id, orElse: () => widget.tab) ?? widget.tab;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => TabSettingsScreen(
          tab: currentTab,
          primaryColor: widget.primaryColor,
        ),
      ),
    );

    if (result != null) {
      if (!mounted) return;

      final newEnabled = result['enableFilters'] as bool;
      final newFilters = result['filters'] as List<QuickFilter>;
      final newListTemplate = result['listTemplate'] as ListTemplateConfig;
      final newDetailTemplate = result['detailTemplate'] as DetailTemplateConfig;

      _saveConfiguration(
        enableFilters: newEnabled,
        filters: newFilters,
        listTemplate: newListTemplate,
        detailTemplate: newDetailTemplate,
      );
    }
  }

  Future<void> _saveConfiguration({
    required bool enableFilters,
    required List<QuickFilter> filters,
    ListTemplateConfig? listTemplate,
    DetailTemplateConfig? detailTemplate,
  }) async {
    try {
      final schemaProvider = context.read<SchemaProvider>();
      
      // Always get the latest module from memory to avoid stale data
      final currentModule = schemaProvider.getFromMemory(widget.module!.id) ?? widget.module!;
      
      final updatedTab = TabConfig(
        id: widget.tab.id,
        label: widget.tab.label,
        columns: widget.tab.columns,
        quickFilters: filters,
        enableCustomFilters: enableFilters,
        listTemplate: listTemplate,
        detailTemplate: detailTemplate,
      );

      final updatedTabs = currentModule.tabs.map((t) {
        return t.id == widget.tab.id ? updatedTab : t;
      }).toList();

      final updatedModule = ModuleSchema(
        id: currentModule.id,
        name: currentModule.name,
        icon: currentModule.icon,
        primaryColor: currentModule.primaryColor,
        version: currentModule.version,
        settings: currentModule.settings,
        dashboard: currentModule.dashboard,
        tabs: updatedTabs,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saving configuration...'), duration: Duration(seconds: 1)),
      );

      await schemaProvider.service.saveModuleConfig(currentModule.id, updatedModule);
      schemaProvider.updateMemoryCache(currentModule.id, updatedModule);

      if (mounted) {
        setState(() {
          _showFilters = enableFilters;
          _activeFilters = filters;
          // If disabled or active filter removed, reset selection
          bool activeExists = _activeFilters.any((f) => f.key == _activeFilter);
          if (!_showFilters || !activeExists) {
            _activeFilter = 'all';
          }
          _applyFilters();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuration saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving configuration: $e')),
        );
      }
    }
  }

  Widget _buildQuickFilters() {
    if (!_showFilters || _activeFilters.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final theme = Theme.of(context);

    // Filter Chips Row logic needs to handle scrolling and selection
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _activeFilters.length + 1, // +1 for "All"
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            // "All" Chip
            final isSelected = _activeFilter == null || _activeFilter == 'all';
             return FilterChip(
              label: const Text('All'),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _activeFilter = 'all';
                  _applyFilters();
                });
              },
              backgroundColor: theme.cardTheme.color,
              selectedColor: widget.primaryColor.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected ? widget.primaryColor : theme.textTheme.bodyMedium?.color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? widget.primaryColor : Colors.transparent,
                ),
              ),
              showCheckmark: false,
            );
          }
          
          final filter = _activeFilters[index - 1];
          final isSelected = _activeFilter == filter.key;

          return FilterChip(
            label: Text(filter.label),
            selected: isSelected,
            onSelected: (_) {
              setState(() {
                _activeFilter = filter.key;
                _applyFilters();
              });
            },
            backgroundColor: theme.cardTheme.color,
            selectedColor: widget.primaryColor.withValues(alpha: 0.2),
            labelStyle: TextStyle(
              color: isSelected ? widget.primaryColor : theme.textTheme.bodyMedium?.color,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? widget.primaryColor : Colors.transparent,
              ),
            ),
            showCheckmark: false,
          );
        },
      ),
    ); 
  }

  Widget _buildListView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    if (_filteredData.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 64, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.2)),
              const SizedBox(height: 16),
              Text(
                'No items found',
                style: AppTheme.inter(color: theme.textTheme.bodyMedium?.color),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(refresh: true),
      color: widget.primaryColor,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _filteredData.length + (_isLoadingMore || _hasErrorLoadingMore ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == _filteredData.length) {
            if (_hasErrorLoadingMore) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text('Failed to load more records', style: TextStyle(color: theme.colorScheme.error)),
                      TextButton.icon(
                        onPressed: () => _loadData(refresh: false),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Retry'),
                      )
                    ],
                  ),
                ),
              );
            }
            return const Center(child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ));
          }
          final item = _filteredData[index];
          
          final template = widget.tab.listTemplate?.template ?? 'high_density';
          if (template == 'standard') {
            return _buildStandardCard(item);
          }
          return _buildHighDensityCard(item);
        },
      ),
    );
  }

  dynamic _getValueFromLogic(Map<String, dynamic> data, ConditionalLogic? logic) {
    if (logic == null || logic.conditionKey == null) return null;

    final conditionValue = data[logic.conditionKey];
    bool isTruthy = false;

    if (conditionValue is bool) {
      isTruthy = conditionValue;
    } else if (conditionValue is String) {
      isTruthy = conditionValue.isNotEmpty;
    } else if (conditionValue is List) {
      isTruthy = conditionValue.isNotEmpty;
    } else if (conditionValue != null) {
      isTruthy = true;
    }

    final key = isTruthy ? logic.truthyKey : logic.falsyKey;
    return key != null ? data[key] : null;
  }

  String _resolveTitle(Map<String, dynamic> item, ListTemplateConfig? config) {
    final logicValue = _getValueFromLogic(item, config?.titleLogic);
    if (logicValue != null) return logicValue.toString();

    final titleKey = config?.titleKey ?? (widget.tab.columns.isNotEmpty ? widget.tab.columns[0].key : '');
    return item[titleKey]?.toString() ?? '';
  }

  String _resolveSubtitle(Map<String, dynamic> item, ListTemplateConfig? config) {
    final logicValue = _getValueFromLogic(item, config?.subtitleLogic);
    if (logicValue != null) return logicValue.toString();

    final subtitleKey = config?.subtitleKey ?? (widget.tab.columns.length > 1 ? widget.tab.columns[1].key : '');
    return item[subtitleKey]?.toString() ?? '';
  }

  String _resolveTrailing(Map<String, dynamic> item, ListTemplateConfig? config) {
    final logicValue = _getValueFromLogic(item, config?.trailingLogic);
    if (logicValue != null) return logicValue.toString();

    final trailingKey = config?.trailingKey;
    if (trailingKey == null) return '';
    return item[trailingKey]?.toString() ?? '';
  }

  Widget _buildStandardCard(Map<String, dynamic> item) {
    final theme = Theme.of(context);
    final config = widget.tab.listTemplate;

    final title = _resolveTitle(item, config);
    final subtitle = _resolveSubtitle(item, config);
    final trailing = _resolveTrailing(item, config);

    return Card(
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _openRecordDetail(item),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title.isNotEmpty)
                          Text(
                            title,
                            style: AppTheme.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: AppTheme.inter(
                              fontSize: 14,
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: widget.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        trailing,
                        style: AppTheme.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: widget.primaryColor,
                        ),
                      ),
                    ),
                ],
              ),
              if (config?.detailKeys != null && config!.detailKeys!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: config.detailKeys!.map((key) {
                    final col = widget.tab.columns.firstWhere((c) => c.key == key, orElse: () => widget.tab.columns.first);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          col.label.toUpperCase(),
                          style: AppTheme.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          item[key]?.toString() ?? '-',
                          style: AppTheme.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openRecordDetail(Map<String, dynamic> item) {
    // Get the latest tab config from memory if available
    final latestModule = context.read<SchemaProvider>().getFromMemory(widget.module?.id ?? '');
    final currentTab = latestModule?.tabs.firstWhere((t) => t.id == widget.tab.id, orElse: () => widget.tab) ?? widget.tab;

    final titleKey = currentTab.detailTemplate?.titleKey ?? currentTab.listTemplate?.titleKey ?? (currentTab.columns.isNotEmpty ? currentTab.columns[0].key : '');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecordDetailScreen(
          data: item,
          columns: currentTab.columns,
          primaryColor: widget.primaryColor,
          title: titleKey.isNotEmpty ? (item[titleKey]?.toString() ?? 'Details') : 'Details',
          settings: widget.settings,
          detailTemplate: currentTab.detailTemplate,
        ),
      ),
    );
  }

  Widget _buildHighDensityCard(Map<String, dynamic> item) {
    final theme = Theme.of(context);
    final config = widget.tab.listTemplate;

    final title = _resolveTitle(item, config);
    final subtitle = _resolveSubtitle(item, config);

    return Card(
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _openRecordDetail(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                        style: AppTheme.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: AppTheme.inter(
                          fontSize: 14,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.textTheme.bodyMedium?.color),
            ],
          ),
        ),
      ),
    );
  }
}
