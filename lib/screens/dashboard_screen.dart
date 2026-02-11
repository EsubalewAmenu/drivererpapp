import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import '../models/schema_models.dart';
import '../providers/drive_provider.dart';
import '../services/drive_service.dart';
import '../providers/workspace_provider.dart';
import '../features/add_module/add_module_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import 'module_screen.dart';
import 'module_details_screen.dart';
import 'settings_screen.dart';
import '../utils/icon_lookup.dart';

class DashboardScreen extends StatefulWidget {
  final String? userAccessSpreadsheetId;
  const DashboardScreen({super.key, this.userAccessSpreadsheetId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<List<drive.File>> _modulesFuture = Future.value([]);
  // Map of module folder id -> sheet ids (dashboard, settings, tabs)
  final Map<String, Map<String, String>> _userAccessModuleSheets = {};
  String? _lastWorkspaceId;
  Object? _lastDriveService;
  bool _initialized = false;
  String _selectedPeriod = 'Today'; // 'Today', 'Week', 'Month'
  
  final List<Map<String, String>> _catalog = [
    {'name': 'CRM', 'icon': 'people', 'desc': 'Customer Relationship Management', 'color': '#3B82F6'}, // Blue
    {'name': 'Inventory', 'icon': 'inventory', 'desc': 'Stock & Warehouse', 'color': '#F59E0B'}, // Amber
    {'name': 'HR', 'icon': 'badge', 'desc': 'Human Resources', 'color': '#8B5CF6'}, // Violet
    {'name': 'Finance', 'icon': 'account_balance', 'desc': 'Financial Records', 'color': '#6366F1'}, // Indigo
    // {'name': 'Marketing', 'icon': 'campaign', 'desc': 'Campaigns & Leads', 'color': '#EC4899'}, // Pink
    // {'name': 'Expenses', 'icon': 'receipt_long', 'desc': 'Cost Tracking', 'color': '#EF4444'}, // Red
    // {'name': 'Projects', 'icon': 'assignment', 'desc': 'Task Management', 'color': '#14B8A6'}, // Teal
    // {'name': 'Analytics', 'icon': 'analytics', 'desc': 'Business Intelligence', 'color': '#06B6D4'}, // Cyan
  ];
  
  // Mock KPI Data
  final Map<String, Map<String, double>> _kpiData = {
    'Today': {'sales': 1250.00, 'expenses': 450.00},
    'Week': {'sales': 8500.00, 'expenses': 3200.00},
    'Month': {'sales': 35000.00, 'expenses': 42000.00}, // Loss example
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    final workspace = Provider.of<WorkspaceProvider>(context).currentWorkspace;
    final driveService = Provider.of<DriveProvider>(context).driveService;
    final workspaceId = workspace?.id;

    if (!_initialized || 
        workspaceId != _lastWorkspaceId || 
        driveService != _lastDriveService) {
      _lastWorkspaceId = workspaceId;
      _lastDriveService = driveService;
      _initialized = true;
      _loadModules();
    }
  }

  Future<void> _loadModules() async {
    final workspace = Provider.of<WorkspaceProvider>(context).currentWorkspace;
    final driveService = Provider.of<DriveProvider>(context).driveService;
    final provider = Provider.of<WorkspaceProvider>(context, listen: false);

    if (workspace == null || driveService == null) {
      setState(() {
        _modulesFuture = Future.value([]);
      });
      return;
    }

    debugPrint('DashboardScreen: loading modules for workspace=${workspace.id} name=${workspace.name}');
    // Determine effective userAccessSpreadsheetId: widget param -> in-memory provider -> persisted prefs
    String? cachedId = provider.lastUserAccessSpreadsheetId;
    if (cachedId == null || cachedId.isEmpty) {
      try {
        cachedId = await WorkspaceProvider.getLastUserAccessSpreadsheetId();
      } catch (e) {
        debugPrint('Error reading persisted user access spreadsheet id: $e');
      }
    }

    final effectiveId = (widget.userAccessSpreadsheetId != null && widget.userAccessSpreadsheetId!.isNotEmpty)
        ? widget.userAccessSpreadsheetId
        : (cachedId != null && cachedId.isNotEmpty ? cachedId : null);
    await _refreshModules(driveService, effectiveId);
  }

  Future<void> _refreshModules(DriveService driveService, String? effectiveId) async {
    debugPrint('DashboardScreen: effective userAccessSpreadsheetId=$effectiveId (widget param=${widget.userAccessSpreadsheetId})');

    if (!mounted) return;
    setState(() {
      if (effectiveId != null && effectiveId.isNotEmpty) {
        debugPrint('DashboardScreen: loading modules from user_access sheet $effectiveId');
        _modulesFuture = _loadModulesFromUserAccess(driveService, effectiveId);
      } else {
        debugPrint('DashboardScreen: no user_access sheet, treating as no access (no Drive listing)');
        _modulesFuture = Future.value([]);
      }
    });
  }

  Future<List<drive.File>> _loadModulesFromUserAccess(DriveService driveService, String userAccessSpreadsheetId) async {
    try {
      debugPrint('DashboardScreen: reading user_access modules from $userAccessSpreadsheetId');
      final resp = await driveService.sheetsApi.spreadsheets.values.get(userAccessSpreadsheetId, 'modules!A1:Z');
      final all = resp.values ?? [];
      debugPrint('DashboardScreen: user_access rows=${all.length}');
      if (all.isEmpty) return [];
      final header = List<String>.from(all.first.map((e) => e.toString().toLowerCase()));
      final rows = all.length > 1 ? all.sublist(1) : [];
      // rows columns: id, module_name, dashboard, settings, tabs
      final files = <drive.File>[];
      _userAccessModuleSheets.clear();
      final moduleTypeIdx = header.indexOf('module_type');
      for (var r in rows) {
        final id = r.isNotEmpty ? (r[0] as String) : '';
        final name = r.length > 1 ? (r[1] as String) : '';
        final dashboardId = r.length > 2 ? (r[2] as String) : '';
        final settingsId = r.length > 3 ? (r[3] as String) : '';
        final tabsId = r.length > 4 ? (r[4] as String) : '';
        final moduleType = (moduleTypeIdx != -1 && r.length > moduleTypeIdx)
            ? (r[moduleTypeIdx] ?? '').toString().toLowerCase()
            : '';
        // Check status column if present
        String status = '';
        final statusIdx = header.indexOf('status');
        if (statusIdx != -1 && r.length > statusIdx) {
          status = (r[statusIdx] ?? '').toString().toLowerCase();
        }
        if (status == 'deactivated') {
          // Skip deactivated modules for this user
          continue;
        }
        if (moduleType == 'extension') {
          // Extensions should not appear on main dashboard
          continue;
        }
        if (id.isNotEmpty && name.isNotEmpty) {
          final f = drive.File()..id = id..name = name;
          files.add(f);
          _userAccessModuleSheets[id] = {
            'dashboard': dashboardId,
            'settings': settingsId,
            'tabs': tabsId,
          };
        }
      }
      debugPrint('DashboardScreen: built userAccessModuleSheets for ${_userAccessModuleSheets.length} modules');
      _userAccessModuleSheets.forEach((k, v) {
        debugPrint('DashboardScreen: sheets mapping -> moduleId=$k -> $v');
      });
      return files;
    } catch (e) {
      debugPrint('Error loading modules from user access sheet: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final sales = _kpiData[_selectedPeriod]!['sales']!;
    final expenses = _kpiData[_selectedPeriod]!['expenses']!;
    final profit = sales - expenses;
    final isProfitable = profit >= 0;
    final theme = Theme.of(context);
    final kpiColor = isProfitable ? theme.primaryColor : const Color(0xFFF43F5E); // Emerald or Rose

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Consumer<WorkspaceProvider>(
          builder: (context, provider, child) {
            return Text(
              (provider.currentWorkspace?.name ?? 'DRIVE ERP').toUpperCase(),
              style: AppTheme.inter(fontWeight: FontWeight.w900, letterSpacing: 1.0, color: theme.textTheme.titleLarge?.color),
            );
          },
        ),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: theme.iconTheme,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<drive.File>>(
          future: _modulesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final driveFiles = snapshot.data ?? [];
            // Debug: print loaded modules and their mapped sheet ids (if any)
            try {
              debugPrint('DashboardScreen: modules loaded count=${driveFiles.length}');
              for (var f in driveFiles) {
                final id = f.id ?? '<no-id>';
                final name = f.name ?? '<no-name>';
                final sheets = _userAccessModuleSheets[id];
                debugPrint('DashboardScreen: module -> id=$id name=$name sheets=${sheets ?? {}}');
              }
            } catch (e) {
              debugPrint('DashboardScreen: error printing modules debug info: $e');
            }
            final activeModuleNames = driveFiles.map((f) => f.name).toSet();

            // Always render modules from user_access (no catalog gating)
            final expansionModules = _catalog.where((m) => !activeModuleNames.contains(m['name'])).toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateFilter(),
                  const SizedBox(height: 24),
                  _buildKPIEngine(sales, expenses, profit, kpiColor),
                  const SizedBox(height: 32),
                  _buildSectionHeader('CORE MODULES'),
                  const SizedBox(height: 16),
                  _buildCoreModulesGrid(driveFiles),
                  const SizedBox(height: 32),
                  _buildSectionHeader('EXPANSION MARKETPLACE'),
                  const SizedBox(height: 16),
                  _buildExpansionMarketplaceGrid(expansionModules),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDateFilter() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: ['Today', 'Week', 'Month'].map((period) {
          final isSelected = _selectedPeriod == period;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = period),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? theme.scaffoldBackgroundColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)] : null,
                ),
                child: Text(
                  period.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: AppTheme.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? theme.textTheme.bodyLarge?.color : theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKPIEngine(double sales, double expenses, double profit, Color color) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.2), theme.cardTheme.color ?? theme.cardColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('NET PROFIT ENGINE', style: AppTheme.inter(fontSize: 12, fontWeight: FontWeight.w700, color: theme.textTheme.bodyMedium?.color, letterSpacing: 1.0)),
              Icon(profit >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: color),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '\$${profit.abs().toStringAsFixed(2)}',
            style: AppTheme.sourceCodePro(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildKPIStat('SALES', sales, theme.textTheme.bodyLarge!.color!),
              const SizedBox(width: 24),
              _buildKPIStat('EXPENSES', expenses, theme.textTheme.bodyMedium!.color!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKPIStat(String label, double value, Color color) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.inter(fontSize: 10, fontWeight: FontWeight.w600, color: theme.textTheme.bodyMedium?.color)),
        const SizedBox(height: 4),
        Text('\$${value.toStringAsFixed(2)}', style: AppTheme.inter(fontSize: 16, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: AppTheme.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: theme.textTheme.bodyMedium?.color,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildCoreModulesGrid(List<drive.File> driveFiles) {
    final theme = Theme.of(context);
    if (driveFiles.isEmpty) {
      return Column(
        children: [
          Text(
            'No modules installed.\nVisit the Marketplace to expand.',
            textAlign: TextAlign.center,
            style: AppTheme.inter(color: theme.textTheme.bodyMedium?.color),
          ),
          const SizedBox(height: 16),
          _buildAddModuleCard(),
        ],
      );
    }
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: driveFiles.length + 1,
      itemBuilder: (context, index) {
        if (index == driveFiles.length) {
          return _buildAddModuleCard();
        }
        final folder = driveFiles[index];
        final moduleInfo = _catalog.firstWhere(
          (m) => m['name']?.toLowerCase() == (folder.name ?? '').toLowerCase(),
          orElse: () => {
            'name': folder.name ?? 'Module',
            'icon': 'table_chart',
            'color': '#4F46E5',
          },
        );
        
        // Create a temporary schema from the folder
        final module = ModuleSchema(
          id: folder.id ?? 'unknown',
          name: moduleInfo['name'] ?? (folder.name ?? 'Module'),
          icon: moduleInfo['icon'] ?? 'table_chart',
          primaryColor: moduleInfo['color'] ?? '#4F46E5',
          version: '1.0.0',
          settings: {},
          dashboard: DashboardConfig(cards: []),
          tabs: [],
        );
        final sheetIds = _userAccessModuleSheets[folder.id ?? ''];
        return _buildModuleCard(module, isActive: true, sheetIds: sheetIds);
      },
    );
  }

  Widget _buildAddModuleCard() {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.textTheme.bodyMedium!.color!.withValues(alpha: 0.2),
          width: 1,
          style: BorderStyle.solid,
        ),
      ),
      child: InkWell(
        onTap: _handleAddModule,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: theme.primaryColor,
                  size: 24,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Module',
                    style: AppTheme.inter(fontSize: 16, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Use an existing spreadsheet',
                    style: AppTheme.inter(fontSize: 12, color: theme.textTheme.bodyMedium?.color),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAddModule() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddModuleScreen()),
    );
    if (result == true) {
      final driveService = Provider.of<DriveProvider>(context, listen: false).driveService;
      final provider = Provider.of<WorkspaceProvider>(context, listen: false);
      final effectiveId = (widget.userAccessSpreadsheetId != null && widget.userAccessSpreadsheetId!.isNotEmpty)
          ? widget.userAccessSpreadsheetId
          : (provider.lastUserAccessSpreadsheetId ?? await WorkspaceProvider.getLastUserAccessSpreadsheetId());

      if (driveService != null) {
        await _refreshModules(driveService, effectiveId);
        // Retry once to handle Drive eventual consistency
        await Future.delayed(const Duration(milliseconds: 600));
        await _refreshModules(driveService, effectiveId);
      } else {
        await _loadModules();
      }
    }
  }

  Widget _buildExpansionMarketplaceGrid(List<Map<String, String>> expansionModules) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: expansionModules.length,
      itemBuilder: (context, index) {
        final mod = expansionModules[index];
        return _buildMarketplaceCard(mod['name']!, mod['icon']!, mod['desc']!, mod['color']!);
      },
    );
  }

  Widget _buildModuleCard(ModuleSchema module, {required bool isActive, Map<String, String>? sheetIds}) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () {
          // Debug: when opening a module, log the sheet ids being passed
          debugPrint('DashboardScreen: opening module ${module.id} name=${module.name} sheetIds=${sheetIds ?? {}}');
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ModuleScreen(
              module: module,
              dashboardSheetId: sheetIds != null ? sheetIds['dashboard'] : null,
              settingsSheetId: sheetIds != null ? sheetIds['settings'] : null,
              tabsSheetId: sheetIds != null ? sheetIds['tabs'] : null,
            )),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  iconFromName(module.icon),
                  color: Color(int.parse(module.primaryColor.replaceAll('#', '0xFF'))),
                  size: 24,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module.name,
                    style: AppTheme.inter(fontSize: 16, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Active',
                    style: AppTheme.inter(fontSize: 12, color: theme.primaryColor),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarketplaceCard(String name, String iconName, String desc, String colorHex) {
    final theme = Theme.of(context);
    final color = Color(int.parse(colorHex.replaceAll('#', '0xFF')));
    return Card(
      color: theme.cardTheme.color?.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.textTheme.bodyMedium!.color!.withValues(alpha: 0.2), width: 1, style: BorderStyle.solid), // Dashed border simulation? No, just solid for now.
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ModuleDetailsScreen(
                moduleInfo: {
                  'name': name,
                  'icon': iconName,
                  'desc': desc,
                  'color': colorHex,
                },
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  iconFromName(iconName),
                  color: color.withValues(alpha: 0.7),
                  size: 24,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTheme.inter(fontSize: 16, fontWeight: FontWeight.w700, color: theme.textTheme.bodyMedium?.color),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Install',
                    style: AppTheme.inter(fontSize: 12, color: theme.textTheme.bodyMedium?.color, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Icons are resolved via `iconFromName` in `lib/utils/icon_lookup.dart`.
}
