import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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
  final Map<String, String> _cardValues = {};
  final Map<String, bool> _loadingMap = {};
  final Map<String, String?> _errorMap = {};
  
  // Future implementation will fetch from spreadsheet directly
  // final Map<String, Future<List<Map<String, dynamic>>>> _fetchFutures = {};

  @override
  void initState() {
    super.initState();
    _initializeStatus();
    // Start calculating KPIs after a short delay to let animations finish
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _fetchDashboardValues();
    });
  }

  void _initializeStatus() {
    for (var card in widget.module.dashboard.cards) {
      _loadingMap[card.label] = true;
      _errorMap[card.label] = null;
      _cardValues.remove(card.label); // Clear old value if any
    }
  }

  @override
  void didUpdateWidget(ModuleDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.module != widget.module) {
      debugPrint('Module schema updated, refreshing dashboard...');
      _initializeStatus();
      _fetchDashboardValues();
    }
  }

  Future<void> _fetchDashboardValues() async {
    final driveService = Provider.of<DriveProvider>(context, listen: false).driveService;
    if (driveService == null) return;

    for (var card in widget.module.dashboard.cards) {
      if (mounted) {
        setState(() {
          _loadingMap[card.label] = true;
          _errorMap[card.label] = null;
        });
      }

      try {
        // Parse Formula: =FUNCTION(sheet!Col:Col, args)
        final formula = card.formula;
        if (!formula.startsWith('=')) {
          // Static value or invalid
           _updateCardValue(card, formula);
           continue;
        }

        final content = formula.substring(1); // Remove =
        final openParen = content.indexOf('(');
        final closeParen = content.lastIndexOf(')');
        
        if (openParen == -1 || closeParen == -1) {
          throw Exception('Invalid Format');
        }

        final func = content.substring(0, openParen).toUpperCase();
        final argsStr = content.substring(openParen + 1, closeParen);
        final args = argsStr.split(',').map((e) => e.trim()).toList();
        
        if (args.isEmpty) throw Exception('No arguments');

        // Parse Range: sheet!A:A or sheet!A
        final rangePart = args[0];
        final rangeSplit = rangePart.split('!');
        if (rangeSplit.length != 2) throw Exception('Invalid Range');
        
        final sheetName = rangeSplit[0]; // e.g. "stocks"
        final colRange = rangeSplit[1];   // e.g. "B:B" or "B"
        final colLetter = colRange.split(':')[0].replaceAll(RegExp(r'[^A-Z]'), '');

        String query = "";
        
        if (func == 'COUNTIF' && args.length >= 2) {
          // =COUNTIF(sheet!B:B, "<10")
          var criteria = args[1];
          // Remove quotes
          if (criteria.startsWith('"') && criteria.endsWith('"')) {
            criteria = criteria.substring(1, criteria.length - 1);
          }
          else if (criteria.startsWith("'") && criteria.endsWith("'")) {
             criteria = criteria.substring(1, criteria.length - 1);
          }

          // Build Where Clause
          String where = "";
          if (criteria.startsWith('<') || criteria.startsWith('>')) {
            where = "$colLetter $criteria";
          } else {
             // Exact match string or number
             final isNum = double.tryParse(criteria) != null;
             if (isNum) {
               where = "$colLetter = $criteria";
             } else {
               where = "$colLetter = '$criteria'";
             }
          }
          query = "SELECT count($colLetter) WHERE $where";

        } else if (func == 'SUM') {
           query = "SELECT sum($colLetter)";
        } else if (func == 'AVERAGE') {
           query = "SELECT avg($colLetter)";
        } else if (func == 'COUNTA' || func == 'COUNT') {
           query = "SELECT count($colLetter)";
        } else {
           throw Exception('Unknown Function: $func');
        }

        // Execute
        final result = await driveService.executeGvizQuery(
          widget.module.id, // Module folder ID
          sheetName,        // Spreadsheet Name (Tab ID)
          query
        );

        if (mounted) {
          if (result != null) {
            _updateCardValue(card, result.toString());
          } else {
             _updateCardValue(card, "0"); // Default to 0 if null (e.g. empty sheet)
          }
        }

      } catch (e) {
        debugPrint('Error calculating ${card.label}: $e');
        _setCardError(card, 'Error');
      }
    }
  }

  void _updateCardValue(DashboardCard card, String rawValue) {
    if (!mounted) return;
    
    String formatted = rawValue;
    final numVal = double.tryParse(rawValue);
    
    if (numVal != null) {
      if (card.format == 'currency') {
        formatted = NumberFormat.simpleCurrency(decimalDigits: 0).format(numVal);
      } else if (card.format == 'percent') {
        formatted = "${(numVal).toStringAsFixed(1)}%";
      } else {
        // Number
        if (numVal % 1 == 0) {
          formatted = numVal.toInt().toString();
        } else {
          formatted = numVal.toStringAsFixed(2);
        }
      }
    }

    setState(() {
      _cardValues[card.label] = formatted;
      _loadingMap[card.label] = false;
    });
  }

  /* 
  // Old calculation logic removed as per request
  Future<void> _calculateSingleKpi(KpiCard card) async { ... }
  */

  void _setCardError(DashboardCard card, String message) {
    if (mounted) {
      setState(() {
        _loadingMap[card.label] = false;
        _errorMap[card.label] = message;
      });
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
              onPressed: _fetchDashboardValues, 
              icon: const Icon(Icons.refresh_rounded, size: 18),
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...widget.module.dashboard.cards.map((card) => _buildCard(context, card)),
      ],
    );
  }

  Widget _buildCard(BuildContext context, DashboardCard card) {
    final theme = Theme.of(context);
    final value = _cardValues[card.label];
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
                const SizedBox(
                  width: 12, 
                  height: 12, 
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: 0.5, // Static value to avoid pumpAndSettle timeouts
                  )
                )
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
            "Formula: ${card.formula}",
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
