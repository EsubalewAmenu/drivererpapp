import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
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
  final Map<String, List<Map<String, dynamic>>> _chartDataMap = {};
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
        final formula = card.formula;
        if (!formula.startsWith('=')) {
           _updateCardValue(card, formula);
           continue;
        }
        
        // Handle Charts (Line, Bar, Pie, Progress, List)
        if (card.type != 'kpi') {
          // Expected format: =CHART(MODULE_NAME:TAB_ID:SHEET_NAME!A:B)
          String spreadsheetId = '';
          String tabId = '';
          String sheetName = '';
          String query = '';

          if (formula.startsWith('=CHART(')) {
            final content = formula.substring(7, formula.length - 1);
            final exclIndex = content.indexOf('!');
            if (exclIndex > 0) {
              final refParts = content.substring(0, exclIndex).split(':');
              if (refParts.length == 3) {
                final moduleName = refParts[0].trim();
                tabId = refParts[1].trim();
                sheetName = refParts[2].trim();

                if (moduleName != widget.module.name) {
                  throw Exception('Module mismatch');
                }

                final tab = widget.module.tabs.firstWhere(
                  (t) => t.id == tabId,
                  orElse: () => widget.module.tabs.first,
                );
                spreadsheetId = tab.fileId ?? '';
              }
              final range = content.substring(exclIndex + 1); // A:B
              final cols = range.split(':');
              if (cols.length == 2) {
                final col1 = cols[0].replaceAll(RegExp(r'[^A-Z]'), '');
                final col2 = cols[1].replaceAll(RegExp(r'[^A-Z]'), '');
                if (col1.isNotEmpty && col2.isNotEmpty) {
                  query = col1 == col2 ? "SELECT $col1" : "SELECT $col1, $col2";
                }
              }
            }
          }

          if (spreadsheetId.isEmpty || sheetName.isEmpty || query.isEmpty) {
            throw Exception('Invalid CHART format');
          }

          final results = await driveService.executeGvizTableQueryBySpreadsheetId(
            spreadsheetId,
            sheetName,
            query,
          );

          if (mounted) {
            setState(() {
              _chartDataMap[card.label] = results ?? [];
              _loadingMap[card.label] = false;
            });
          }
          continue;
        }

        // ... Existing KPI Logic ...
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

        // Parse Range: MODULE_NAME:TAB_ID:SHEET_NAME!A:A
        final rangePart = args[0];
        final exclIndex = rangePart.indexOf('!');
        if (exclIndex == -1) {
          throw Exception('Invalid Range');
        }

        final refParts = rangePart.substring(0, exclIndex).split(':');
        if (refParts.length != 3) {
          throw Exception('Invalid Range');
        }

        final moduleName = refParts[0].trim();
        final tabId = refParts[1].trim();
        final sheetName = refParts[2].trim();

        if (moduleName != widget.module.name) {
          throw Exception('Module mismatch');
        }

        final tab = widget.module.tabs.firstWhere(
          (t) => t.id == tabId,
          orElse: () => widget.module.tabs.first,
        );
        final spreadsheetId = tab.fileId ?? '';
        final colRange = rangePart.substring(exclIndex + 1); // e.g. "B:B" or "B"
        final colLetter = colRange.split(':')[0].replaceAll(RegExp(r'[^A-Z]'), '');

        if (spreadsheetId.isEmpty || sheetName.isEmpty || colLetter.isEmpty) {
          throw Exception('Invalid Range');
        }

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
        final result = await driveService.executeGvizQueryBySpreadsheetId(
          spreadsheetId,
          sheetName,
          query,
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
    if (['line', 'bar', 'pie', 'progress', 'list'].contains(card.type)) {
       return _buildChartCard(context, card);
    }
  
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

  Widget _buildChartCard(BuildContext context, DashboardCard card) {
    final theme = Theme.of(context);
    final data = _chartDataMap[card.label];
    final isLoading = _loadingMap[card.label] ?? true;
    
    // 1. Parse Data (Generic for all charts)
    // We assume data is List<Map<String, dynamic>> where keys are "ColA", "ColB" etc.
    // We generally treat:
    // - 1st Axis/Col: Label/Category (String)
    // - 2nd Axis/Col: Value (Number)
    List<String> labels = [];
    List<double> values = [];
    List<List<String>> rawTable = []; // for LIST view
    List<String> headers = [];

    if (data != null && data.isNotEmpty) {
       // Try to extract headers from keys of first row
       headers = data.first.keys.toList();
       
       for (var row in data) {
         // Convert all values to string for table view
         rawTable.add(row.values.map((e) => e.toString()).toList());
         
         final rowVals = row.values.toList();
         if (rowVals.isNotEmpty) {
            // Label
            labels.add(rowVals[0].toString());
            
            // Value
            if (rowVals.length > 1) {
              final val = rowVals[1];
              double? parsed;
              if (val is num) {
                 parsed = val.toDouble();
              } else if (val is String) {
                 parsed = double.tryParse(val.replaceAll(RegExp(r'[^0-9.-]'), ''));
              }
              values.add(parsed ?? 0.0);
            } else {
              values.add(0.0);
            }
         }
       }
    }

    Widget content;
    
    if (isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (data == null || data.isEmpty) {
      content = Center(
        child: Text(
          'No Data Available',
          style: AppTheme.inter(color: theme.disabledColor),
        ),
      );
    } else {
      switch (card.type) {
        case 'bar':
          content = BarChart(
            BarChartData(
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, m) => Text(NumberFormat.compact().format(v), style: const TextStyle(fontSize: 10)))
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (val, meta) {
                      final idx = val.toInt();
                      if (idx >= 0 && idx < labels.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(labels[idx].length > 4 ? "${labels[idx].substring(0,3)}." : labels[idx], style: const TextStyle(fontSize: 10)),
                        );
                      }
                      return const SizedBox();
                    }
                  )
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              barGroups: List.generate(values.length, (i) {
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: values[i],
                      color: widget.primaryColor,
                      width: 16, 
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4))
                    )
                  ]
                );
              }),
            )
          );
          break;
          
        case 'pie':
          content = PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: List.generate(values.length, (i) {
                // Generate varied colors based on primary color
                final opacity = (1.0 - (i * 0.15)).clamp(0.2, 1.0);
                return PieChartSectionData(
                  value: values[i],
                  title: labels[i],
                  color: widget.primaryColor.withValues(alpha: opacity),
                  radius: 50,
                  titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                );
              }),
            )
          );
          break;
          
        case 'progress':
            // Assume first value is current, 2nd value (if exists) is Max. 
            // Or assume value is Percentage (0-100 or 0-1)
            double current = values.isNotEmpty ? values.first : 0;
            double max = 100;
            // Scan for max in headers or assumptions? For now, if val <= 1 assume ratio.
            if (current <= 1.0) {
               max = 1.0; 
            }
            double percent = (current / max).clamp(0.0, 1.0);
            
            content = Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                        Text(labels.isNotEmpty ? labels.first : "", style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text("${(percent * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                     ],
                   ),
                   const SizedBox(height: 12),
                   LinearProgressIndicator(
                     value: percent,
                     color: widget.primaryColor,
                     backgroundColor: widget.primaryColor.withValues(alpha: 0.1),
                     minHeight: 12,
                     borderRadius: BorderRadius.circular(6),
                   ),
                   const SizedBox(height: 8),
                   Text("${current.toStringAsFixed(1)} / ${max.toStringAsFixed(1)}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            );
            break;
            
        case 'list':
          content = SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 32,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 48,
                columns: headers.map((h) => DataColumn(label: Text(h, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                rows: rawTable.map((row) {
                  return DataRow(cells: row.map((cell) => DataCell(Text(cell))).toList());
                }).toList(),
              ),
            ),
          );
          break;
          
        case 'line':
        default:
          content = LineChart(
             LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, m) => Text(NumberFormat.compact().format(v), style: const TextStyle(fontSize: 10)))
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < labels.length) {
                          // thinning
                          if (labels.length > 6 && idx % 2 != 0) return const SizedBox();
                          return Padding(
                             padding: const EdgeInsets.only(top: 8),
                             child: Text(labels[idx].length > 4 ? "${labels[idx].substring(0,3)}." : labels[idx], style: const TextStyle(fontSize: 10)),
                          );
                        }
                        return const SizedBox();
                      }
                    )
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(values.length, (i) => FlSpot(i.toDouble(), values[i])),
                    isCurved: true,
                    color: widget.primaryColor,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: widget.primaryColor.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
          );
          break;
      }
    }

    return Container(
      height: 300,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: widget.primaryColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Text(
              card.label.toUpperCase(),
              style: AppTheme.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: theme.textTheme.bodyMedium?.color,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: content,
            ),
        ],
      ),
    );
  }
}

