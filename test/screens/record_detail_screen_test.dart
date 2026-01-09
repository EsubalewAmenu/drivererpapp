import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/record_detail_screen.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('RecordDetailScreen renders standard template', (WidgetTester tester) async {
    final data = {
      'name': 'John Doe',
      'email': 'john@example.com',
      'status': 'Active',
    };
    
    final columns = [
      ColumnConfig(key: 'name', label: 'Full Name', type: 'text'),
      ColumnConfig(key: 'email', label: 'Email Address', type: 'email'),
      ColumnConfig(key: 'status', label: 'Current Status', type: 'text'),
    ];

    await tester.pumpWidget(MaterialApp(
      home: RecordDetailScreen(
        data: data,
        columns: columns,
        primaryColor: Colors.blue,
        title: 'Customer Details',
      ),
    ));

    expect(find.text('DETAILS'), findsOneWidget);
    expect(find.text('John Doe'), findsOneWidget);
    expect(find.text('FULL NAME'), findsOneWidget);
    expect(find.text('john@example.com'), findsOneWidget);
    expect(find.text('EMAIL ADDRESS'), findsOneWidget);
  });

  testWidgets('RecordDetailScreen renders modern template', (WidgetTester tester) async {
    final data = {
      'name': 'Modern Record',
      'type': 'Premium',
    };
    
    final columns = [
      ColumnConfig(key: 'name', label: 'Name', type: 'text'),
      ColumnConfig(key: 'type', label: 'Type', type: 'text'),
    ];

    final detailTemplate = DetailTemplateConfig(
      template: 'modern',
      titleKey: 'name',
      subtitleKey: 'type',
    );

    await tester.pumpWidget(MaterialApp(
      home: RecordDetailScreen(
        data: data,
        columns: columns,
        primaryColor: Colors.purple,
        title: 'Modern Record Title',
        detailTemplate: detailTemplate,
      ),
    ));

    expect(find.text('Modern Record'), findsOneWidget);
    expect(find.text('Premium'), findsOneWidget);
    expect(find.text('RECORD ENTRY'), findsOneWidget);
  });

  testWidgets('RecordDetailScreen filters fields by dependsOn', (WidgetTester tester) async {
    final data = {
      'show_extra': true,
      'extra_info': 'Secret Data',
      'hidden_info': 'Hidden Data',
    };
    
    final columns = [
      ColumnConfig(key: 'show_extra', label: 'Show Extra', type: 'boolean'),
      ColumnConfig(key: 'extra_info', label: 'Extra Info', type: 'text', dependsOn: 'show_extra'),
      ColumnConfig(key: 'hidden_info', label: 'Hidden Info', type: 'text', dependsOn: 'non_existent'),
    ];

    await tester.pumpWidget(MaterialApp(
      home: RecordDetailScreen(
        data: data,
        columns: columns,
        primaryColor: Colors.green,
        title: 'Depends Test',
      ),
    ));

    expect(find.text('EXTRA INFO'), findsOneWidget);
    expect(find.text('Secret Data'), findsOneWidget);
    expect(find.text('HIDDEN INFO'), findsNothing);
  });

  testWidgets('RecordDetailScreen renders specialized fields (Table, List, Image)', (WidgetTester tester) async {
    final data = {
      'items': [
        {'name': 'Item A', 'qty': 10},
        {'name': 'Item B', 'qty': 5},
      ],
      'tags': ['Urgent', 'Invoiced'],
      'photo': 'https://example.com/img.png',
      'calc': '15.5',
    };
    
    final columns = [
      ColumnConfig(
        key: 'items', 
        label: 'Order Items', 
        type: 'table',
        columns: [
          ColumnConfig(key: 'name', label: 'Name', type: 'text'),
          ColumnConfig(key: 'qty', label: 'Qty', type: 'number'),
        ],
      ),
      ColumnConfig(key: 'tags', label: 'Tags', type: 'list'),
      ColumnConfig(key: 'photo', label: 'Photo', type: 'image'),
      ColumnConfig(key: 'calc', label: 'Calculation', type: 'formula'),
    ];

    await tester.pumpWidget(MaterialApp(
      home: RecordDetailScreen(
        data: data,
        columns: columns,
        primaryColor: Colors.orange,
        title: 'Specialized Fields',
      ),
    ));

    expect(find.text('ORDER ITEMS'), findsOneWidget);
    expect(find.text('Item A'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    
    expect(find.text('TAGS'), findsOneWidget);
    expect(find.text('Urgent'), findsOneWidget);
    expect(find.text('Invoiced'), findsOneWidget);

    expect(find.text('PHOTO'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    expect(find.text('CALCULATION'), findsOneWidget);
    expect(find.text('15.5'), findsOneWidget);
  });

  testWidgets('RecordDetailScreen uses detailKeys if showAllFields is false', (WidgetTester tester) async {
    final data = {'k1': 'v1', 'k2': 'v2', 'k3': 'v3'};
    final columns = [
      ColumnConfig(key: 'k1', label: 'L1', type: 'text'),
      ColumnConfig(key: 'k2', label: 'L2', type: 'text'),
      ColumnConfig(key: 'k3', label: 'L3', type: 'text'),
    ];
    final template = DetailTemplateConfig(
      template: 'standard',
      showAllFields: false,
      detailKeys: ['k1', 'k3'],
    );

    await tester.pumpWidget(MaterialApp(
      home: RecordDetailScreen(
        data: data,
        columns: columns,
        primaryColor: Colors.blue,
        title: 'Limited Fields',
        detailTemplate: template,
      ),
    ));

    expect(find.text('L1'), findsOneWidget);
    expect(find.text('L3'), findsOneWidget);
    expect(find.text('L2'), findsNothing);
  });
}
