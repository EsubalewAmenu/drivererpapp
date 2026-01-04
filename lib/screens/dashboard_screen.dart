import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/schema_models.dart';
import '../services/schema_service.dart';
import '../theme/app_theme.dart';
import 'module_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<ModuleSchema>> _modulesFuture;
  String _selectedPeriod = 'Today'; // 'Today', 'Week', 'Month'
  
  // Mock KPI Data
  final Map<String, Map<String, double>> _kpiData = {
    'Today': {'sales': 1250.00, 'expenses': 450.00},
    'Week': {'sales': 8500.00, 'expenses': 3200.00},
    'Month': {'sales': 35000.00, 'expenses': 42000.00}, // Loss example
  };

  @override
  void initState() {
    super.initState();
    _modulesFuture = SchemaService().loadModules();
  }

  @override
  Widget build(BuildContext context) {
    final sales = _kpiData[_selectedPeriod]!['sales']!;
    final expenses = _kpiData[_selectedPeriod]!['expenses']!;
    final profit = sales - expenses;
    final isProfitable = profit >= 0;
    final kpiColor = isProfitable ? AppTheme.primaryColor : const Color(0xFFF43F5E); // Emerald or Rose

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('DRIVE ERP', style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 1.0)),
        centerTitle: true,
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () {
              // TODO: Settings
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
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
              _buildCoreModulesGrid(),
              const SizedBox(height: 32),
              _buildSectionHeader('EXPANSION MARKETPLACE'),
              const SizedBox(height: 16),
              _buildExpansionMarketplaceGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateFilter() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
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
                  color: isSelected ? AppTheme.backgroundColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)] : null,
                ),
                child: Text(
                  period.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? AppTheme.textColor : AppTheme.secondaryTextColor,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.2), AppTheme.surfaceColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('NET PROFIT ENGINE', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.secondaryTextColor, letterSpacing: 1.0)),
              Icon(profit >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: color),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '\$${profit.abs().toStringAsFixed(2)}',
            style: GoogleFonts.sourceCodePro(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildKPIStat('SALES', sales, AppTheme.textColor),
              const SizedBox(width: 24),
              _buildKPIStat('EXPENSES', expenses, AppTheme.secondaryTextColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKPIStat(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.secondaryTextColor)),
        const SizedBox(height: 4),
        Text('\$${value.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppTheme.secondaryTextColor,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildCoreModulesGrid() {
    return FutureBuilder<List<ModuleSchema>>(
      future: _modulesFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final modules = snapshot.data!;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
          ),
          itemCount: modules.length,
          itemBuilder: (context, index) {
            return _buildModuleCard(modules[index], isActive: true);
          },
        );
      },
    );
  }

  Widget _buildExpansionMarketplaceGrid() {
    // Mock Expansion Modules
    final expansionModules = [
      {'name': 'Fleet AI', 'icon': 'local_shipping', 'desc': 'Route optimization'},
      {'name': 'Payroll', 'icon': 'payments', 'desc': 'Automated salary'},
    ];

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
        return _buildMarketplaceCard(mod['name']!, mod['icon']!, mod['desc']!);
      },
    );
  }

  Widget _buildModuleCard(ModuleSchema module, {required bool isActive}) {
    return Card(
      color: AppTheme.surfaceColor,
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
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getIconData(module.icon),
                  color: Color(int.parse(module.settings.primaryColor.replaceAll('#', '0xFF'))),
                  size: 24,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module.name,
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Active',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.primaryColor),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarketplaceCard(String name, String iconName, String desc) {
    return Card(
      color: AppTheme.surfaceColor.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppTheme.secondaryTextColor.withOpacity(0.2), width: 1, style: BorderStyle.solid), // Dashed border simulation? No, just solid for now.
      ),
      child: InkWell(
        onTap: () {
          // Activate logic
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Activating $name...')));
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
                  color: AppTheme.backgroundColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getIconData(iconName),
                  color: AppTheme.secondaryTextColor,
                  size: 24,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.secondaryTextColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Install',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.secondaryTextColor, fontWeight: FontWeight.w600),
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
      default: return Icons.widgets_rounded;
    }
  }
}
