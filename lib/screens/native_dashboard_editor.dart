import 'package:flutter/material.dart';
import '../models/schema_models.dart';

class NativeDashboardEditor extends StatelessWidget {
  final ModuleSchema module;
  final ValueChanged<List<DashboardCard>> onChanged;
  const NativeDashboardEditor({
    super.key,
    required this.module,
    required this.onChanged,
  });
  Future<void> _edit(BuildContext context, [int? index]) async {
    if (module.collections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a collection before creating metrics.'),
        ),
      );
      return;
    }
    final old = index == null ? null : module.dashboard.cards[index];
    var label = old?.label ?? '';
    String collection =
        module.collections.any((c) => c.id == old?.query['collection'])
        ? old!.query['collection']
        : module.collections.first.id;
    String operation = old?.query['operation'] ?? 'count';
    if (![
      'count',
      'sum',
      'avg',
      'min',
      'max',
      'recent',
      'sum_product',
    ].contains(operation)) {
      operation = 'count';
    }
    String type = old?.type ?? 'kpi';
    String? field = old?.query['field'];
    String? multiplyBy = old?.query['multiply_by'];
    String? group = old?.query['group_by'];
    final saved = await showDialog<DashboardCard>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) {
          final current = module.collections.firstWhere(
            (c) => c.id == collection,
          );
          final numeric = current.fields
              .where(
                (f) => [
                  'number',
                  'currency',
                  'integer',
                  'calculated',
                ].contains(f.type),
              )
              .toList();
          if (!numeric.any((f) => f.key == field)) {
            field = numeric.firstOrNull?.key;
          }
          if (!numeric.any((f) => f.key == multiplyBy)) {
            multiplyBy = numeric.firstOrNull?.key;
          }
          final groups = current.fields
              .where(
                (f) =>
                    !['table', 'list', 'image', 'signature'].contains(f.type),
              )
              .toList();
          if (group != null &&
              group != 'created_month' &&
              !groups.any((f) => f.key == group)) {
            group = null;
          }
          return AlertDialog(
            title: Text(
              index == null ? 'Add dashboard metric' : 'Edit dashboard metric',
            ),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue: label,
                      onChanged: (v) => set(() => label = v),
                      decoration: const InputDecoration(labelText: 'Label'),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: collection,
                      decoration: const InputDecoration(
                        labelText: 'Collection',
                      ),
                      items: module.collections
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.label),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => set(() => collection = v!),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: operation,
                      decoration: const InputDecoration(labelText: 'Operation'),
                      items:
                          const [
                                'count',
                                'sum',
                                'avg',
                                'min',
                                'max',
                                'sum_product',
                                'recent',
                              ]
                              .map(
                                (v) =>
                                    DropdownMenuItem(value: v, child: Text(v)),
                              )
                              .toList(),
                      onChanged: (v) => set(() => operation = v!),
                    ),
                    if (!['count', 'recent'].contains(operation))
                      DropdownButtonFormField<String>(
                        initialValue: field,
                        decoration: const InputDecoration(
                          labelText: 'Numeric field',
                        ),
                        items: numeric
                            .map(
                              (f) => DropdownMenuItem(
                                value: f.key,
                                child: Text(f.label),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => set(() => field = v),
                      ),
                    if (operation == 'sum_product')
                      DropdownButtonFormField<String>(
                        initialValue: multiplyBy,
                        decoration: const InputDecoration(
                          labelText: 'Multiply by',
                        ),
                        items: numeric
                            .map(
                              (f) => DropdownMenuItem(
                                value: f.key,
                                child: Text(f.label),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => set(() => multiplyBy = v),
                      ),
                    DropdownButtonFormField<String>(
                      initialValue: group ?? '',
                      decoration: const InputDecoration(labelText: 'Group by'),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('No grouping'),
                        ),
                        const DropdownMenuItem(
                          value: 'created_month',
                          child: Text('Created month'),
                        ),
                        for (final f in groups)
                          DropdownMenuItem(value: f.key, child: Text(f.label)),
                      ],
                      onChanged: (v) => set(() => group = v == '' ? null : v),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: const InputDecoration(labelText: 'Display'),
                      items: const ['kpi', 'pie', 'bar', 'line', 'list']
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: (v) => set(() => type = v!),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed:
                    label.trim().isEmpty ||
                        (!['count', 'recent'].contains(operation) &&
                            field == null)
                    ? null
                    : () => Navigator.pop(
                        context,
                        DashboardCard(
                          label: label.trim(),
                          type: operation == 'recent' ? 'list' : type,
                          format: old?.format,
                          query: {
                            'collection': collection,
                            'operation': operation,
                            if (field != null &&
                                operation != 'count' &&
                                operation != 'recent')
                              'field': field,
                            if (operation == 'sum_product')
                              'multiply_by': multiplyBy,
                            if (group != null && operation != 'recent')
                              'group_by': group,
                            if (operation == 'recent') 'limit': 5,
                            if (old?.query['filters'] != null)
                              'filters': old!.query['filters'],
                          },
                        ),
                      ),
                child: const Text('Save metric'),
              ),
            ],
          );
        },
      ),
    );
    if (saved != null) {
      final cards = [...module.dashboard.cards];
      if (index == null) {
        cards.add(saved);
      } else {
        cards[index] = saved;
      }
      onChanged(cards);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      for (final entry in module.dashboard.cards.asMap().entries)
        Card(
          child: ListTile(
            title: Text(entry.value.label),
            subtitle: Text(
              '${entry.value.query['operation']} · ${entry.value.query['collection']}',
            ),
            onTap: () => _edit(context, entry.key),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () =>
                  onChanged([...module.dashboard.cards]..removeAt(entry.key)),
            ),
          ),
        ),
      FilledButton.icon(
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add),
        label: const Text('Add metric'),
      ),
    ],
  );
}
