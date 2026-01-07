import 'package:flutter/material.dart';
import '../../../models/schema_models.dart';
import '../../../theme/app_theme.dart';

class DynamicFormulaField extends StatefulWidget {
  final ColumnConfig column;
  final Map<String, TextEditingController> controllers;
  final Function(String) onCalculated;

  const DynamicFormulaField({
    super.key,
    required this.column,
    required this.controllers,
    required this.onCalculated,
  });

  @override
  State<DynamicFormulaField> createState() => _DynamicFormulaFieldState();
}

class _DynamicFormulaFieldState extends State<DynamicFormulaField> {
  String _currentValue = '0.00';

  @override
  void initState() {
    super.initState();
    _calculateValue(isInit: true);
    // Listen to all dependent controllers
    if (widget.column.formula != null) {
      final keys = _extractKeys(widget.column.formula!);
      for (var key in keys) {
        widget.controllers[key]?.addListener(_onDependencyChanged);
      }
    }
  }

  @override
  void dispose() {
    if (widget.column.formula != null) {
      final keys = _extractKeys(widget.column.formula!);
      for (var key in keys) {
        widget.controllers[key]?.removeListener(_onDependencyChanged);
      }
    }
    super.dispose();
  }

  void _onDependencyChanged() {
    _calculateValue();
  }

  List<String> _extractKeys(String formula) {
    if (formula.contains('*')) {
      return formula.split('*').map((e) => e.trim()).toList();
    }
    return [];
  }

  void _calculateValue({bool isInit = false}) {
    String newValue = '0.00';
    if (widget.column.formula != null) {
      final keys = _extractKeys(widget.column.formula!);
      if (keys.length == 2) {
        final val1 = double.tryParse(widget.controllers[keys[0]]?.text ?? '') ?? 0;
        final val2 = double.tryParse(widget.controllers[keys[1]]?.text ?? '') ?? 0;
        newValue = (val1 * val2).toStringAsFixed(2);
      }
    }

    if (newValue != _currentValue || isInit) {
      _currentValue = newValue;
      if (!isInit && mounted) {
        setState(() {});
      }
      // Use microtask or post frame only if the value actually changed to notify parent
      if (!isInit) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onCalculated(_currentValue);
        });
      } else {
        // For init, we can't call onCalculated directly if it calls setState, 
        // but we already have the value in _currentValue for building.
        // The parent will get it on first change or we can send it once.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onCalculated(_currentValue);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.column.label.toUpperCase(),
          style: AppTheme.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).textTheme.bodyMedium?.color,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color?.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Text(
            _currentValue,
            style: AppTheme.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ),
      ],
    );
  }
}
