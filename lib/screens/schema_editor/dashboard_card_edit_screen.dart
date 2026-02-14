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
    // Try to extract module, tab, and sheet name from formula
    // Format: =FUNCTION(MODULE_ID:TAB_ID:SHEET_NAME!COLUMN, ...)
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
      
      // Parse MODULE_ID:TAB_ID:SHEET_NAME!COLUMN format
      if (argsStr.contains(':') && argsStr.contains('!')) {
        final firstComma = argsStr.indexOf(',');
        final reference = firstComma > 0 ? argsStr.substring(0, firstComma).trim() : argsStr.trim();
        
        final exclIndex = reference.indexOf('!');
        final colonParts = reference.substring(0, exclIndex).split(':');
        
        if (exclIndex > 0 && colonParts.length == 3) {
          final moduleId = colonParts[0];
          final tabId = colonParts[1];
          final sheetName = colonParts[2];
          
          if (moduleId == widget.module.id) {
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
                    });
                  },
                ),
        ],

        if (_selectedSheetName != null) ...[
          const SizedBox(height: 24),
          // Column Selection (Manual Entry)
          Text('Column Letter', style: AppTheme.inter(fontWeight: FontWeight.w600, color: theme.disabledColor)),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: _selectedColumnKey),
            onChanged: (val) => setState(() => _selectedColumnKey = val.toUpperCase()),
            decoration: InputDecoration(
              filled: true,
              fillColor: theme.cardTheme.color,
              hintText: 'e.g., A, B, C, D',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
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
                  onChanged: (val) => setState(() => _chartSheetName = val),
                ),
        ],

        if (_chartSheetName != null) ...[
          const SizedBox(height: 24),
          // X-Axis Column
          Text('X-Axis Column (Labels)', style: AppTheme.inter(fontWeight: FontWeight.w600, color: theme.disabledColor)),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: _xAxisColumn),
            onChanged: (val) => setState(() => _xAxisColumn = val.toUpperCase()),
            decoration: InputDecoration(
              filled: true,
              fillColor: theme.cardTheme.color,
              hintText: 'e.g., A',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),

          const SizedBox(height: 16),
          // Y-Axis Column
          Text('Y-Axis Column (Values)', style: AppTheme.inter(fontWeight: FontWeight.w600, color: theme.disabledColor)),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: _yAxisColumn),
            onChanged: (val) => setState(() => _yAxisColumn = val.toUpperCase()),
            decoration: InputDecoration(
              filled: true,
              fillColor: theme.cardTheme.color,
              hintText: 'e.g., B',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
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
            hintText: '=SUM(MODULE_ID:TAB_ID:SHEET_NAME!A:A)',
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
                'Format: =FUNCTION(MODULE_ID:TAB_ID:SHEET_NAME!COLUMN)',
                style: AppTheme.inter(fontSize: 11, fontWeight: FontWeight.w600, color: theme.primaryColor),
              ),
              const SizedBox(height: 4),
              Text(
                'Example: =SUM(crm:contacts:Contacts!B:B)',
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

    final reference = '${widget.module.id}:$_selectedTabId:$_selectedSheetName!$_selectedColumnKey:$_selectedColumnKey';

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
    return '=CHART(${widget.module.id}:$_chartTabId:$_chartSheetName!$_xAxisColumn:$_yAxisColumn)';
  }
}
