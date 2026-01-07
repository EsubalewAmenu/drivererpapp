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
  final Map<String, String> _kpiValues = {};
  final Map<String, bool> _loadingMap = {};
  final Map<String, String?> _errorMap = {};
  final Map<String, Future<List<Map<String, dynamic>>>> _fetchFutures = {};

  @override
  void initState() {
    super.initState();
    _initializeStatus();
    // Start calculating KPIs after a short delay to let animations finish
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _calculateAllKpis();
    });
  }

  void _initializeStatus() {
    for (var card in widget.module.dashboard.kpiCards) {
      _loadingMap[card.label] = true;
      _errorMap[card.label] = null;
      _kpiValues.remove(card.label); // Clear old value if any
    }
  }

  @override
  void didUpdateWidget(ModuleDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.module != widget.module) {
      debugPrint('Module schema updated, recalculating KPIs...');
      _fetchFutures.clear();
      _initializeStatus();
      _calculateAllKpis();
    }
  }

  Future<void> _calculateAllKpis() async {
    for (var card in widget.module.dashboard.kpiCards) {
      _calculateSingleKpi(card);
    }
  }

  Future<void> _calculateSingleKpi(KpiCard card) async {
    final driveProvider = Provider.of<DriveProvider>(context, listen: false);
    final driveService = driveProvider.driveService;
    
    if (driveService == null) {
      _setCardError(card, 'Not authenticated');
      return;
    }

    if (widget.module.tabs.isEmpty) {
      _setCardError(card, 'No data sources');
      return;
    }

    try {
      // Heuristic: Identify which tab this formula likely refers to
      String tabId = widget.module.tabs.first.id;
      for (var tab in widget.module.tabs) {
        final formula = card.calculation.toLowerCase();
        bool matches = false;
        for (var col in tab.columns) {
          if (formula.contains(col.key.toLowerCase())) {
            matches = true;
            break;
          }
        }
        if (matches) {
          tabId = tab.id;
          break;
        }
      }

      // Use shared future to avoid redundant requests
      if (!_fetchFutures.containsKey(tabId)) {
        _fetchFutures[tabId] = driveService.fetchRecords(widget.module.id, widget.module.name, tabId);
      }
      
      final data = await _fetchFutures[tabId]!;

      if (mounted) {
        final result = _evaluateFormula(card.calculation, card.format, data);
        setState(() {
          _kpiValues[card.label] = result;
          _loadingMap[card.label] = false;
          _errorMap[card.label] = null;
        });
      }
    } catch (e) {
      debugPrint('Error calculating KPI ${card.label}: $e');
      _setCardError(card, 'Error');
    }
  }

  void _setCardError(KpiCard card, String message) {
    if (mounted) {
      setState(() {
        _loadingMap[card.label] = false;
        _errorMap[card.label] = message;
      });
    }
  }

  String _evaluateFormula(String formula, String format, List<Map<String, dynamic>> data) {
    if (data.isEmpty) return format == 'currency' ? '\$0.00' : '0';

    try {
      final matches = RegExp(r'(\w+)\((.*)\)').firstMatch(formula);
      if (matches == null) return '0';

      final function = matches.group(1)?.toUpperCase();
      final expression = matches.group(2) ?? '';

      double result = 0;

      if (function == 'SUM') {
        final parts = expression.split('*').map((e) => e.trim()).toList();
        for (var row in data) {
          double val = 1.0;
          for (var p in parts) {
            val *= (double.tryParse(row[p]?.toString() ?? '0') ?? 0.0);
          }
          result += val;
        }
      } else if (function == 'COUNT') {
        final parts = expression.split('<').map((e) => e.trim()).toList();
        if (parts.length == 2) {
          final field = parts[0];
          final limit = double.tryParse(parts[1]) ?? 0.0;
          result = data.where((row) => (double.tryParse(row[field]?.toString() ?? '0') ?? 0.0) < limit).length.toDouble();
        } else {
          result = data.length.toDouble();
        }
      }

      if (format == 'currency') {
        return '\$${result.toStringAsFixed(2)}';
      }
      return result.toInt().toString();
    } catch (e) {
      return 'Error';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
            IconButton(
              onPressed: _calculateAllKpis, 
              icon: const Icon(Icons.refresh_rounded, size: 18),
              tooltip: 'Refresh KPIs',
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...widget.module.dashboard.kpiCards.map((card) => _buildKpiCard(context, card)),
      ],
    );
  }

  Widget _buildKpiCard(BuildContext context, KpiCard card) {
    final theme = Theme.of(context);
    final value = _kpiValues[card.label];
    final isLoading = _loadingMap[card.label] ?? true;
    final error = _errorMap[card.label];
    
    // Alert Logic: If label is "Shortages" and count > 0, use danger color
    final isAlert = card.label == 'Shortages' && value != null && (int.tryParse(value) ?? 0) > 0;
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
              if (isLoading)
                const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
              else if (error != null)
                Icon(Icons.error_outline_rounded, size: 16, color: theme.colorScheme.error)
              else
                Icon(
                  isAlert ? Icons.warning_rounded : Icons.show_chart_rounded, 
                  color: cardColor
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading)
            Text(
              '---',
              style: AppTheme.sourceCodePro(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.3),
              ),
            )
          else if (error != null)
            Text(
              error,
              style: AppTheme.inter(
                fontSize: 14,
                color: theme.colorScheme.error,
              ),
            )
          else
            Text(
              value ?? '0',
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
