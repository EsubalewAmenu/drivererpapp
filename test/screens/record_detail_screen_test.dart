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
}
