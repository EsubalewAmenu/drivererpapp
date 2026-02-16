import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/schema_models.dart';
import '../../theme/app_theme.dart';
import '../../providers/drive_provider.dart';

class DashboardCardEditScreen extends StatefulWidget {
  final DashboardCard card;
  final ModuleSchema module;
  final int index;

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
  String? _format;
  late String _mode; // 'builder', 'custom'

  // Builder State for KPI
  String? _selectedTabId;
  String? _selectedSheetName;
  String? _selectedColumnKey;
  String? _selectedOperator;
  late TextEditingController _conditionController;

  // Builder State for Charts
  String? _chartTabId;
  String? _chartSheetName;
  String? _xAxisColumn;
  String? _yAxisColumn;

  // Available sheets for selected spreadsheet
  List<String> _availableSheets = [];
  bool _loadingSheets = false;
  List<String> _availableColumns = [];
  bool _loadingColumns = false;
  final Map<String, String> _columnLetterMap = {};
  final Map<String, String> _columnHeaderByLetter = {};
  String? _selectedColumnHeader;
  String? _selectedXAxisHeader;
  String? _selectedYAxisHeader;

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
    _conditionController = TextEditingController();
    
    // Start with builder mode by default
    _mode = 'builder';
    
    // If there's an existing formula, try to parse it
    if (widget.card.formula.isNotEmpty) {
      _tryParseExistingFormula(widget.card.formula);
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _customFormulaController.dispose();
    _conditionController.dispose();
    super.dispose();
  }

  void _tryParseExistingFormula(String formula) {
    // Try to extract module name, tab, and sheet name from formula
    // Format: =FUNCTION(MODULE_NAME:TAB_ID:SHEET_NAME!COLUMN, ...)
    if (!formula.startsWith('=')) {
      _mode = 'custom';
      return;
    }

    try {
      final content = formula.substring(1);
      final parenIndex = content.indexOf('(');
      if (parenIndex == -1) {
        _mode = 'custom';
        return;
      }

      final func = content.substring(0, parenIndex).toUpperCase();
      final argsStr = content.substring(parenIndex + 1, content.lastIndexOf(')'));
      
      // Parse MODULE_NAME:TAB_ID:SHEET_NAME!COLUMN format
      if (argsStr.contains(':') && argsStr.contains('!')) {
        final firstComma = argsStr.indexOf(',');
        final reference = firstComma > 0 ? argsStr.substring(0, firstComma).trim() : argsStr.trim();
        
        final exclIndex = reference.indexOf('!');
        final colonParts = reference.substring(0, exclIndex).split(':');
        
        if (exclIndex > 0 && colonParts.length == 3) {
          final moduleName = colonParts[0];
          final tabId = colonParts[1];
          final sheetName = colonParts[2];
          
          if (moduleName == widget.module.name) {
            _selectedTabId = tabId;
            _selectedSheetName = sheetName;
          }
          
          // Extract column
          final columnPart = reference.substring(exclIndex + 1);
          _selectedColumnKey = columnPart.replaceAll(RegExp(r'[^A-Z]'), '');
          
          // Set operator
          if (func == 'COUNTIF') {
            _selectedOperator = 'count_if';
            if (firstComma > 0) {
              final condition = argsStr.substring(firstComma + 1).trim().replaceAll('"', '').replaceAll("'", '');
              _conditionController.text = condition;
            }
          } else if (func == 'SUM') {
            _selectedOperator = 'sum';
          } else if (func == 'AVERAGE') {
            _selectedOperator = 'average';
          } else if (func == 'COUNTA' || func == 'COUNT') {
            _selectedOperator = 'count';
          }
          
          // Load sheets for this tab
          if (_selectedTabId != null) {
            _loadSheetsForTab(_selectedTabId!);
          }

          // Load columns for selected sheet when available
          if (_selectedTabId != null && _selectedSheetName != null) {
            _loadColumnsForTabSheet(_selectedTabId!, _selectedSheetName!);
          }
        }
      }
    } catch (e) {
      debugPrint('Could not parse formula: $e');
      _mode = 'custom';
    }
  }

