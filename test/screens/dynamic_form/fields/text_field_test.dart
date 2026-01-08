import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/dynamic_form/fields/text_field.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('DynamicTextField handles text input', (WidgetTester tester) async {
    final column = ColumnConfig(key: 'name', label: 'Name', type: 'text');
    String? newValue;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DynamicTextField(
          column: column,
          value: 'Old',
          primaryColor: Colors.blue,
          onChanged: (val) => newValue = val,
        ),
      ),
    ));

    expect(find.text('NAME'), findsOneWidget);
    expect(find.text('Old'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'New');
    expect(newValue, 'New');
  });

  testWidgets('DynamicTextField validation', (WidgetTester tester) async {
    final column = ColumnConfig(key: 'email', label: 'Email', type: 'email', isRequired: true);
    final formKey = GlobalKey<FormState>();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Form(
          key: formKey,
          child: DynamicTextField(
            column: column,
            value: '',
            primaryColor: Colors.blue,
            onChanged: (val) {},
          ),
        ),
      ),
    ));

    formKey.currentState!.validate();
    await tester.pump();
    expect(find.text('This field is required'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'invalid-email');
    formKey.currentState!.validate();
    await tester.pump();
    expect(find.text('Please enter a valid email'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'test@example.com');
    formKey.currentState!.validate();
    await tester.pump();
    expect(find.text('Please enter a valid email'), findsNothing);
  });
}
