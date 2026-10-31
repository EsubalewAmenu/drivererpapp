import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/dynamic_form/fields/boolean_field.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('DynamicBooleanField toggles value', (WidgetTester tester) async {
    final column = FieldDefinition(
      key: 'active',
      label: 'Is Active',
      type: 'boolean',
    );
    bool? newValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DynamicBooleanField(
            column: column,
            value: false,
            primaryColor: Colors.blue,
            onChanged: (val) => newValue = val,
          ),
        ),
      ),
    );

    expect(find.text('Is Active'), findsOneWidget);
    final switchFinder = find.byType(Switch);

    await tester.tap(switchFinder);
    await tester.pump();

    expect(newValue, isTrue);
  });
}
