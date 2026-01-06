import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/dynamic_form/fields/boolean_field.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('DynamicBooleanField renders and toggles', (WidgetTester tester) async {
    bool? changedValue;
    final column = ColumnConfig(
      key: 'test_bool',
      label: 'Test Boolean',
      type: 'boolean',
    );

    // Test with initial value true
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DynamicBooleanField(
            column: column,
            value: true,
            primaryColor: Colors.blue,
            onChanged: (val) => changedValue = val,
          ),
        ),
      ),
    );

    expect(find.text('Test Boolean'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    
    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    expect(switchWidget.value, true);

    // Toggle switch
    await tester.tap(find.byType(Switch));
    expect(changedValue, false);
  });
}
