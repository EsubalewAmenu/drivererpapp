import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/record_detail_screen.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('RecordDetailScreen displays list field from List object', (WidgetTester tester) async {
    final columns = [
      ColumnConfig(key: 'tags', label: 'Tags', type: 'list'),
    ];
    final data = {
      'tags': ['Tag1', 'Tag2'],
    };

    await tester.pumpWidget(
      MaterialApp(
        home: RecordDetailScreen(
          title: 'Test Record',
          data: data,
          columns: columns,
          primaryColor: Colors.blue,
        ),
      ),
    );

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

    await tester.pumpWidget(
      MaterialApp(
        home: RecordDetailScreen(
          title: 'Test Record',
          data: data,
          columns: columns,
          primaryColor: Colors.blue,
        ),
      ),
    );

    expect(find.text('TAGS'), findsOneWidget);
    expect(find.text('JSON1'), findsOneWidget);
    expect(find.text('JSON2'), findsOneWidget);
  });

  testWidgets('RecordDetailScreen displays basic fields', (WidgetTester tester) async {
    final columns = [
      ColumnConfig(key: 'name', label: 'Name', type: 'text'),
      ColumnConfig(key: 'price', label: 'Price', type: 'currency'),
    ];
    final data = {
      'name': 'Widget A',
      'price': '100',
    };

    await tester.pumpWidget(
      MaterialApp(
        home: RecordDetailScreen(
          title: 'Widget A Details',
          data: data,
          columns: columns,
          primaryColor: Colors.blue,
        ),
      ),
    );

    expect(find.text('NAME'), findsOneWidget);
    expect(find.text('Widget A'), findsOneWidget);
    expect(find.text('PRICE'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
  });
}
