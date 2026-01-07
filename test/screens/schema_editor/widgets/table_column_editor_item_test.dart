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
    // We can find the text 'Sub 1' and the edit/delete buttons associated with it.
    // Since there are multiple delete buttons (main and sub), we need to be careful.
    // The main one is in header. Sub one is in children.
    
    // Find "Add Sub-Column" and tap it to verify dialog opens
    await tester.tap(find.text('Add Sub-Column'));
    await tester.pumpAndSettle();
    
    expect(find.text('Add Column'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
}
