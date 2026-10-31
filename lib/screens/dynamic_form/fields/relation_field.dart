import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/schema_models.dart';
import '../../../providers/erp_controller.dart';

class DynamicRelationField extends StatefulWidget {
  final FieldDefinition column;
  final String? value;
  final ModuleSchema? module;
  final ValueChanged<String?> onChanged;
  final Map<String, dynamic> data;
  const DynamicRelationField({
    super.key,
    required this.column,
    required this.value,
    this.module,
    required this.onChanged,
    required this.data,
  });
  @override
  State<DynamicRelationField> createState() => _DynamicRelationFieldState();
}

class _DynamicRelationFieldState extends State<DynamicRelationField> {
  String? label;
  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(DynamicRelationField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _resolve();
  }

  Future<void> _resolve() async {
    if (widget.value == null || widget.value!.isEmpty) {
      if (mounted) setState(() => label = null);
      return;
    }
    try {
      final erp = context.read<ErpController>();
      final collection = widget.column.options?.toString() ?? '';
      final module = erp.moduleForCollection(
        collection,
        preferred: widget.module,
      );
      if (module == null) return;
      final record = await erp.api.record(
        module.id,
        collection.split('.').last,
        widget.value!,
      );
      if (mounted) setState(() => label = _label(record));
    } catch (_) {
      if (mounted) setState(() => label = widget.value);
    }
  }

  String _label(Map<String, dynamic> r) =>
      (r[widget.column.displayField] ??
              r['name'] ??
              r['item_name'] ??
              r['title'] ??
              r['record_id'])
          .toString();
  Future<void> _choose() async {
    final erp = context.read<ErpController>();
    final collection = widget.column.options?.toString() ?? '';
    final module = erp.moduleForCollection(
      collection,
      preferred: widget.module,
    );
    if (module == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Install the related module first.')),
      );
      return;
    }
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _RelationDialog(
        erp: erp,
        module: module,
        collection: collection.split('.').last,
        label: widget.column.label,
        displayField: widget.column.displayField,
      ),
    );
    if (selected != null && mounted) {
      for (final entry in selected.entries) {
        widget.data['${widget.column.key}.${entry.key}'] = entry.value;
      }
      setState(() => label = _label(selected));
      widget.onChanged(selected['record_id'].toString());
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        widget.column.label.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge,
      ),
      const SizedBox(height: 8),
      InputDecorator(
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          suffixIcon: widget.value == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: widget.column.readonly == true
                      ? null
                      : () {
                          setState(() => label = null);
                          widget.onChanged(null);
                        },
                ),
        ),
        child: InkWell(
          onTap: widget.column.readonly == true ? null : _choose,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              label ?? widget.value ?? 'Choose ${widget.column.label}',
            ),
          ),
        ),
      ),
    ],
  );
}

class _RelationDialog extends StatefulWidget {
  final ErpController erp;
  final ModuleSchema module;
  final String collection;
  final String label;
  final String? displayField;
  const _RelationDialog({
    required this.erp,
    required this.module,
    required this.collection,
    required this.label,
    this.displayField,
  });
  @override
  State<_RelationDialog> createState() => _RelationDialogState();
}

class _RelationDialogState extends State<_RelationDialog> {
  late Future<List<Map<String, dynamic>>> results;
  String search = '';
  @override
  void initState() {
    super.initState();
    results = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async =>
      (await widget.erp.api.records(
        widget.module.id,
        widget.collection.split('.').last,
        search: search,
        limit: 50,
      )).records;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Choose ${widget.label}'),
    content: SizedBox(
      width: 450,
      height: 400,
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search records',
              suffixIcon: Icon(Icons.search),
            ),
            onSubmitted: (v) => setState(() {
              search = v;
              results = _load();
            }),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: results,
              builder: (context, s) {
                if (s.hasError) return Text('${s.error}');
                if (!s.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView(
                  children: s.data!
                      .map(
                        (r) => ListTile(
                          title: Text(
                            (r[widget.displayField] ??
                                    r['name'] ??
                                    r['item_name'] ??
                                    r['title'] ??
                                    r['record_id'])
                                .toString(),
                          ),
                          onTap: () => Navigator.pop(context, r),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  );
}
