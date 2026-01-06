import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/dynamic_form/fields/text_field.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('DynamicTextField renders and validates', (WidgetTester tester) async {
    String? changedValue;
    final column = ColumnConfig(
      key: 'test_text',
      label: 'Test Label',
      type: 'text',
      isRequired: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            child: DynamicTextField(
              column: column,
              value: 'Initial',
              primaryColor: Colors.blue,
              onChanged: (val) => changedValue = val,
            ),
          ),
        ),
      ),
    );

    // Check initial render
    expect(find.text('TEST LABEL'), findsOneWidget);
    expect(find.text('Initial'), findsOneWidget);

    // Test text entry
    await tester.enterText(find.byType(TextFormField), 'New Value');
    expect(changedValue, 'New Value');

    // Test validation
    await tester.enterText(find.byType(TextFormField), '');
    // Trigger validation
    final form = tester.state(find.byType(Form)) as FormState;
    form.validate();
    await tester.pump();
    
    expect(find.text('This field is required'), findsOneWidget);
  });
  
  testWidgets('DynamicTextField supports numeric input', (WidgetTester tester) async {
      final column = ColumnConfig(
        key: 'test_number',
        label: 'Number Label',
        type: 'number',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicTextField(
              column: column,
              value: '',
              primaryColor: Colors.blue,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      
      final textField = tester.widget<TextField>(find.descendant(
        of: find.byType(TextFormField),
        matching: find.byType(TextField),
      ));
      expect(textField.keyboardType, TextInputType.number);
  });
}
