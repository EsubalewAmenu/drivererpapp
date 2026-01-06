import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/dynamic_form/fields/formula_field.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('DynamicFormulaField calculates value', (WidgetTester tester) async {
    final controllers = {
      'qty': TextEditingController(text: '10'),
      'price': TextEditingController(text: '5.5'),
    };
    
    // Create column with formula "qty * price"
    final column = ColumnConfig(
      key: 'total',
      label: 'Total',
      type: 'formula',
      formula: 'qty * price',
    );

    String? calculatedValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DynamicFormulaField(
            column: column,
            controllers: controllers,
            onCalculated: (val) => calculatedValue = val,
          ),
        ),
      ),
    );

    // Initial render might happen before calculation callback or same frame.
    // The calculation happens in build but triggers onCalculated in postFrameCallback.
    await tester.pumpAndSettle();

    expect(find.text('TOTAL'), findsOneWidget);
    expect(find.text('55.00'), findsOneWidget); // 10 * 5.5
    expect(calculatedValue, '55.00');

    // Update controller
    controllers['qty']!.text = '2';
    // Trigger rebuild
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DynamicFormulaField(
            column: column,
            controllers: controllers,
            onCalculated: (val) => calculatedValue = val,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    
    expect(find.text('11.00'), findsOneWidget); // 2 * 5.5
    expect(calculatedValue, '11.00');
  });
}
