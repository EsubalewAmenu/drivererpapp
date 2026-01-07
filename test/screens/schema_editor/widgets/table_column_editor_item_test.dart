import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/schema_editor/widgets/table_column_editor_item.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('TableColumnEditorItem renders and shows sub-columns', (WidgetTester tester) async {
    final column = ColumnConfig(
      key: 'table1',
      label: 'My Table',
      type: 'table',
      columns: [
        ColumnConfig(key: 'sub1', label: 'Sub 1', type: 'text'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TableColumnEditorItem(
            column: column,
            onEdit: () {},
            onDelete: () {},
            onUpdate: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('My Table'), findsOneWidget);
    expect(find.text('TABLE'), findsOneWidget);
    expect(find.text('1 Sub-columns'), findsOneWidget);

    // Expand tile
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();

    expect(find.text('TABLE COLUMNS'), findsOneWidget);
    expect(find.text('Sub 1'), findsOneWidget);
    expect(find.text('Add Sub-Column'), findsOneWidget);
  });
}
