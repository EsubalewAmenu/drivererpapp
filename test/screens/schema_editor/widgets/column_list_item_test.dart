import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/schema_editor/widgets/column_list_item.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('ColumnListItem renders correctly', (WidgetTester tester) async {
    final column = ColumnConfig(key: 'col1', label: 'My Column', type: 'text');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ColumnListItem(
            column: column,
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      ),
    );

    expect(find.text('My Column'), findsOneWidget);
    expect(find.text('TEXT'), findsOneWidget);
    expect(find.byIcon(Icons.text_fields), findsOneWidget);
  });

  testWidgets('ColumnListItem renders hidden state', (WidgetTester tester) async {
    final column = ColumnConfig(key: 'col1', label: 'My Column', type: 'text', hidden: true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ColumnListItem(
            column: column,
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      ),
    );

    expect(find.text('HIDDEN'), findsOneWidget);
  });
}
