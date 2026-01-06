import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/dynamic_form/fields/dropdown_field.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('DynamicDropdownField renders with options', (WidgetTester tester) async {
    String? changedValue;
    final column = ColumnConfig(
      key: 'test_dropdown',
      label: 'Test Dropdown',
      type: 'select',
      options: ['Option 1', 'Option 2'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DynamicDropdownField(
            column: column,
            value: null,
            onChanged: (val) => changedValue = val,
            data: {},
          ),
        ),
      ),
    );

    expect(find.text('TEST DROPDOWN'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);

    // Tap to open dropdown
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    expect(find.text('Option 1').last, findsOneWidget);
    expect(find.text('Option 2').last, findsOneWidget);

    // Select option
    await tester.tap(find.text('Option 1').last);
    await tester.pumpAndSettle();

    expect(changedValue, 'Option 1');
  });
}
