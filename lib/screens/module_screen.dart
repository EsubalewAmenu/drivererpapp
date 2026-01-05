import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/schema_models.dart';
import '../services/auth_service.dart';
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
  ModuleSchema? _fullModule;
  bool _isLoadingSchema = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSchema();
    });
  }

  Future<void> _loadSchema() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final driveService = DriveService(authService.authClient!);
      
      // 1. Check for config.json in the module folder (widget.module.id)
      String? configFileId = await driveService.getFileId(widget.module.id, 'config.json');
      
      Map<String, dynamic> jsonMap;
      bool isLocalConfig = false;

      if (configFileId != null) {
        // 2. Load from Drive
        final content = await driveService.getFileContent(configFileId);
        jsonMap = jsonDecode(content);
      } else {
        // 3. Load from Assets (Fallback)
        isLocalConfig = true;
        final fileName = widget.module.name.toLowerCase();
        // Handle case where asset might not exist (though it should for known modules)
        try {
          final jsonString = await rootBundle.loadString('assets/erp_modules/$fileName.json');
          jsonMap = jsonDecode(jsonString);
        } catch (e) {
          print('Asset not found for $fileName, using default empty schema');
          jsonMap = {
            'settings': {'name': {'value': widget.module.name}},
            'dashboard': {'kpiCards': []},
            'tabs': []
          };
        }
      }
      
      // Parse JSON to ModuleSchema
      final settingsMap = (jsonMap['settings'] as Map<String, dynamic>?) ?? {};
      final name = settingsMap['name']?['value'] ?? widget.module.name;
      
      final dashboard = jsonMap['dashboard'] != null 
          ? DashboardConfig.fromJson(jsonMap['dashboard'])
          : DashboardConfig(kpiCards: []);
      
      final tabsList = (jsonMap['tabs'] as List?) ?? [];
      
      // Pre-process tabs (same logic as before)
      for (var tab in tabsList) {
        if (tab['columns'] != null) {
          for (var col in tab['columns']) {
            if (col['options'] is String && (col['options'] as String).startsWith('settings.')) {
              final path = (col['options'] as String).split('.');
              if (path.length == 2) {
                final settingKey = path[1];
                final settingValue = settingsMap[settingKey]?['value'];
                if (settingValue is List) {
                  col['options'] = settingValue;
                } else {
                  col['options'] = [];
                }
              }
            }
          }
        }
      }

      final tabs = tabsList.map((t) => TabConfig.fromJson(t)).toList();
      final settingsItems = settingsMap.map((k, v) => MapEntry(k, SettingItem.fromJson(v)));

      final loadedModule = ModuleSchema(
        id: widget.module.id,
        name: name,
        icon: jsonMap['icon'] ?? widget.module.icon,
        primaryColor: jsonMap['primaryColor'] ?? widget.module.primaryColor,
        version: jsonMap['version'] ?? widget.module.version,
        settings: settingsItems,
        dashboard: dashboard,
        tabs: tabs,
      );

      setState(() {
        _fullModule = loadedModule;
        _isLoadingSchema = false;
      });

      // 4. If local config, navigate to Editor to complete setup
      if (isLocalConfig && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SchemaEditorScreen(
              module: loadedModule,
              isNewSetup: true,
            ),
          ),
        ).then((_) {
          // Reload schema after returning from editor (in case it was saved)
          _loadSchema();
        });
      }

    } catch (e) {
      print('Error loading module schema: $e');
      setState(() {
        _fullModule = widget.module;
        _isLoadingSchema = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingSchema) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final module = _fullModule ?? widget.module;
    final primaryColor = Color(int.parse(module.primaryColor.replaceAll('#', '0xFF')));

    return DefaultTabController(
      length: module.tabs.length + 1, // +1 for Dashboard
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: Text(
            module.name.toUpperCase(),
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
                  MaterialPageRoute(builder: (context) => SchemaEditorScreen(module: module)),
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
              ...module.tabs.map((t) => Tab(text: t.label.toUpperCase())),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ModuleDashboard(
              key: UniqueKey(), // Force rebuild when tab changes or parent rebuilds
              module: module, 
              primaryColor: primaryColor
            ),
            ...module.tabs.map((t) => ModuleTabScreen(
              tab: t, 
              primaryColor: primaryColor,
              settings: module.settings,
              module: module,
            )),
          ],
        ),
      ),
    );
  }
}

class ModuleDashboard extends StatefulWidget {
  final ModuleSchema module;
  final Color primaryColor;

