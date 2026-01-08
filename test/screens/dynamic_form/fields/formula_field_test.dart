import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/dynamic_form/fields/formula_field.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('DynamicFormulaField calculates multiplication', (WidgetTester tester) async {
    final column = ColumnConfig(
      key: 'total',
      label: 'Total Amount',
      type: 'formula',
      formula: 'qty * price',
    );
    
    final controllers = {
      'qty': TextEditingController(text: '10'),
      'price': TextEditingController(text: '15.5'),
    };
    
    String? calculatedValue;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DynamicFormulaField(
          column: column,
          controllers: controllers,
          onCalculated: (val) => calculatedValue = val,
        ),
      ),
    ));

    await tester.pumpAndSettle();

    // Initial calculation: 10 * 15.5 = 155.00
    expect(find.text('155.00'), findsOneWidget);
    expect(calculatedValue, '155.00');

    // Update qty
    controllers['qty']!.text = '20';
    await tester.pump(); // Listener should trigger
    await tester.pumpAndSettle(); // Process microtasks

    // New calculation: 20 * 15.5 = 310.00
    expect(find.text('310.00'), findsOneWidget);
    expect(calculatedValue, '310.00');
  });
}
