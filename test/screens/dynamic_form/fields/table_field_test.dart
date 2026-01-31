import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/dynamic_form/fields/table_field.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('DynamicTableField renders and adds item', (WidgetTester tester) async {
    List<Map<String, dynamic>>? changedValue;
    
    final subColumns = [
      ColumnConfig(key: 'item_name', label: 'Item Name', type: 'text'),
      ColumnConfig(key: 'qty', label: 'Qty', type: 'number'),
    ];

    final column = ColumnConfig(
      key: 'items',
      label: 'Order Items',
      type: 'table',
      columns: subColumns,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DynamicTableField(
            column: column,
            value: const [
              {'item_name': 'Existing Item', 'qty': '1'}
            ],
            primaryColor: Colors.blue,
            onChanged: (val) => changedValue = val,
          ),
        ),
      ),
    );

    expect(find.text('ORDER ITEMS'), findsOneWidget);
    expect(find.text('Existing Item'), findsOneWidget);
    expect(find.text('Add Item'), findsOneWidget);

    // Tap Add Item
    await tester.tap(find.text('Add Item'));
    await tester.pumpAndSettle();

    // Dialog should appear with sub-fields
    expect(find.text('Add Order Items Item'), findsOneWidget);
    expect(find.text('ITEM NAME'), findsOneWidget);
    expect(find.text('QTY'), findsOneWidget);

    // Enter data
    await tester.enterText(find.widgetWithText(TextFormField, 'Enter item name'), 'New Item');
    await tester.enterText(find.widgetWithText(TextFormField, 'Enter qty'), '5');

    // Save
    await tester.tap(find.text('Save Item'));
    await tester.pumpAndSettle();

    expect(changedValue!.length, 2);
    expect(changedValue!.last['item_name'], 'New Item');
  });

  testWidgets('DynamicTableField edits and deletes items', (WidgetTester tester) async {
    List<Map<String, dynamic>>? changedValue;
    
    final subColumns = [
      ColumnConfig(key: 'item_name', label: 'Item Name', type: 'text'),
    ];

    final column = ColumnConfig(
      key: 'items',
      label: 'Order Items',
      type: 'table',
      columns: subColumns,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DynamicTableField(
            column: column,
            value: const [
              {'item_name': 'Item 1'},
              {'item_name': 'Item 2'},
            ],
            primaryColor: Colors.blue,
            onChanged: (val) => changedValue = val,
          ),
        ),
      ),
    );

    expect(find.text('Item 1'), findsOneWidget);
    expect(find.text('Item 2'), findsOneWidget);

    // 1. Edit Item 1
    await tester.tap(find.byIcon(Icons.edit).first);
    await tester.pumpAndSettle();
    
    expect(find.text('Edit Order Items Item'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Enter item name'), 'Updated Item');
    await tester.tap(find.text('Save Item'));
    await tester.pumpAndSettle();

    expect(changedValue!.length, 2);
    expect(changedValue![0]['item_name'], 'Updated Item');

    // 2. Delete Item 2
    await tester.tap(find.byIcon(Icons.delete).last);
    await tester.pumpAndSettle();

    expect(changedValue!.length, 1);
    expect(changedValue![0]['item_name'], 'Item 1'); // Wait, the previous test might have used the original value
  });
}
