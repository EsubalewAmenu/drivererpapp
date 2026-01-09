import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/record_detail_screen.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  Widget createScreen({
    required List<ColumnConfig> columns,
    required Map<String, dynamic> data,
    Map<String, SettingItem> settings = const {},
    DetailTemplateConfig? template,
  }) {
    return MaterialApp(
      home: RecordDetailScreen(
        columns: columns,
        data: data,
        settings: settings,
        primaryColor: Colors.blue,
        title: 'Test',
        detailTemplate: template,
      ),
    );
  }

  testWidgets('RecordDetailScreen Comprehensive', (tester) async {
    final cols = [
      ColumnConfig(key: 't', label: 'T', type: 'text'),
      ColumnConfig(key: 'f', label: 'F', type: 'formula'),
      ColumnConfig(key: 'i', label: 'I', type: 'image'),
      ColumnConfig(key: 'ie', label: 'IE', type: 'image'), // null value
      ColumnConfig(key: 'status', label: 'S', type: 'text'),
      ColumnConfig(key: 'tab', label: 'Tab', type: 'table', columns: [
        ColumnConfig(key: 's1', label: 'S1', type: 'text'),
      ]),
      ColumnConfig(key: 'tabe', label: 'TabE', type: 'table', columns: []),
      ColumnConfig(key: 'd1', label: 'D1', type: 'text', dependsOn: 'on'),
      ColumnConfig(key: 'd2', label: 'D2', type: 'text', dependsOn: 'off'),
      ColumnConfig(key: 'd3', label: 'D3', type: 'text', dependsOn: 'settings.son'),
      ColumnConfig(key: 'd4', label: 'D4', type: 'text', dependsOn: 'settings.soff'),
    ];

    final data = {
      't': 'val',
      'f': 'form',
      'i': 'url',
      'tab': [{'s1': 'v'}],
      'on': true,
      'off': false,
      'd1': 'v1',
      'd3': 'v3',
    };

    final settings = {
      'son': SettingItem(label: 'L', type: 'b', value: true),
      'soff': SettingItem(label: 'L', type: 'b', value: false),
    };

    await tester.pumpWidget(createScreen(columns: cols, data: data, settings: settings));
    await tester.pumpAndSettle();

    // Trigger all statuses
    final s_cols = [ColumnConfig(key: 'status', label: 'S', type: 'text')];
    final statuses = ['paid', 'completed', 'active', 'delivered', 'pending', 'cancelled', 'error', 'failed', 'inactive', 'unknown'];
    for (var s in statuses) {
      await tester.pumpWidget(createScreen(columns: s_cols, data: {'status': s}));
      await tester.pump();
    }

    // Modern template + missing title key
    await tester.pumpWidget(createScreen(
      columns: [],
      data: {},
      template: DetailTemplateConfig(template: 'modern', titleKey: 'none'),
    ));
    await tester.pumpAndSettle();
  });
}
