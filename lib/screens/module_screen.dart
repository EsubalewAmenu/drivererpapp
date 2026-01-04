import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/schema_models.dart';
import '../services/drive_service.dart';
import '../theme/app_theme.dart';
import 'dynamic_form_screen.dart';
import 'record_detail_screen.dart';
import 'schema_editor_screen.dart';

class ModuleScreen extends StatefulWidget {
  final ModuleSchema module;

  const ModuleScreen({super.key, required this.module});

  @override
  State<ModuleScreen> createState() => _ModuleScreenState();
}

class _ModuleScreenState extends State<ModuleScreen> {
  @override
  Widget build(BuildContext context) {
    final primaryColor = Color(int.parse(widget.module.settings.primaryColor.replaceAll('#', '0xFF')));

    return DefaultTabController(
      length: widget.module.tabs.length + 1, // +1 for Dashboard
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: Text(
            widget.module.name.toUpperCase(),
            style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 1.0),
          ),
          centerTitle: true,
          backgroundColor: AppTheme.backgroundColor,
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_note_rounded),
              tooltip: 'Edit Blueprint',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SchemaEditorScreen(module: widget.module)),
                );
              },
            ),
          ],
          elevation: 0,
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: primaryColor,
            labelColor: primaryColor,
            unselectedLabelColor: AppTheme.secondaryTextColor,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
            tabs: [
              const Tab(text: 'DASHBOARD'),
              ...widget.module.tabs.map((t) => Tab(text: t.label.toUpperCase())),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ModuleDashboard(module: widget.module, primaryColor: primaryColor),
            ...widget.module.tabs.map((t) => ModuleTabScreen(tab: t, primaryColor: primaryColor)),
          ],
        ),
      ),
    );
  }
}

class ModuleDashboard extends StatelessWidget {
  final ModuleSchema module;
  final Color primaryColor;

  const ModuleDashboard({super.key, required this.module, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'PERFORMANCE OVERVIEW',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.secondaryTextColor,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        ...module.dashboard.kpiCards.map((card) => _buildKpiCard(context, card)),
      ],
    );
  }

  Widget _buildKpiCard(BuildContext context, KpiCard card) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                card.label.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.secondaryTextColor,
                  letterSpacing: 1.0,
                ),
              ),
              Icon(Icons.show_chart_rounded, color: primaryColor),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "0", // Placeholder for calculation result
            style: GoogleFonts.sourceCodePro(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Formula: ${card.calculation}",
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }
}

class ModuleTabScreen extends StatefulWidget {
  final TabConfig tab;
  final Color primaryColor;

  const ModuleTabScreen({super.key, required this.tab, required this.primaryColor});

  @override
  State<ModuleTabScreen> createState() => _ModuleTabScreenState();
}

class _ModuleTabScreenState extends State<ModuleTabScreen> {
  final DriveService _driveService = DriveService();
  final String _currentWorkspace = 'Default Workspace'; // TODO: Get from global state
  
  List<Map<String, dynamic>> _allData = [];
  List<Map<String, dynamic>> _filteredData = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _activeFilter;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        _applyFilters();
      });
    });
  }

  Future<void> _loadData() async {
    // Simulate network delay for "High Trust" feel
    await Future.delayed(const Duration(milliseconds: 800));
    
    // Mock data since DriveService might not be fully connected yet
    // In real app, use: final data = await _driveService.readSheet(_currentWorkspace, widget.tab.id);
    final mockData = List.generate(10, (index) {
      final map = <String, dynamic>{};
      for (var col in widget.tab.columns) {
        map[col.key] = 'Item $index - ${col.label}';
      }
      // Add some variation for filtering
      map['status'] = index % 2 == 0 ? 'Active' : 'Inactive';
      return map;
    });

    if (mounted) {
      setState(() {
        _allData = mockData;
        _filteredData = mockData;
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
        
        // Quick Filter (Mock implementation)
        final matchesQuickFilter = _activeFilter == null || 
          (_activeFilter == 'Active Items' && item['status'] == 'Active') ||
          (_activeFilter == 'Inactive Items' && item['status'] == 'Inactive');

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
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DynamicFormScreen(
                tab: widget.tab,
                primaryColor: widget.primaryColor,
              ),
            ),
          );
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
          hintStyle: TextStyle(color: AppTheme.secondaryTextColor),
          prefixIcon: Icon(Icons.search_rounded, color: AppTheme.secondaryTextColor),
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
    final filters = ['Active Items', 'Inactive Items', 'Recent'];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _activeFilter == filter;
          return FilterChip(
            label: Text(filter),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                _activeFilter = selected ? filter : null;
                _applyFilters();
              });
            },
            backgroundColor: AppTheme.surfaceColor,
            selectedColor: widget.primaryColor.withOpacity(0.2),
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
              Icon(Icons.chevron_right_rounded, color: AppTheme.secondaryTextColor),
            ],
          ),
        ),
      ),
    );
  }
}
