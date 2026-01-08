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

  testWidgets('EditColumnDialog updates isRequired field', (WidgetTester tester) async {
    final column = ColumnConfig(key: 'col1', label: 'Column 1', type: 'text', isRequired: false);
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

    // Find and tap "Is Required" toggle
    await tester.tap(find.widgetWithText(SwitchListTile, 'Is Required'));
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(updatedColumn, isNotNull);
    expect(updatedColumn!.isRequired, true);
  });

  testWidgets('EditColumnDialog updates currency symbol', (WidgetTester tester) async {
    final column = ColumnConfig(key: 'col', label: 'Price', type: 'currency', currencySymbol: '\$');
    final tab = TabConfig(id: 't1', label: 'T1', columns: [column]);
    ColumnConfig? result;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (c) => ElevatedButton(
          onPressed: () async => result = await showDialog(context: c, builder: (c) => EditColumnDialog(column: column, tab: tab)),
          child: const Text('Open'),
        ))
      )
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final currencyDropdown = find.text('USD (\$)');
    await tester.ensureVisible(currencyDropdown);
    await tester.tap(currencyDropdown);
    await tester.pumpAndSettle();
    
    final etbOption = find.text('ETB (Br)').last;
    await tester.tap(etbOption);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result!.currencySymbol, 'Br');
  });

  testWidgets('EditColumnDialog edits static options for select type', (WidgetTester tester) async {
    final column = ColumnConfig(key: 'col', label: 'Choice', type: 'select', options: ['A', 'B']);
    final tab = TabConfig(id: 't1', label: 'T1', columns: [column]);
    ColumnConfig? result;

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (c) => ElevatedButton(
      onPressed: () async => result = await showDialog(context: c, builder: (c) => EditColumnDialog(column: column, tab: tab)),
      child: const Text('Open'),
    )))));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Check existing chips
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);

    // Add option
    final addButton = find.byIcon(Icons.add);
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();
    
    await tester.enterText(find.byType(TextField).last, 'C');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('C'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result!.options as List, containsAll(['A', 'B', 'C']));
  });

  testWidgets('EditColumnDialog configures dynamic options', (WidgetTester tester) async {
    final column = ColumnConfig(key: 'col', label: 'Choice', type: 'select');
    final tab = TabConfig(id: 't1', label: 'T1', columns: [column]);
    final rawSettings = {
      'categories': {'type': 'list', 'label': 'Cats', 'value': ['C1', 'C2']}
    };
    ColumnConfig? result;

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (c) => ElevatedButton(
      onPressed: () async => result = await showDialog(context: c, builder: (c) => EditColumnDialog(column: column, tab: tab, rawSettings: rawSettings)),
      child: const Text('Open'),
    )))));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Tap Dynamic Radio
    final dynamicRadio = find.text('Dynamic');
    await tester.ensureVisible(dynamicRadio);
    await tester.tap(dynamicRadio);
    await tester.pumpAndSettle();

    // Select dynamic source
    final dropdownLabel = find.text('Select Setting List');
    await tester.ensureVisible(dropdownLabel);
    await tester.tap(dropdownLabel);
    await tester.pumpAndSettle();
    
    // Choose categories
    await tester.tap(find.text('categories').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result!.options, 'settings.categories');
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
