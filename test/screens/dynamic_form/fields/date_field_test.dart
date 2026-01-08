import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/dynamic_form/fields/date_field.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('DynamicDateField shows picker and selects date', (WidgetTester tester) async {
    final column = ColumnConfig(key: 'date', label: 'Order Date', type: 'date');
    String? newValue;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DynamicDateField(
          column: column,
          value: null,
          primaryColor: Colors.blue,
          onChanged: (val) => newValue = val,
        ),
      ),
    ));

    expect(find.text('ORDER DATE'), findsOneWidget);
    expect(find.text('Select Date'), findsOneWidget);

    await tester.tap(find.text('Select Date'));
    await tester.pumpAndSettle();

    // By default today is selected in showDatePicker. Tapping OK should return today.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(newValue, isNotNull);
    expect(newValue, matches(RegExp(r'\d{4}-\d{2}-\d{2}')));
  });

  testWidgets('DynamicDateField displays error when required and empty', (WidgetTester tester) async {
    final column = ColumnConfig(key: 'date', label: 'Order Date', type: 'date', isRequired: true);
    final formKey = GlobalKey<FormState>();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Form(
          key: formKey,
          child: DynamicDateField(
            column: column,
            value: null,
            primaryColor: Colors.blue,
            onChanged: (val) {},
          ),
        ),
      ),
    ));

    formKey.currentState!.validate();
    await tester.pump();

    expect(find.text('Date is required'), findsOneWidget);
  });
}
