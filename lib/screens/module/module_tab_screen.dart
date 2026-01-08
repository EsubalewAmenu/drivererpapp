import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/schema_models.dart';
import '../../providers/drive_provider.dart';
import '../../services/drive_service.dart';
import '../../theme/app_theme.dart';
import '../dynamic_form_screen.dart';
import '../record_detail_screen.dart';
import 'filter/filter_management_screen.dart';

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
      if (!_isLoading && !_isLoadingMore && _hasMore && _searchQuery.isEmpty && isFilterEmpty) {
        _loadData(refresh: false);
      }
    }
  }

  @override
  void didUpdateWidget(ModuleTabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the tab config or module schema changed, we might need to refresh
    if (oldWidget.tab != widget.tab || oldWidget.module != widget.module) {
      if (oldWidget.tab.id != widget.tab.id) {
         _activeFilters = List.from(widget.tab.quickFilters ?? []);
         _showFilters = true;
         _activeFilter = 'all';
      }
      debugPrint('Tab or Module schema updated for ${widget.tab.id}, refreshing tab...');
      _loadData(refresh: true);
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
        });
      }
    } else {
      if (mounted) setState(() => _isLoadingMore = true);
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
          _isLoadingMore = false;
          if (refresh) {
            _errorMessage = 'Records unavailable (Offline)';
          } else {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Failed to load more records')),
             );
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
    final hasCustomFilters = widget.tab.enableCustomFilters ?? true;
    
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
          if (hasCustomFilters) ...[
            const SizedBox(width: 12),
            InkWell(
              onTap: _openFilterManager,
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
          ]
        ],
      ),
    );
  }

  void _openFilterManager() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FilterManagementScreen(
          columns: widget.tab.columns, 
          initialFilters: _activeFilters, 
          initialEnabled: _showFilters
        ),
      ),
    );

    if (result != null && result is Map) {
      setState(() {
        _showFilters = result['enabled'];
        _activeFilters = result['filters'];
        // If disabled or active filter removed, reset selection
        bool activeExists = _activeFilters.any((f) => f.key == _activeFilter);
        if (!_showFilters || !activeExists) {
          _activeFilter = 'all';
        }
        _applyFilters();
      });
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
        child: Text(
          'No items found',
          style: AppTheme.inter(color: theme.textTheme.bodyMedium?.color),
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _filteredData.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == _filteredData.length) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ));
        }
        final item = _filteredData[index];
        return _buildHighDensityCard(item);
      },
    );
  }

  Widget _buildHighDensityCard(Map<String, dynamic> item) {
    final theme = Theme.of(context);
    // Use the first column as title, second as subtitle
    final titleKey = widget.tab.columns.isNotEmpty ? widget.tab.columns[0].key : '';
    final subtitleKey = widget.tab.columns.length > 1 ? widget.tab.columns[1].key : '';

    return Card(
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecordDetailScreen(
                data: item,
                columns: widget.tab.columns,
                primaryColor: widget.primaryColor,
                title: titleKey.isNotEmpty ? (item[titleKey]?.toString() ?? 'Details') : 'Details',
                settings: widget.settings,
              ),
            ),
          );
        },
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
                    if (titleKey.isNotEmpty)
                      Text(
                        item[titleKey]?.toString() ?? '',
                        style: AppTheme.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    if (subtitleKey.isNotEmpty)
                      Text(
                        item[subtitleKey]?.toString() ?? '',
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
