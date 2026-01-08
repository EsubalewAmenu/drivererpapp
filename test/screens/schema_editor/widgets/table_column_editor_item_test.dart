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

    bool editCalled = false;
    bool deleteCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView( // Wrapped in ListView for scrolling if needed
            children: [
              TableColumnEditorItem(
                column: column,
                onEdit: () => editCalled = true,
                onDelete: () => deleteCalled = true,
                onUpdate: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('My Table'), findsOneWidget);
    expect(find.text('TABLE'), findsOneWidget);
    expect(find.text('1 Sub-columns'), findsOneWidget);

    // Test main actions
    await tester.tap(find.byIcon(Icons.edit_rounded).first);
    expect(editCalled, isTrue);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
    expect(deleteCalled, isTrue);
    
    // Expand tile
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();

    expect(find.text('TABLE COLUMNS'), findsOneWidget);
    expect(find.text('Sub 1'), findsOneWidget);
    expect(find.text('Add Sub-Column'), findsOneWidget);
  });

  testWidgets('TableColumnEditorItem interacts with sub-columns', (WidgetTester tester) async {
    final column = ColumnConfig(
      key: 'table1',
      label: 'My Table',
      type: 'table',
      columns: [
        ColumnConfig(key: 'sub1', label: 'Sub 1', type: 'text'),
      ],
    );

    ColumnConfig? updatedConfig;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              TableColumnEditorItem(
                column: column,
                onEdit: () {},
                onDelete: () {},
                onUpdate: (val) => updatedConfig = val,
                rawSettings: const {},
              ),
            ],
          ),
        ),
      ),
    );

    // Expand tile
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();

    // Verify sub-column item exists (ColumnListItem)
    expect(find.text('Sub 1'), findsOneWidget);

    // Test Delete Sub-Column
    await tester.tap(find.byIcon(Icons.delete_outline_rounded).last);
    await tester.pumpAndSettle();

    expect(find.text('Delete Sub-Column'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(updatedConfig, isNotNull);
    expect(updatedConfig!.columns!.length, 0);

    // Test Add Sub-Column
    await tester.tap(find.text('Add Sub-Column'));
    await tester.pumpAndSettle();
    
    expect(find.text('Add Column'), findsOneWidget);
    
    // Fill the AddColumnDialog
    await tester.enterText(find.widgetWithText(TextField, 'Column Name').first, 'New Sub');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(updatedConfig, isNotNull);
    expect(updatedConfig!.columns!.length, 2);
    expect(updatedConfig!.columns!.last.label, 'New Sub');
  });
}
