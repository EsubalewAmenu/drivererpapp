import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/schema_models.dart';
import '../../../providers/erp_controller.dart';

class DynamicDropdownField extends StatefulWidget {
  final FieldDefinition column;
  final String? value;
  final ValueChanged<String?> onChanged;
  final Map<String, dynamic> data;
  final ModuleSchema? module;
  const DynamicDropdownField({
    super.key,
    required this.column,
    required this.value,
    required this.onChanged,
    required this.data,
    this.module,
  });
  @override
  State<DynamicDropdownField> createState() => _DynamicDropdownFieldState();
}

class _DynamicDropdownFieldState extends State<DynamicDropdownField> {
  List<String> options = [];
  bool loading = false;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DynamicDropdownField old) {
    super.didUpdateWidget(old);
    if (old.column != widget.column ||
        old.data.toString() != widget.data.toString()) {
      _load();
    }
  }

  Future<void> _load() async {
    final config = widget.column.options;
    if (config is List) {
      setState(() => options = config.map((v) => v.toString()).toList());
      return;
    }
    if (config is! String) return;
    if (config.startsWith('settings.')) {
      final value = widget.module?.settings[config.substring(9)]?.value;
      if (value is List) {
        setState(() => options = value.map((v) => v.toString()).toList());
      }
      return;
    }
    final parts = config.split('.');
    if (parts.length != 2 || widget.module == null) return;
    FieldDefinition? relation;
    for (final c in widget.module!.collections) {
      for (final f in c.fields) {
        if (f.key == parts[0] && f.type == 'relation') relation = f;
        for (final nested in f.fields ?? <FieldDefinition>[]) {
          if (nested.key == parts[0] && nested.type == 'relation') {
            relation = nested;
          }
        }
      }
    }
    final selected = widget.data[parts[0]];
    if (relation == null || selected == null) return;
    setState(() => loading = true);
    try {
      final erp = context.read<ErpController>();
      final collection = relation.options.toString();
      final module = erp.moduleForCollection(
        collection,
        preferred: widget.module,
      );
      if (module == null) return;
      final record = await erp.api.record(
        module.id,
        collection.split('.').last,
        selected.toString(),
      );
      final value = record[parts[1]];
      if (mounted) {
        setState(
          () => options = value is List
              ? value.map((v) => v.toString()).toList()
              : value == null
              ? []
              : [value.toString()],
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    isExpanded: true,
    initialValue: options.contains(widget.value) ? widget.value : null,
    decoration: InputDecoration(
      labelText: widget.column.label,
      errorText: error,
      suffixIcon: loading
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            )
          : null,
      border: const OutlineInputBorder(),
    ),
    items: options
        .map(
          (v) => DropdownMenuItem(
            value: v,
            child: Text(v, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: widget.column.readonly == true ? null : widget.onChanged,
  );
}
