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

  testWidgets('DynamicTextField validates numeric input', (WidgetTester tester) async {
    final column = ColumnConfig(
      key: 'test_numeric_validation',
      label: 'Numeric Label',
      type: 'number',
    );

    String inputValue = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Form(
                child: Builder(
                  builder: (innerContext) {
                    return Column(
                      children: [
                        DynamicTextField(
                          column: column,
                          value: inputValue,
                          primaryColor: Colors.blue,
                          onChanged: (val) {
                             setState(() {
                               inputValue = val;
                             });
                          },
                        ),
                        ElevatedButton(
                          onPressed: () {
                             Form.of(innerContext).validate();
                          }, 
                          child: const Text('Validate')
                        )
                      ],
                    );
                  }
                ),
              );
            }
          ),
        ),
      ),
    );

    // Enter invalid number
    await tester.enterText(find.byType(TextFormField), 'abc');
    await tester.tap(find.text('Validate'));
    await tester.pump();

    expect(find.text('Please enter a valid number'), findsOneWidget);

    // Enter valid number
    await tester.enterText(find.byType(TextFormField), '123');
    await tester.tap(find.text('Validate'));
    await tester.pump();

    expect(find.text('Please enter a valid number'), findsNothing);
  });

  testWidgets('DynamicTextField validates email input', (WidgetTester tester) async {
    final column = ColumnConfig(
      key: 'test_email',
      label: 'Email Label',
      type: 'email',
    );
    String inputValue = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Form(
                child: Builder(
                  builder: (innerContext) {
                    return Column(
                      children: [
                        DynamicTextField(
                          column: column,
                          value: inputValue,
                          primaryColor: Colors.blue,
                          onChanged: (val) {
                             setState(() {
                               inputValue = val;
                             });
                          },
                        ),
                        ElevatedButton(
                          onPressed: () {
                             Form.of(innerContext).validate();
                          }, 
                          child: const Text('Validate')
                        )
                      ],
                    );
                  }
                ),
              );
            }
          ),
        ),
      ),
    );

    // Initial state
    final textField = tester.widget<TextField>(find.descendant(
      of: find.byType(TextFormField),
      matching: find.byType(TextField),
    ));
    // Verify keyboard type
    expect(textField.keyboardType, TextInputType.emailAddress);

    // Enter invalid email
    await tester.enterText(find.byType(TextFormField), 'not-an-email');
    await tester.tap(find.text('Validate'));
    await tester.pump();

    expect(find.text('Please enter a valid email'), findsOneWidget);

     // Enter valid email
    await tester.enterText(find.byType(TextFormField), 'test@example.com');
    await tester.tap(find.text('Validate'));
    await tester.pump();

    expect(find.text('Please enter a valid email'), findsNothing);
  });

  testWidgets('DynamicTextField validates phone input', (WidgetTester tester) async {
    final column = ColumnConfig(
      key: 'test_phone_validation',
      label: 'Phone Label',
      type: 'phone',
    );

    String inputValue = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Form(
                child: Builder(
                  builder: (innerContext) {
                    return Column(
                      children: [
                        DynamicTextField(
                          column: column,
                          value: inputValue,
                          primaryColor: Colors.blue,
                          onChanged: (val) {
                             setState(() {
                               inputValue = val;
                             });
                          },
                        ),
                        ElevatedButton(
                          onPressed: () {
                             Form.of(innerContext).validate();
                          }, 
                          child: const Text('Validate')
                        )
                      ],
                    );
                  }
                ),
              );
            }
          ),
        ),
      ),
    );

    // Initial state
    final textField = tester.widget<TextField>(find.descendant(
      of: find.byType(TextFormField),
      matching: find.byType(TextField),
    ));
    // Verify keyboard type
    expect(textField.keyboardType, TextInputType.phone);

    // Enter invalid phone
    await tester.enterText(find.byType(TextFormField), 'abc');
    await tester.tap(find.text('Validate'));
    await tester.pump();

    expect(find.text('Please enter a valid phone number'), findsOneWidget);

     // Enter valid phone
    await tester.enterText(find.byType(TextFormField), '+1234567890');
    await tester.tap(find.text('Validate'));
    await tester.pump();

    expect(find.text('Please enter a valid phone number'), findsNothing);
  });

  testWidgets('DynamicTextField displays diverse currency symbols', (WidgetTester tester) async {
    // Default USD
    final usdColumn = ColumnConfig(key: 'usd', label: 'USD', type: 'currency');
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DynamicTextField(column: usdColumn, value: '', primaryColor: Colors.blue, onChanged: (_){}))));
    expect(find.text('\$ '), findsOneWidget);

    // Custom Euro
    final eurColumn = ColumnConfig(key: 'eur', label: 'EUR', type: 'currency', currencySymbol: '€');
     await tester.pumpWidget(MaterialApp(home: Scaffold(body: DynamicTextField(column: eurColumn, value: '', primaryColor: Colors.blue, onChanged: (_){}))));
    expect(find.text('€ '), findsOneWidget);

    // Custom ETB
    final etbColumn = ColumnConfig(key: 'etb', label: 'ETB', type: 'currency', currencySymbol: 'Br');
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DynamicTextField(column: etbColumn, value: '', primaryColor: Colors.blue, onChanged: (_){}))));
    expect(find.text('Br '), findsOneWidget);
  });
}
