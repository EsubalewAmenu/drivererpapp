import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../models/schema_models.dart';
import '../../providers/drive_provider.dart';

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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Start calculating KPIs after a short delay to let animations finish
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _calculateKpis();
    });
  }

  @override
  void didUpdateWidget(ModuleDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.module != widget.module) {
      debugPrint('Module schema updated, recalculating KPIs...');
      _calculateKpis();
    }
  }

  Future<void> _calculateKpis() async {
    final driveProvider = Provider.of<DriveProvider>(context, listen: false);
    final driveService = driveProvider.driveService;
    
    if (driveService == null) return;
    
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    
    // Assuming the first tab is the primary data source for now
    if (widget.module.tabs.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // Heuristic: Find tab
    String tabId = widget.module.tabs.first.id;
    for (var tab in widget.module.tabs) {
      final hasQty = tab.columns.any((c) => c.key == 'qty');
      final hasCost = tab.columns.any((c) => c.key == 'cost_price');
      if (hasQty && hasCost) {
        tabId = tab.id;
        break;
      }
    }

    // Fetch fresh data
    try {
      final data = await driveService.fetchRecords(widget.module.id, widget.module.name, tabId);
      
      if (mounted) {
        debugPrint('Updating Dashboard KPIs from fresh data for $tabId...');
        _updateKpiState(data);
      }
    } catch (e) {
      debugPrint('Error fetching records for dashboard: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Data unavailable (Offline)';
        });
      }
    }
  }

  void _updateKpiState(List<Map<String, dynamic>> data) {
    final Map<String, String> results = {};
    for (var card in widget.module.dashboard.kpiCards) {
      results[card.label] = _evaluateFormula(card.calculation, card.format, data);
    }

    setState(() {
      _kpiValues = results;
      _isLoading = false;
      _errorMessage = null;
    });
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
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _kpiValues.isEmpty) {
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
              onPressed: _calculateKpis, 
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

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'PERFORMANCE OVERVIEW',
          style: AppTheme.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: theme.textTheme.bodyMedium?.color,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        ...widget.module.dashboard.kpiCards.map((card) => _buildKpiCard(context, card)),
      ],
    );
  }

  Widget _buildKpiCard(BuildContext context, KpiCard card) {
    final theme = Theme.of(context);
    final value = _kpiValues[card.label] ?? '0';
    
    // Alert Logic: If label is "Shortages" and count > 0, use danger color
    final isAlert = card.label == 'Shortages' && (int.tryParse(value) ?? 0) > 0;
    final cardColor = isAlert ? const Color(0xFFF43F5E) : widget.primaryColor;
    final bgColor = isAlert ? const Color(0xFFF43F5E).withValues(alpha: 0.1) : theme.cardTheme.color;
    final borderColor = isAlert ? const Color(0xFFF43F5E) : widget.primaryColor.withValues(alpha: 0.3);

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
                style: AppTheme.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isAlert ? cardColor : theme.textTheme.bodyMedium?.color,
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
            style: AppTheme.sourceCodePro(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: isAlert ? cardColor : theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Formula: ${card.calculation}",
            style: AppTheme.inter(
              fontSize: 12,
              color: isAlert ? cardColor.withValues(alpha: 0.8) : theme.textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }
}
