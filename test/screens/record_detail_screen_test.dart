import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/record_detail_screen.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  Widget createRecordDetailScreen({
    required List<ColumnConfig> columns,
    required Map<String, dynamic> data,
    Map<String, SettingItem> settings = const {},
    DetailTemplateConfig? detailTemplate,
  }) {
    return MaterialApp(
      home: RecordDetailScreen(
        columns: columns,
        data: data,
        primaryColor: Colors.blue,
        title: 'Test Record',
        settings: settings,
        detailTemplate: detailTemplate,
      ),
    );
  }

  testWidgets('RecordDetailScreen displays basic fields', (WidgetTester tester) async {
    final columns = [
      ColumnConfig(key: 'name', label: 'Name', type: 'text'),
      ColumnConfig(key: 'age', label: 'Age', type: 'number'),
    ];
    final data = {'name': 'John Doe', 'age': 30};

    await tester.pumpWidget(createRecordDetailScreen(
      columns: columns,
      data: data,
    ));
    await tester.pumpAndSettle();

    expect(find.text('NAME'), findsOneWidget);
    expect(find.text('John Doe'), findsOneWidget);
  });

  testWidgets('RecordDetailScreen handles formula and status fields', (WidgetTester tester) async {
    final columns = [
      ColumnConfig(key: 'total', label: 'Total', type: 'formula'),
      ColumnConfig(key: 'status', label: 'Status', type: 'text'),
    ];
    final data = {'total': '500', 'status': 'Pending'};

    await tester.pumpWidget(createRecordDetailScreen(
      columns: columns,
      data: data,
    ));
    await tester.pumpAndSettle();

    expect(find.text('TOTAL'), findsOneWidget);
    expect(find.text('500'), findsOneWidget);
    expect(find.text('STATUS'), findsOneWidget);
    expect(find.text('PENDING'), findsOneWidget); // Status values are upper-cased
  });

  testWidgets('RecordDetailScreen displays table and image fields', (WidgetTester tester) async {
    final columns = [
      ColumnConfig(key: 'photo', label: 'Photo', type: 'image'),
      ColumnConfig(
        key: 'items', 
        label: 'Items', 
        type: 'table',
        columns: [
          ColumnConfig(key: 'name', label: 'Item Name', type: 'text'),
        ]
      ),
    ];
    final data = {
      'photo': 'http://example.com/image.jpg',
      'items': [
        {'name': 'SubItem 1'},
      ],
    };

    await tester.pumpWidget(createRecordDetailScreen(
      columns: columns,
      data: data,
    ));
    await tester.pumpAndSettle();

    expect(find.text('PHOTO'), findsOneWidget);
    expect(find.text('ITEMS'), findsOneWidget);
    expect(find.text('SubItem 1'), findsOneWidget);
  });

  testWidgets('RecordDetailScreen handles settings dependency', (WidgetTester tester) async {
    final columns = [
      ColumnConfig(key: 'f1', label: 'Field 1', type: 'text', dependsOn: 'settings.show_f1'),
      ColumnConfig(key: 'f2', label: 'Field 2', type: 'text', dependsOn: 'non_existent'),
    ];
    final settings = {
      'show_f1': SettingItem(label: 'Show F1', type: 'boolean', value: true),
    };

    await tester.pumpWidget(createRecordDetailScreen(
      columns: columns,
      settings: settings,
      data: {'f1': 'Visible', 'f2': 'Hidden'},
    ));
    await tester.pumpAndSettle();

    expect(find.text('FIELD 1'), findsOneWidget);
    expect(find.text('FIELD 2'), findsNothing);
  });

  testWidgets('RecordDetailScreen uses modern template', (WidgetTester tester) async {
     final template = DetailTemplateConfig(
      template: 'modern',
      titleKey: 'name',
    );
     await tester.pumpWidget(createRecordDetailScreen(
      columns: [ColumnConfig(key: 'name', label: 'Name', type: 'text')],
      data: {'name': 'Modern Title'},
      detailTemplate: template,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Modern Title'), findsWidgets);
  });
}
