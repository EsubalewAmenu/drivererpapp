import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/schema_editor/dialogs/edit_column_dialog.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('EditColumnDialog updates basic fields', (WidgetTester tester) async {
    final column = ColumnConfig(key: 'col1', label: 'Column 1', type: 'text', hidden: false);
    final tab = TabConfig(id: 't1', label: 'Tab 1', columns: [column]);
    
    ColumnConfig? updatedColumn;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              updatedColumn = await showDialog<ColumnConfig>(
                context: context,
                builder: (context) => EditColumnDialog(column: column, tab: tab),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Column'), findsOneWidget);
    
    // Label change
    await tester.enterText(find.widgetWithText(TextField, 'Column Name'), 'New Label');
    
    // Hidden Toggle
    await tester.tap(find.widgetWithText(SwitchListTile, 'Hidden (Don\'t show on form)'));
    await tester.pump();
    
    // Depends On Dropdown exists
    // Using simple text finder as widgetWithText can be flaky with generics
    expect(find.text('Depends On (Optional)'), findsOneWidget);

    // Save
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(updatedColumn, isNotNull);
    expect(updatedColumn!.label, 'New Label');
    expect(updatedColumn!.hidden, true);
  });

  testWidgets('EditColumnDialog changes type', (WidgetTester tester) async {
    final column = ColumnConfig(key: 'col1', label: 'Column 1', type: 'text');
    final tab = TabConfig(id: 't1', label: 'Tab 1', columns: [column]);
    
    ColumnConfig? updatedColumn;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              updatedColumn = await showDialog<ColumnConfig>(
                context: context,
                builder: (context) => EditColumnDialog(column: column, tab: tab),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Find Type Dropdown - It's the first dropdown
    final typeDropdown = find.byWidgetPredicate((widget) => widget is DropdownButtonFormField<String>).first;
    await tester.tap(typeDropdown);
    await tester.pumpAndSettle();
    
    // Select Boolean
    await tester.tap(find.text('BOOLEAN').last); // .last because it might be in list and selected item
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(updatedColumn, isNotNull);
    expect(updatedColumn!.type, 'boolean');
  });

  testWidgets('EditColumnDialog cancels', (WidgetTester tester) async {
    final column = ColumnConfig(key: 'col1', label: 'Column 1', type: 'text');
    final tab = TabConfig(id: 't1', label: 'Tab 1', columns: [column]);
    
    bool dialogClosed = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              final result = await showDialog<ColumnConfig>(
                context: context,
                builder: (context) => EditColumnDialog(column: column, tab: tab),
              );
              if (result == null) dialogClosed = true;
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(dialogClosed, isTrue);
  });
}
