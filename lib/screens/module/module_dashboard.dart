import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/schema_models.dart';
import '../../services/auth_service.dart';
import '../../services/drive_service.dart';
import '../../theme/app_theme.dart';

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
