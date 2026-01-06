import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/dynamic_form/fields/list_field.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('DynamicListField adds and removes items', (WidgetTester tester) async {
    List<String>? changedList;
    final column = ColumnConfig(
      key: 'test_list',
      label: 'Test List',
      type: 'list',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DynamicListField(
            column: column,
            value: ['Item1', 'Item2'],
            primaryColor: Colors.blue,
            onChanged: (val) => changedList = val,
          ),
        ),
      ),
    );

    expect(find.text('TEST LIST'), findsOneWidget);
    expect(find.text('Item1'), findsOneWidget);
    expect(find.text('Item2'), findsOneWidget);

    // Remove Item1
    await tester.tap(find.descendant(
      of: find.widgetWithText(Chip, 'Item1'),
      matching: find.byIcon(Icons.close),
    ));
    await tester.pump();

    expect(changedList, ['Item2']);

    // Add Item3
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Add Test List'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Item3');
    await tester.tap(find.text('Add').last); // The button in dialog
    await tester.pumpAndSettle();

    expect(changedList, contains('Item3'));
  });
}