  Future<void> _loadSheetsForTab(String tabId) async {
    setState(() {
      _loadingSheets = true;
      _availableSheets = [];
      _availableColumns = [];
      _columnLetterMap.clear();
      _columnHeaderByLetter.clear();
      _selectedColumnHeader = null;
      _selectedXAxisHeader = null;
      _selectedYAxisHeader = null;
    });

    try {
      final driveService = Provider.of<DriveProvider>(context, listen: false).driveService;
      if (driveService == null) {
        throw Exception('Drive service not available');
      }

      final tab = widget.module.tabs.firstWhere(
        (t) => t.id == tabId,
        orElse: () => widget.module.tabs.first,
      );
      final spreadsheetId = tab.fileId;
      if (spreadsheetId == null || spreadsheetId.isEmpty) {
        throw Exception('Spreadsheet not found for selected tab');
      }

      final spreadsheet = await driveService.sheetsApi.spreadsheets.get(spreadsheetId);
      final sheets = spreadsheet.sheets ?? [];
      
      setState(() {
        _availableSheets = sheets
            .map((s) => s.properties?.title ?? '')
            .where((title) => title.isNotEmpty)
            .toList();
        _loadingSheets = false;
      });
    } catch (e) {
      debugPrint('Error loading sheets: $e');
      setState(() {
        _loadingSheets = false;
      });
    }
  }

