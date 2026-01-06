import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/dynamic_form/fields/date_field.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('DynamicDateField renders and picks date', (WidgetTester tester) async {
    String? changedValue;
    final column = ColumnConfig(
      key: 'test_date',
      label: 'Test Date',
      type: 'date',
    );

    // Initial value
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DynamicDateField(
            column: column,
            value: '2023-01-01',
            primaryColor: Colors.blue,
            onChanged: (val) => changedValue = val,
          ),
        ),
      ),
    );

    expect(find.text('TEST DATE'), findsOneWidget);
    expect(find.text('2023-01-01'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_today_rounded), findsOneWidget);

    // Open date picker
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    // Select a date (e.g., 15th)
    await tester.tap(find.text('15'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(changedValue, isNotNull);
    // The date format depends on what the picker returns, usually YYYY-MM-DD
    expect(changedValue, contains('-'));
  });
}
