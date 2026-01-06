import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/schema_models.dart';
import '../../providers/drive_provider.dart';
import '../../services/drive_service.dart';
import '../../theme/app_theme.dart';
import '../dynamic_form_screen.dart';
import '../record_detail_screen.dart';

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
  String _searchQuery = '';
  String? _activeFilter;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _driveService = Provider.of<DriveProvider>(context, listen: false).driveService!;
    _loadData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        _applyFilters();
      });
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    if (widget.module == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Load actual data from DriveService
    final data = await _driveService.fetchRecords(
      widget.module!.id, 
      widget.module!.name, 
      widget.tab.id
    );
    
    if (mounted) {
      setState(() {
        _allData = data;
        _filteredData = data;
        _isLoading = false;
      });
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
        if (_activeFilter != null && widget.tab.quickFilters != null) {
           try {
             final filter = widget.tab.quickFilters!.firstWhere((f) => f.key == _activeFilter);
             if (filter.key == 'all') {
               matchesQuickFilter = true;
             } else {
               final itemValue = item[filter.field];
               if (filter.operator == '==') {
                 matchesQuickFilter = itemValue.toString() == filter.value.toString();
               } else if (filter.operator == 'contains') {
                 matchesQuickFilter = itemValue.toString().contains(filter.value.toString());
               }
               // Add more operators if needed
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
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
          _loadData();
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.inter(color: AppTheme.textColor),
        decoration: InputDecoration(
          hintText: 'Search ${widget.tab.label.toLowerCase()}...',
          hintStyle: const TextStyle(color: AppTheme.secondaryTextColor),
          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.secondaryTextColor),
          filled: true,
          fillColor: AppTheme.surfaceColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildQuickFilters() {
    if (widget.tab.quickFilters == null || widget.tab.quickFilters!.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: widget.tab.quickFilters!.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = widget.tab.quickFilters![index];
          final isSelected = _activeFilter == filter.key || (_activeFilter == null && filter.key == 'all');
          
          return FilterChip(
            label: Text(filter.label),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                if (selected) {
                   _activeFilter = filter.key;
                } else {
                   _activeFilter = 'all';
                }
                _applyFilters();
              });
            },
            backgroundColor: AppTheme.surfaceColor,
            selectedColor: widget.primaryColor.withValues(alpha: 0.2),
            labelStyle: GoogleFonts.inter(
              color: isSelected ? widget.primaryColor : AppTheme.secondaryTextColor,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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
    if (_filteredData.isEmpty) {
      return Center(
        child: Text(
          'No items found',
          style: GoogleFonts.inter(color: AppTheme.secondaryTextColor),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredData.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _filteredData[index];
        return _buildHighDensityCard(item);
      },
    );
  }

  Widget _buildHighDensityCard(Map<String, dynamic> item) {
    // Use the first column as title, second as subtitle
    final titleKey = widget.tab.columns.isNotEmpty ? widget.tab.columns[0].key : '';
    final subtitleKey = widget.tab.columns.length > 1 ? widget.tab.columns[1].key : '';

    return Card(
      color: AppTheme.surfaceColor,
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
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textColor,
                        ),
                      ),
                    if (subtitleKey.isNotEmpty)
                      Text(
                        item[subtitleKey]?.toString() ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppTheme.secondaryTextColor,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.secondaryTextColor),
            ],
          ),
        ),
      ),
    );
  }
}
