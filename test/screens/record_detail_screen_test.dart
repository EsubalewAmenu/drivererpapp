import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/record_detail_screen.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('RecordDetailScreen displays generic fields', (WidgetTester tester) async {
    final columns = [
      ColumnConfig(key: 'name', label: 'Name', type: 'text'),
      ColumnConfig(key: 'sku', label: 'SKU', type: 'text'),
    ];
    final data = {'name': 'Widget A', 'sku': '12345'};

    await tester.pumpWidget(MaterialApp(
      home: RecordDetailScreen(title: 'Item', data: data, columns: columns, primaryColor: Colors.blue),
    ));

    expect(find.text('NAME'), findsOneWidget);
    expect(find.text('Widget A'), findsOneWidget);
    expect(find.text('SKU'), findsOneWidget);
    expect(find.text('12345'), findsOneWidget);
  });

  testWidgets('RecordDetailScreen displays list field from List object', (WidgetTester tester) async {
    final columns = [
      ColumnConfig(key: 'tags', label: 'Tags', type: 'list'),
    ];
    final data = {
      'tags': ['Tag1', 'Tag2'],
    };

    await tester.pumpWidget(MaterialApp(
      home: RecordDetailScreen(
        title: 'Test Record',
        data: data,
        columns: columns,
        primaryColor: Colors.blue,
      ),
    ));

    expect(find.text('TAGS'), findsOneWidget);
    expect(find.text('Tag1'), findsOneWidget);
    expect(find.text('Tag2'), findsOneWidget);
    expect(find.byType(Wrap), findsOneWidget);
  });

  testWidgets('RecordDetailScreen displays list field from JSON string', (WidgetTester tester) async {
    final columns = [
      ColumnConfig(key: 'tags', label: 'Tags', type: 'list'),
    ];
    final data = {
      'tags': jsonEncode(['JSON1', 'JSON2']),
    };

    await tester.pumpWidget(MaterialApp(
      home: RecordDetailScreen(
        title: 'Test Record',
        data: data,
        columns: columns,
        primaryColor: Colors.blue,
      ),
    ));

    expect(find.text('TAGS'), findsOneWidget);
    expect(find.text('JSON1'), findsOneWidget);
    expect(find.text('JSON2'), findsOneWidget);
  });

  testWidgets('RecordDetailScreen handles dependency visibility', (WidgetTester tester) async {
    final columns = [
      ColumnConfig(key: 'has_extra', label: 'Has Extra', type: 'boolean'),
      ColumnConfig(key: 'extra_info', label: 'Extra Info', type: 'text', dependsOn: 'has_extra'),
    ];

    // Case 1: has_extra is false (or null), extra_info should be hidden
    await tester.pumpWidget(MaterialApp(
      home: RecordDetailScreen(
        title: 'Record',
        data: const {'has_extra': false}, 
        columns: columns, 
        primaryColor: Colors.blue
      ),
    ));
    expect(find.text('EXTRA INFO'), findsNothing);

    // Case 2: has_extra is true, extra_info should be visible
    await tester.pumpWidget(MaterialApp(
      home: RecordDetailScreen(
        title: 'Record',
        data: const {'has_extra': true, 'extra_info': 'Secret'}, 
        columns: columns, 
        primaryColor: Colors.blue
      ),
    ));
    expect(find.text('EXTRA INFO'), findsOneWidget);
    expect(find.text('Secret'), findsOneWidget);
  });

  testWidgets('RecordDetailScreen displays modern template and hides header fields from list', (WidgetTester tester) async {
    final columns = [
      ColumnConfig(key: 'name', label: 'Name', type: 'text'),
      ColumnConfig(key: 'desc', label: 'Description', type: 'text'),
      ColumnConfig(key: 'price', label: 'Price', type: 'text'),
    ];
    final data = {
      'name': 'Modern Item',
      'desc': 'Detailed info',
      'price': r'$100',
      'img': 'https://example.com/image.png'
    };
    final template = DetailTemplateConfig(
      template: 'modern',
      titleKey: 'name',
      subtitleKey: 'desc',
      imageKey: 'img'
    );

    await tester.pumpWidget(MaterialApp(
      home: RecordDetailScreen(
        title: 'Title',
        data: data,
        columns: columns,
        primaryColor: Colors.blue,
        detailTemplate: template,
      ),
    ));

    // Modern title and subtitle in header
    expect(find.text('Modern Item'), findsOneWidget);
    expect(find.text('Detailed info'), findsOneWidget);
    
    // Header keys should be hidden from fields list
    expect(find.text('NAME'), findsNothing);
    expect(find.text('DESCRIPTION'), findsNothing);
    
    // Non-header key should be visible
    expect(find.text('PRICE'), findsOneWidget);
    expect(find.text(r'$100'), findsOneWidget);
  });

  testWidgets('RecordDetailScreen displays table field', (WidgetTester tester) async {
    final columns = [
      ColumnConfig(
        key: 'items', 
        label: 'Order Items', 
        type: 'table',
        columns: [
          ColumnConfig(key: 'sku', label: 'SKU', type: 'text'),
          ColumnConfig(key: 'qty', label: 'Qty', type: 'number'),
        ]
      ),
    ];
    final data = {
      'items': [
        {'sku': 'A1', 'qty': 5},
        {'sku': 'B2', 'qty': 10},
      ]
    };

    await tester.pumpWidget(MaterialApp(
      home: RecordDetailScreen(
        title: 'Order',
        data: data,
        columns: columns,
        primaryColor: Colors.blue,
      ),
    ));

    expect(find.text('ORDER ITEMS'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('A1'), findsOneWidget);
    expect(find.text('B2'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('RecordDetailScreen displays status field custom styling', (WidgetTester tester) async {
     final columns = [
      ColumnConfig(key: 'status', label: 'Status', type: 'text'),
    ];
     // Status typically renders with color pill
    await tester.pumpWidget(MaterialApp(
      home: RecordDetailScreen(
        title: 'Record',
        data: const {'status': 'Approved'}, 
        columns: columns, 
        primaryColor: Colors.blue
      ),
    ));
    
    expect(find.text('APPROVED'), findsOneWidget);
  });

  testWidgets('RecordDetailScreen displays formula field', (WidgetTester tester) async {
     final columns = [
      ColumnConfig(key: 'total', label: 'Total', type: 'formula'),
    ];
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        cardTheme: const CardThemeData(color: Colors.white),
      ),
      home: RecordDetailScreen(
        title: 'Record',
        data: const {'total': '100.00'}, 
        columns: columns, 
        primaryColor: Colors.blue
      ),
    ));
    
    expect(find.text('TOTAL'), findsOneWidget);
    expect(find.text('100.00'), findsOneWidget);
  });
}