  Future<void> _loadColumnsForTabSheet(String tabId, String sheetName) async {
    setState(() {
      _loadingColumns = true;
      _availableColumns = [];
      _columnLetterMap.clear();
      _columnHeaderByLetter.clear();
      _selectedColumnHeader = null;
      _selectedXAxisHeader = null;
      _selectedYAxisHeader = null;
    });

    try {
      final driveService = Provider.of<DriveProvider>(context, listen: false).driveService;
      if (driveService == null) {
        throw Exception('Drive service not available');
      }

      final tab = widget.module.tabs.firstWhere(
        (t) => t.id == tabId,
        orElse: () => widget.module.tabs.first,
      );
      final spreadsheetId = tab.fileId;
      if (spreadsheetId == null || spreadsheetId.isEmpty) {
        throw Exception('Spreadsheet not found for selected tab');
      }

      final resp = await driveService.sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        '$sheetName!1:1',
      );

      final headerRow = (resp.values != null && resp.values!.isNotEmpty)
          ? resp.values!.first
          : <dynamic>[];

      final columns = <String>[];
      for (int i = 0; i < headerRow.length; i++) {
        final raw = headerRow[i]?.toString().trim() ?? '';
        final letter = _indexToColumnLetter(i);
        final label = raw.isNotEmpty ? raw : 'Column $letter';
        columns.add(label);
        _columnLetterMap[label] = letter;
        _columnHeaderByLetter[letter] = label;
      }

      setState(() {
        _availableColumns = columns;
        _loadingColumns = false;
        if (_selectedColumnKey != null && _selectedColumnKey!.isNotEmpty) {
          _selectedColumnHeader = _columnHeaderByLetter[_selectedColumnKey!];
        }
        if (_xAxisColumn != null && _xAxisColumn!.isNotEmpty) {
          _selectedXAxisHeader = _columnHeaderByLetter[_xAxisColumn!];
        }
        if (_yAxisColumn != null && _yAxisColumn!.isNotEmpty) {
          _selectedYAxisHeader = _columnHeaderByLetter[_yAxisColumn!];
        }
      });
    } catch (e) {
      debugPrint('Error loading columns: $e');
      setState(() {
        _loadingColumns = false;
      });
    }
  }

  String _indexToColumnLetter(int colIndex) {
    String letter = '';
    int index = colIndex;
    while (index >= 0) {
      letter = String.fromCharCode((index % 26) + 65) + letter;
      index = (index / 26).floor() - 1;
    }
    return letter;
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
              final formula = _mode == 'builder' ? _generateFormula() : _customFormulaController.text;
              Navigator.pop(context, DashboardCard(
                label: _labelController.text,
                formula: formula,
                format: _format,
                type: widget.card.type,
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
              child: SwitchListTile(
                title: const Text('Use Formula Builder'),
                subtitle: const Text('Visual builder for formulas'),
                value: _mode == 'builder',
                onChanged: (val) => setState(() => _mode = val ? 'builder' : 'custom'),
              ),
            ),

            const SizedBox(height: 24),

            if (_mode == 'builder')
              widget.card.type == 'kpi' ? _buildKpiBuilder(theme) : _buildChartBuilder(theme)
            else
              _buildCustomUI(theme),

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

  Widget _buildKpiBuilder(ThemeData theme) {
    // Get available tabs that have fileId
    final availableTabs = widget.module.tabs.where((t) => t.fileId != null && t.fileId!.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Spreadsheet Selection
        Text('Data Source', style: AppTheme.inter(fontWeight: FontWeight.w600, color: theme.disabledColor)),
        const SizedBox(height: 8),
        _buildDropdown<String>(
          value: _selectedTabId,
          hint: 'Select Tab',
          items: availableTabs.map((t) => DropdownMenuItem(
            value: t.id,
            child: Text(t.label),
          )).toList(),
          onChanged: (val) {
            setState(() {
              _selectedTabId = val;
              _selectedSheetName = null;
              _selectedColumnKey = null;
            });
            if (val != null) {
              _loadSheetsForTab(val);
            }
          },
        ),

        if (_selectedTabId != null) ...[
          const SizedBox(height: 24),
          // Sheet Name Selection
          Text('Sheet Name', style: AppTheme.inter(fontWeight: FontWeight.w600, color: theme.disabledColor)),
          const SizedBox(height: 8),
          _loadingSheets
              ? const Center(child: CircularProgressIndicator())
              : _buildDropdown<String>(
                  value: _selectedSheetName,
                  hint: 'Select Sheet',
                  items: _availableSheets.map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s),
                  )).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedSheetName = val;
                      _selectedColumnKey = null;
                      _selectedColumnHeader = null;
                    });
                    if (val != null && _selectedTabId != null) {
                      _loadColumnsForTabSheet(_selectedTabId!, val);
                    }
                  },
                ),
        ],

        if (_selectedSheetName != null) ...[
          const SizedBox(height: 24),
          // Column Selection
          Text('Column', style: AppTheme.inter(fontWeight: FontWeight.w600, color: theme.disabledColor)),
          const SizedBox(height: 8),
          _loadingColumns
              ? const Center(child: CircularProgressIndicator())
              : _buildDropdown<String>(
                  value: _selectedColumnHeader,
                  hint: 'Select Column',
                  items: _availableColumns.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c),
                  )).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedColumnHeader = val;
                      _selectedColumnKey = val != null ? _columnLetterMap[val] : null;
                    });
                  },
                ),
        ],

        if (_selectedColumnKey != null && _selectedColumnKey!.isNotEmpty) ...[
          const SizedBox(height: 24),
          // Operation Selection
          Text('Operation', style: AppTheme.inter(fontWeight: FontWeight.w600, color: theme.disabledColor)),
          const SizedBox(height: 8),
          _buildDropdown<String>(
            value: _selectedOperator,
            hint: 'Select Operation',
            items: _operations.entries.map((e) => DropdownMenuItem(
              value: e.key,
              child: Text(e.value),
            )).toList(),
            onChanged: (val) => setState(() => _selectedOperator = val),
          ),
        ],

        if (_selectedOperator == 'count_if') ...[
          const SizedBox(height: 24),
          // Condition Input
          Text('Condition', style: AppTheme.inter(fontWeight: FontWeight.w600, color: theme.disabledColor)),
          const SizedBox(height: 8),
          TextField(
            controller: _conditionController,
            decoration: InputDecoration(
              filled: true,
              fillColor: theme.cardTheme.color,
              hintText: 'e.g., <10, >100, Approved',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],

        if (_selectedOperator != null) ...[
          const SizedBox(height: 24),
          // Formula Preview
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
                Text('FORMULA PREVIEW', style: AppTheme.inter(fontSize: 10, fontWeight: FontWeight.w700, color: theme.disabledColor)),
                const SizedBox(height: 8),
                Text(
                  _generateFormula(),
                  style: AppTheme.sourceCodePro(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildChartBuilder(ThemeData theme) {
    final availableTabs = widget.module.tabs.where((t) => t.fileId != null && t.fileId!.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Spreadsheet Selection
        Text('Data Source', style: AppTheme.inter(fontWeight: FontWeight.w600, color: theme.disabledColor)),
        const SizedBox(height: 8),
        _buildDropdown<String>(
          value: _chartTabId,
          hint: 'Select Tab',
          items: availableTabs.map((t) => DropdownMenuItem(
            value: t.id,
            child: Text(t.label),
          )).toList(),
          onChanged: (val) {
            setState(() {
              _chartTabId = val;
              _chartSheetName = null;
              _xAxisColumn = null;
              _yAxisColumn = null;
              _selectedXAxisHeader = null;
              _selectedYAxisHeader = null;
            });
            if (val != null) {
              _loadSheetsForTab(val);
            }
          },
        ),

        if (_chartTabId != null) ...[
          const SizedBox(height: 24),
          // Sheet Name
          Text('Sheet Name', style: AppTheme.inter(fontWeight: FontWeight.w600, color: theme.disabledColor)),
          const SizedBox(height: 8),
          _loadingSheets
              ? const Center(child: CircularProgressIndicator())
              : _buildDropdown<String>(
                  value: _chartSheetName,
                  hint: 'Select Sheet',
                  items: _availableSheets.map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s),
                  )).toList(),
                  onChanged: (val) {
                    setState(() {
                      _chartSheetName = val;
                      _xAxisColumn = null;
                      _yAxisColumn = null;
                      _selectedXAxisHeader = null;
                      _selectedYAxisHeader = null;
                    });
                    if (val != null && _chartTabId != null) {
                      _loadColumnsForTabSheet(_chartTabId!, val);
                    }
                  },
                ),
        ],

        if (_chartSheetName != null) ...[
          const SizedBox(height: 24),
          // X-Axis Column
          Text('X-Axis Column (Labels)', style: AppTheme.inter(fontWeight: FontWeight.w600, color: theme.disabledColor)),
          const SizedBox(height: 8),
          _loadingColumns
              ? const Center(child: CircularProgressIndicator())
              : _buildDropdown<String>(
                  value: _selectedXAxisHeader,
                  hint: 'Select Column',
                  items: _availableColumns.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c),
                  )).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedXAxisHeader = val;
                      _xAxisColumn = val != null ? _columnLetterMap[val] : null;
                    });
                  },
                ),

          const SizedBox(height: 16),
          // Y-Axis Column
          Text('Y-Axis Column (Values)', style: AppTheme.inter(fontWeight: FontWeight.w600, color: theme.disabledColor)),
          const SizedBox(height: 8),
          _loadingColumns
              ? const Center(child: CircularProgressIndicator())
              : _buildDropdown<String>(
                  value: _selectedYAxisHeader,
                  hint: 'Select Column',
                  items: _availableColumns.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c),
                  )).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedYAxisHeader = val;
                      _yAxisColumn = val != null ? _columnLetterMap[val] : null;
                    });
                  },
                ),
        ],

        if (_xAxisColumn != null && _yAxisColumn != null) ...[
          const SizedBox(height: 24),
          // Formula Preview
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
                Text('FORMULA PREVIEW', style: AppTheme.inter(fontSize: 10, fontWeight: FontWeight.w700, color: theme.disabledColor)),
                const SizedBox(height: 8),
                Text(
                  _generateFormula(),
                  style: AppTheme.sourceCodePro(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCustomUI(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Custom Formula', style: AppTheme.inter(fontWeight: FontWeight.w600, color: theme.disabledColor)),
        const SizedBox(height: 8),
        TextField(
          controller: _customFormulaController,
          maxLines: 4,
          style: AppTheme.sourceCodePro(),
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.cardTheme.color,
            hintText: '=SUM(MODULE_NAME:TAB_ID:SHEET_NAME!A:A)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Format: =FUNCTION(MODULE_NAME:TAB_ID:SHEET_NAME!COLUMN)',
                style: AppTheme.inter(fontSize: 11, fontWeight: FontWeight.w600, color: theme.primaryColor),
              ),
              const SizedBox(height: 4),
              Text(
                'Example: =SUM(CRM:contacts:Contacts!B:B)',
                style: AppTheme.inter(fontSize: 11, color: theme.primaryColor.withValues(alpha: 0.8)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required Function(T?) onChanged,
  }) {
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

  String _generateFormula() {
    if (widget.card.type == 'kpi') {
      return _generateKpiFormula();
    } else {
      return _generateChartFormula();
    }
  }

  String _generateKpiFormula() {
    if (_selectedTabId == null || _selectedSheetName == null || _selectedColumnKey == null || _selectedOperator == null) {
      return 'Incomplete configuration';
    }

    final reference = '${widget.module.name}:$_selectedTabId:$_selectedSheetName!$_selectedColumnKey:$_selectedColumnKey';

    switch (_selectedOperator) {
      case 'count':
        return '=COUNTA($reference)';
      case 'sum':
        return '=SUM($reference)';
      case 'average':
        return '=AVERAGE($reference)';
      case 'count_if':
        final condition = _conditionController.text.trim();
        if (condition.isEmpty) return '=COUNTIF($reference, "condition")';
        return '=COUNTIF($reference, "$condition")';
      default:
        return 'Unknown operator';
    }
  }

  String _generateChartFormula() {
    if (_chartTabId == null || _chartSheetName == null || _xAxisColumn == null || _yAxisColumn == null) {
      return 'Incomplete configuration';
    }

    // Format: =CHART(MODULE_ID:TAB_ID:SHEET_NAME!X_COL:Y_COL)
    return '=CHART(${widget.module.name}:$_chartTabId:$_chartSheetName!$_xAxisColumn:$_yAxisColumn)';
  }
}
