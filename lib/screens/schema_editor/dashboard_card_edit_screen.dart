import 'package:flutter/material.dart';
import '../../models/schema_models.dart';
import '../../theme/app_theme.dart';

class DashboardCardEditScreen extends StatefulWidget {
  final DashboardCard card;
  final ModuleSchema module;
  final int index; // For updating list

  const DashboardCardEditScreen({
    super.key,
    required this.card,
    required this.module,
    required this.index,
  });

  @override
  State<DashboardCardEditScreen> createState() => _DashboardCardEditScreenState();
}

class _DashboardCardEditScreenState extends State<DashboardCardEditScreen> {
  late TextEditingController _labelController;
  late TextEditingController _customFormulaController;
  late TextEditingController _conditionController;
  late String _format;
  late String _mode; // 'builder', 'custom'

  // Builder State
  String? _selectedTabId;
  String? _selectedColumnKey;
  String? _selectedOperator; // For conditional logic
  String? _conditionValue;
  
  // Generic operations map
  final Map<String, String> _operations = {
    'count': 'Count All',
    'count_if': 'Count If...',
    'sum': 'Sum',
    'average': 'Average',
  };

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.card.label);
    _customFormulaController = TextEditingController(text: widget.card.formula);
    _format = widget.card.format;
    
    // Intelligently determine if we can reverse-engineer the formula for the builder
    _tryParseFormula(widget.card.formula);
    _conditionController = TextEditingController(text: _conditionValue ?? '');
  }

  @override
  void dispose() {
    _labelController.dispose();
    _customFormulaController.dispose();
    _conditionController.dispose();
    super.dispose();
  }

  void _tryParseFormula(String formula) {
    // Basic heuristics to pre-fill builder UI
    // Example: =COUNTIF(stocks!D:D, "<10")
    
    // Charts default to custom for now
    if (widget.card.type != 'kpi') {
      _mode = 'custom';
      return;
    }

    _mode = 'builder'; // Default
    try {
      if (formula.startsWith('=COUNTIF(')) {
        _selectedOperator = 'count_if';
        final content = formula.substring(9, formula.length - 1); // stocks!D:D, "<10"
        final parts = content.split(',');
        if (parts.length >= 2) {
           _parseRange(parts[0].trim());
           _conditionValue = parts[1].trim().replaceAll('"', '');
        }
      } else if (formula.startsWith('=SUM(')) {
        _selectedOperator = 'sum';
        _parseRange(formula.substring(5, formula.length - 1));
      } else if (formula.startsWith('=AVERAGE(')) {
        _selectedOperator = 'average';
        _parseRange(formula.substring(9, formula.length - 1));
      } else if (formula.startsWith('=COUNTA(')) {
        _selectedOperator = 'count';
        _parseRange(formula.substring(8, formula.length - 1));
      } else {
        _mode = 'custom';
      }
    } catch (e) {
      _mode = 'custom';
    }
  }

  void _parseRange(String range) {
    // stocks!D:D
    final parts = range.split('!');
    if (parts.length == 2) {
      final potentialTabId = parts[0];
      // Only set if tab actually exists in this module
      if (widget.module.tabs.any((t) => t.id == potentialTabId)) {
        _selectedTabId = potentialTabId;
      } else {
        _selectedTabId = null;
      }
      
      // Try to parse 'D:D' to get 'D'
      final colPart = parts[1];
      if (colPart.contains(':')) {
        final colLetter = colPart.split(':')[0].replaceAll(RegExp(r'[^A-Z]'), '');
        if (colLetter.isNotEmpty) {
           try {
             final colIndex = _colLetterToIndex(colLetter);
             // Find column in tab
             final tab = widget.module.tabs.firstWhere((t) => t.id == _selectedTabId, orElse: () => widget.module.tabs.first);
             if (colIndex >= 0 && colIndex < tab.columns.length) {
               _selectedColumnKey = tab.columns[colIndex].key;
             }
           } catch (e) {
             // Ignore parsing error
           }
        }
      }
    }
  }

  int _colLetterToIndex(String letter) {
    int index = 0;
    for (int i = 0; i < letter.length; i++) {
      index = index * 26 + (letter.codeUnitAt(i) - 65 + 1);
    }
    return index - 1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'CONFIGURE CARD',
          style: AppTheme.inter(
            fontWeight: FontWeight.w900, 
            letterSpacing: 1.0, 
            color: theme.textTheme.titleLarge?.color
          ),
        ),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, DashboardCard(
                label: _labelController.text,
                formula: _mode == 'builder' ? _generateFormula() : _customFormulaController.text,
                format: _format,
                type: widget.card.type, // Preserve Type
                config: widget.card.config,
              ));
            },
            child: Text('DONE', style: AppTheme.inter(fontWeight: FontWeight.w700, color: theme.primaryColor)),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label Section
            Text('Display Name', style: AppTheme.inter(fontWeight: FontWeight.w600, color: theme.disabledColor)),
            const SizedBox(height: 8),
            TextField(
              controller: _labelController,
              decoration: InputDecoration(
                filled: true,
                fillColor: theme.cardTheme.color,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Configuration Mode
            Container(
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Use Formula Builder'),
                    subtitle: const Text('Easily construct rules without code'),
                    value: _mode == 'builder',
                    onChanged: (val) => setState(() => _mode = val ? 'builder' : 'custom'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            if (_mode == 'builder') _buildBuilderUI(theme) else _buildCustomUI(theme),

            const SizedBox(height: 32),
            
            // Format Section
             Text('Display Format', style: AppTheme.inter(fontWeight: FontWeight.w600, color: theme.disabledColor)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _format,
                  isExpanded: true,
                  items: ['number', 'currency', 'percent', 'text'].map((f) {
                    return DropdownMenuItem(value: f, child: Text(f.toUpperCase()));
                  }).toList(),
                  onChanged: (val) => setState(() => _format = val!),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuilderUI(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Data Source (Tab)
        Text('Data Source (Sheet)', style: AppTheme.inter(fontWeight: FontWeight.w600, color: theme.disabledColor)),
        const SizedBox(height: 8),
        _buildDropdown(
          value: _selectedTabId,
          hint: 'Select Sheet',
          items: widget.module.tabs.map((t) => DropdownMenuItem(value: t.id, child: Text(t.label))).toList(),
          onChanged: (val) {
            setState(() {
              _selectedTabId = val;
              _selectedColumnKey = null; // Reset column when tab changes
            });
          },
        ),

        if (_selectedTabId != null) ...[
          const SizedBox(height: 24),
          // 2. Column Selection
          Text('Field (Column)', style: AppTheme.inter(fontWeight: FontWeight.w600, color: theme.disabledColor)),
          const SizedBox(height: 8),
          _buildDropdown(
            value: _selectedColumnKey,
            hint: 'Select Field',
            items: _getColumnsForTab(_selectedTabId!).map((c) => DropdownMenuItem(value: c.key, child: Text(c.label))).toList(),
            onChanged: (val) => setState(() => _selectedColumnKey = val),
          ),
        ],

        if (_selectedColumnKey != null) ...[
          const SizedBox(height: 24),
          // 3. Operation
          Text('Logic / Operation', style: AppTheme.inter(fontWeight: FontWeight.w600, color: theme.disabledColor)),
          const SizedBox(height: 8),
          _buildDropdown(
            value: _selectedOperator,
            hint: 'Select Operation',
            items: _operations.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (val) => setState(() => _selectedOperator = val),
          ),
        ],

        if (_selectedOperator == 'count_if') ...[
           const SizedBox(height: 24),
           // 4. Condition Value
           Text('Condition Rule', style: AppTheme.inter(fontWeight: FontWeight.w600, color: theme.disabledColor)),
           const SizedBox(height: 8),
           TextField(
             controller: _conditionController,
             onChanged: (val) {
                setState(() {
                  _conditionValue = val;
                });
             },
             decoration: InputDecoration(
               filled: true,
               fillColor: theme.cardTheme.color,
               hintText: '<10, Pending, Approved',
               border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
             ),
           ),
        ],

        const SizedBox(height: 24),
        // Preview
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Text('GENERATED FORMULA', style: AppTheme.inter(fontSize: 10, fontWeight: FontWeight.w700, color: theme.disabledColor)),
               const SizedBox(height: 4),
               Text(
                 _generateFormula(),
                 style: AppTheme.sourceCodePro(fontWeight: FontWeight.w600),
               ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomUI(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Spreadsheet Formula', style: AppTheme.inter(fontWeight: FontWeight.w600, color: theme.disabledColor)),
        const SizedBox(height: 8),
        TextField(
          controller: _customFormulaController,
          maxLines: 3,
          style: AppTheme.sourceCodePro(),
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.cardTheme.color,
            hintText: '=SUM(sheet!A:A)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({required T? value, required String hint, required List<DropdownMenuItem<T>> items, required Function(T?) onChanged}) {
     return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint),
          isExpanded: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  List<ColumnConfig> _getColumnsForTab(String tabId) {
    final tab = widget.module.tabs.firstWhere((t) => t.id == tabId, orElse: () => widget.module.tabs.first);
    // Flatten columns if needed, but for now top-level
    return tab.columns;
  }

  String _generateFormula() {
    if (_selectedColumnKey == null || _selectedTabId == null) return 'Select Sheet & Field';
    
    // Calculate Column Letter
    final tab = widget.module.tabs.firstWhere((t) => t.id == _selectedTabId);
    final colIndex = tab.columns.indexWhere((c) => c.key == _selectedColumnKey);
    if (colIndex == -1) return 'Invalid Column';
    
    final colLetter = _getColLetter(colIndex);
    final range = '$_selectedTabId!$colLetter:$colLetter';
    
    switch (_selectedOperator) {
      case 'count':
        return '=COUNTA($range)';
      case 'sum':
        return '=SUM($range)';
      case 'average':
        return '=AVERAGE($range)';
      case 'count_if':
        final val = _conditionValue ?? '';
        // If val contains operator, wrap in quotes if not already there? 
        // Typically user types "<10" or "Pending"
        return '=COUNTIF($range, "$val")';
      default:
        return '...';
    }
  }

  String _getColLetter(int colIndex) {
    String letter = "";
    while (colIndex >= 0) {
      letter = String.fromCharCode((colIndex % 26) + 65) + letter;
      colIndex = (colIndex / 26).floor() - 1;
    }
    return letter;
  }
}
