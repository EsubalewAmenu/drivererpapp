import 'dart:async';
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
import 'widgets/module_filter_bar.dart';
import 'widgets/module_list_item.dart';
import 'widgets/module_status_views.dart';

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
  Timer? _searchTimer;

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
    if (_scrollController.hasClients && _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final isFilterEmpty = _activeFilter == null || _activeFilter == 'all';
      
      // Allow pagination if not loading, has more data, 
      // AND (is not searching OR is searching with enough chars)
      bool canLoadMore = !_isLoading && !_isLoadingMore && !_hasErrorLoadingMore && _hasMore;
      bool isSearchActive = _searchQuery.isNotEmpty;
      bool isSearchRemote = _searchQuery.length >= 2;

      if (canLoadMore) {
        // ALWAYS allow pagination if not currently busy.
        // If it's a short search (<2 chars), we fetch more unfiltered data 
        // from the server and then apply the local filter to find more matches.
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
    final newQuery = _searchController.text;
    
    // local filtering for quick feedback if length < 2
    if (newQuery.length < 2) {
       if (_searchQuery.length >= 2) {
         // Clear remote search
         _searchQuery = newQuery;
         _loadData(refresh: true);
       } else {
         _searchQuery = newQuery;
         _applyFilters();
       }
       return;
    }

    // Debounce remote search (>= 2 chars)
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _searchQuery = newQuery;
          _loadData(refresh: true);
        });
      }
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
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
      QuickFilter? selectedFilter;
      if (_activeFilter != null && _activeFilter != 'all') {
        try {
          selectedFilter = _activeFilters.firstWhere((f) => f.key == _activeFilter);
        } catch (_) {}
      }

      final fetchedData = await _driveService.fetchRecords(
        widget.module!.id, 
        widget.module!.name, 
        widget.tab.id,
        offset: _currentOffset,
        limit: _pageSize,
        fetchSubTables: false, // Performance optimization for List View
        descending: true,
        searchQuery: _searchQuery.length >= 2 ? _searchQuery : null,
        quickFilter: selectedFilter != null ? {
          'field': selectedFilter.field,
          'operator': selectedFilter.operator,
          'value': selectedFilter.value,
        } : null,
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

      // We rely on server-side sorting (record_id DESC) from Google Sheets/Gviz.
      // Local sorting is only a fallback or for newly added items if any.
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen to SchemaProvider for the most up-to-date configuration
    final latestModule = context.watch<SchemaProvider>().getFromMemory(widget.module?.id ?? '');
    final currentTab = latestModule?.tabs.firstWhere((t) => t.id == widget.tab.id, orElse: () => widget.tab) ?? widget.tab;

    final theme = Theme.of(context);

    if (_errorMessage != null && _allData.isEmpty) {
      return ModuleErrorView(
        message: _errorMessage!,
        primaryColor: widget.primaryColor,
        onRetry: () => _loadData(refresh: true),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          ModuleFilterBar(
            tab: currentTab,
            primaryColor: widget.primaryColor,
            searchController: _searchController,
            activeFilter: _activeFilter,
            activeFilters: _activeFilters,
            showFilters: _showFilters,
            onFilterChanged: (filterKey) {
              setState(() {
                _activeFilter = filterKey;
              });
              _loadData(refresh: true);
            },
            onOpenSettings: _openSettings,
          ),
          Expanded(child: _buildListView(currentTab)),
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
                tab: currentTab,
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
      
      final updatedTab = widget.tab.copyWith(
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
        const SnackBar(content: Text('Saving configuration...'), duration: Duration(seconds: 5)),
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
        
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
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

  Widget _buildListView(TabConfig tab) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    if (_filteredData.isEmpty) {
      return const ModuleEmptyView();
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
          
          return ModuleListItem(
            item: item,
            tab: tab,
            primaryColor: widget.primaryColor,
            onTap: () => _openRecordDetail(item),
          );
        },
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
}
