import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import '../models/schema_models.dart';
import '../providers/drive_provider.dart';
import '../providers/workspace_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import 'module_screen.dart';
import 'module_details_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<drive.File>> _modulesFuture;
  String _selectedPeriod = 'Today'; // 'Today', 'Week', 'Month'
  
  final List<Map<String, String>> _catalog = [
    {'name': 'CRM', 'icon': 'people', 'desc': 'Customer Relationship Management', 'color': '#3B82F6'}, // Blue
    {'name': 'Inventory', 'icon': 'inventory', 'desc': 'Stock & Warehouse', 'color': '#F59E0B'}, // Amber
    {'name': 'HR', 'icon': 'badge', 'desc': 'Human Resources', 'color': '#8B5CF6'}, // Violet
    {'name': 'Sales', 'icon': 'shopping_cart', 'desc': 'Orders & Invoices', 'color': '#10B981'}, // Emerald
    {'name': 'Marketing', 'icon': 'campaign', 'desc': 'Campaigns & Leads', 'color': '#EC4899'}, // Pink
    {'name': 'Expenses', 'icon': 'receipt_long', 'desc': 'Cost Tracking', 'color': '#EF4444'}, // Red
    {'name': 'Projects', 'icon': 'assignment', 'desc': 'Task Management', 'color': '#14B8A6'}, // Teal
    {'name': 'Accounting', 'icon': 'account_balance', 'desc': 'Financial Records', 'color': '#6366F1'}, // Indigo
    {'name': 'Analytics', 'icon': 'analytics', 'desc': 'Business Intelligence', 'color': '#06B6D4'}, // Cyan
    {'name': 'Support', 'icon': 'support_agent', 'desc': 'Helpdesk & Tickets', 'color': '#F97316'}, // Orange
  ];
  
  // Mock KPI Data
  final Map<String, Map<String, double>> _kpiData = {
    'Today': {'sales': 1250.00, 'expenses': 450.00},
    'Week': {'sales': 8500.00, 'expenses': 3200.00},
    'Month': {'sales': 35000.00, 'expenses': 42000.00}, // Loss example
  };

  @override
  void initState() {
    super.initState();
    _loadModules();
  }

  void _loadModules() {
    final workspace = Provider.of<WorkspaceProvider>(context, listen: false).currentWorkspace;
    final driveService = Provider.of<DriveProvider>(context, listen: false).driveService;
    
    if (workspace != null && driveService != null) {
      _modulesFuture = driveService.listModules(workspace.id!);
    } else {
      _modulesFuture = Future.value([]);
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
            final activeModuleNames = driveFiles.map((f) => f.name).toSet();

            final activeModules = _catalog.where((m) => activeModuleNames.contains(m['name'])).toList();
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
                  _buildCoreModulesGrid(activeModules, driveFiles),
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

  Widget _buildCoreModulesGrid(List<Map<String, String>> activeModules, List<drive.File> driveFiles) {
    final theme = Theme.of(context);
    if (activeModules.isEmpty) {
      return Center(
        child: Text(
          'No modules installed.\nVisit the Marketplace to expand.',
          textAlign: TextAlign.center,
          style: AppTheme.inter(color: theme.textTheme.bodyMedium?.color),
        ),
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
      itemCount: activeModules.length,
      itemBuilder: (context, index) {
        final moduleInfo = activeModules[index];
        final folder = driveFiles.firstWhere((f) => f.name == moduleInfo['name']);
        
        // Create a temporary schema from the folder
        final module = ModuleSchema(
          id: folder.id ?? 'unknown',
          name: moduleInfo['name']!,
          icon: moduleInfo['icon']!,
          primaryColor: moduleInfo['color']!,
          version: '1.0.0',
          settings: {},
          dashboard: DashboardConfig(kpiCards: []),
          tabs: [],
        );
        return _buildModuleCard(module, isActive: true);
      },
    );
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

  Widget _buildModuleCard(ModuleSchema module, {required bool isActive}) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ModuleScreen(module: module)),
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
                  _getIconData(module.icon),
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
                  _getIconData(iconName),
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

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'inventory': return Icons.inventory_2_rounded;
      case 'people': return Icons.people_alt_rounded;
      case 'shopping_cart': return Icons.shopping_cart_rounded;
      case 'local_shipping': return Icons.local_shipping_rounded;
      case 'payments': return Icons.payments_rounded;
      case 'badge': return Icons.badge_rounded;
      case 'campaign': return Icons.campaign_rounded;
      case 'receipt_long': return Icons.receipt_long_rounded;
      case 'assignment': return Icons.assignment_rounded;
      case 'account_balance': return Icons.account_balance_rounded;
      case 'analytics': return Icons.analytics_rounded;
      case 'support_agent': return Icons.support_agent_rounded;
      default: return Icons.widgets_rounded;
    }
  }
}
