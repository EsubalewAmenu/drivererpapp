import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/schema_editor/widgets/tab_editor_card.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/screens/schema_editor/widgets/column_list_item.dart';
import 'package:drivererpapp/screens/schema_editor/widgets/table_column_editor_item.dart';

void main() {
  testWidgets('TabEditorCard renders basic info and callbacks', (WidgetTester tester) async {
    final tab = TabConfig(id: 't1', label: 'My Tab', columns: []);
    
    bool editCalled = false;
    bool deleteCalled = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView( // For expansion
          children: [
            TabEditorCard(
              tab: tab,
              rawSettings: const {},
              onTabChanged: (_) {},
              onDelete: () => deleteCalled = true,
              onEdit: () => editCalled = true,
            ),
          ],
        ),
      ),
    ));

    expect(find.text('My Tab'), findsOneWidget);
    
    await tester.tap(find.byIcon(Icons.edit_rounded));
    expect(editCalled, isTrue);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    expect(deleteCalled, isTrue);
  });

  testWidgets('TabEditorCard renders columns and handles additions', (WidgetTester tester) async {
    final col1 = ColumnConfig(key: 'c1', label: 'Col 1', type: 'text');
    final col2 = ColumnConfig(key: 't1', label: 'Table 1', type: 'table', columns: []);
    
    final tab = TabConfig(id: 't1', label: 'My Tab', columns: [col1, col2]);
    
    TabConfig? updatedTab;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            TabEditorCard(
              tab: tab,
              rawSettings: const {},
              onTabChanged: (val) => updatedTab = val,
              onDelete: () {},
              onEdit: () {},
            ),
          ],
        ),
      ),
    ));

    // Expand
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();

    expect(find.byType(ColumnListItem), findsOneWidget); // Col 1
    expect(find.byType(TableColumnEditorItem), findsOneWidget); // Table 1

    expect(find.text('Col 1'), findsOneWidget);
    expect(find.text('Table 1'), findsOneWidget);

    // Edit Column (Col 1)
    final colItemFinder = find.byType(ColumnListItem);
    final colEditBtn = find.descendant(of: colItemFinder, matching: find.byIcon(Icons.edit_rounded));
    
    await tester.tap(colEditBtn);
    await tester.pumpAndSettle();
    expect(find.text('Edit Column'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Add Column
    await tester.tap(find.text('Add Column'));
    await tester.pumpAndSettle();

    expect(find.text('Add Column'), findsNWidgets(2)); // Button + Dialog Title
    
    // Close dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('TabEditorCard handles column deletion', (WidgetTester tester) async {
    final col1 = ColumnConfig(key: 'c1', label: 'Col 1', type: 'text');
    final tab = TabConfig(id: 't1', label: 'My Tab', columns: [col1]);
    
    TabConfig? updatedTab;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            TabEditorCard(
              tab: tab,
              rawSettings: const {},
              onTabChanged: (val) => updatedTab = val,
              onDelete: () {},
              onEdit: () {},
            ),
          ],
        ),
      ),
    ));

    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();

    // Find delete button on col1. 
    // Tab header has delete. Column List Item has delete.
    // ColumnListItem delete is likely Icons.delete_outline_rounded too.
    // We need to differentiate.
    // Tab header delete is tapped in first test. 
    // Column delete is in the children.
    
    // Find descendent of ColumnListItem
    final colItemFinder = find.byType(ColumnListItem);
    final deleteBtn = find.descendant(of: colItemFinder, matching: find.byIcon(Icons.delete_outline_rounded));
    
    await tester.tap(deleteBtn);
    await tester.pumpAndSettle();
    
    // Confirm delete dialog
    expect(find.text('Delete Column'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(updatedTab!.columns, isEmpty);
  });

  testWidgets('TabEditorCard handles table column update', (WidgetTester tester) async {
    final col1 = ColumnConfig(key: 't1', label: 'Table 1', type: 'table', columns: []);
    final tab = TabConfig(id: 't1', label: 'My Tab', columns: [col1]);
    
    TabConfig? updatedTab;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            TabEditorCard(
              tab: tab,
              rawSettings: const {},
              onTabChanged: (val) => updatedTab = val,
              onDelete: () {},
              onEdit: () {},
            ),
          ],
        ),
      ),
    ));

    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();

    final tableItem = tester.widget<TableColumnEditorItem>(find.byType(TableColumnEditorItem));
    final updatedCol = col1.copyWith(label: 'New Label');
    
    tableItem.onUpdate(updatedCol);
    expect(updatedTab!.columns.first.label, 'New Label');
  });
}