  const ModuleDashboard({super.key, required this.module, required this.primaryColor});

  @override
  State<ModuleDashboard> createState() => _ModuleDashboardState();
}

class _ModuleDashboardState extends State<ModuleDashboard> {
  Map<String, String> _kpiValues = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _calculateKpis();
  }

  Future<void> _calculateKpis() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.authClient == null) return;
    final driveService = DriveService(authService.authClient!);
    final Map<String, String> results = {};

    // Assuming the first tab is the primary data source for now
    // In a real app, we'd need to know which sheet/tab the KPI refers to.
    // For Inventory, it's the 'stock' tab.
    if (widget.module.tabs.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    // Heuristic: Find the tab that contains 'qty' and 'cost_price' or default to the first one
    String tabId = widget.module.tabs.first.id;
    for (var tab in widget.module.tabs) {
      final hasQty = tab.columns.any((c) => c.key == 'qty');
      final hasCost = tab.columns.any((c) => c.key == 'cost_price');
      if (hasQty && hasCost) {
        tabId = tab.id;
        break;
      }
    }

    final data = await driveService.readSheet('Default Workspace', tabId);

    for (var card in widget.module.dashboard.kpiCards) {
      results[card.label] = _evaluateFormula(card.calculation, card.format, data);
    }

    if (mounted) {
      setState(() {
        _kpiValues = results;
        _isLoading = false;
      });
    }
  }

  String _evaluateFormula(String formula, String format, List<Map<String, dynamic>> data) {
    try {
      if (formula.startsWith('SUM(')) {
        // SUM(cost_price * qty)
        final expression = formula.substring(4, formula.length - 1);
        double total = 0;
        
        for (var row in data) {
          if (expression.contains('*')) {
            final parts = expression.split('*').map((e) => e.trim()).toList();
            final val1 = double.tryParse(row[parts[0]]?.toString() ?? '0') ?? 0;
            final val2 = double.tryParse(row[parts[1]]?.toString() ?? '0') ?? 0;
            total += val1 * val2;
          } else {
            final val = double.tryParse(row[expression]?.toString() ?? '0') ?? 0;
            total += val;
          }
        }
        
        if (format == 'currency') {
          return '\$${total.toStringAsFixed(2)}';
        }
        return total.toStringAsFixed(2);
      } 
      else if (formula.startsWith('COUNT(')) {
        // COUNT(qty < 10)
        final expression = formula.substring(6, formula.length - 1);
        int count = 0;
        
        if (expression.contains('<')) {
          final parts = expression.split('<').map((e) => e.trim()).toList();
          final key = parts[0];
          final threshold = double.tryParse(parts[1]) ?? 0;
          
          for (var row in data) {
            final val = double.tryParse(row[key]?.toString() ?? '0') ?? 0;
            if (val < threshold) {
              count++;
            }
          }
        }
        return count.toString();
      }
      
      return '0';
    } catch (e) {
      return 'Error';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

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
        ...widget.module.dashboard.kpiCards.map((card) => _buildKpiCard(context, card)),
      ],
    );
  }

  Widget _buildKpiCard(BuildContext context, KpiCard card) {
    final value = _kpiValues[card.label] ?? '0';
    
    // Alert Logic: If label is "Shortages" and count > 0, use danger color
    final isAlert = card.label == 'Shortages' && (int.tryParse(value) ?? 0) > 0;
    final cardColor = isAlert ? const Color(0xFFF43F5E) : widget.primaryColor;
    final bgColor = isAlert ? const Color(0xFFF43F5E).withOpacity(0.1) : AppTheme.surfaceColor;
    final borderColor = isAlert ? const Color(0xFFF43F5E) : widget.primaryColor.withOpacity(0.3);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
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
                  color: isAlert ? cardColor : AppTheme.secondaryTextColor,
                  letterSpacing: 1.0,
                ),
              ),
              Icon(
                isAlert ? Icons.warning_rounded : Icons.show_chart_rounded, 
                color: cardColor
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.sourceCodePro(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: isAlert ? cardColor : AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Formula: ${card.calculation}",
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isAlert ? cardColor.withOpacity(0.8) : AppTheme.secondaryTextColor,
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
    final authService = Provider.of<AuthService>(context, listen: false);
    _driveService = DriveService(authService.authClient!);
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
    
    // Load actual data from DriveService
    final data = await _driveService.readSheet(_currentWorkspace, widget.tab.id);
    
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
