import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/schema_editor/dialogs/add_column_dialog.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('AddColumnDialog can add column', (WidgetTester tester) async {
    ColumnConfig? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<ColumnConfig>(
                  context: context,
                  builder: (context) => const AddColumnDialog(),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Add Column'), findsOneWidget);
    
    // Fill Name
    await tester.enterText(find.byType(TextField).first, 'Full Price');
    await tester.pump(); // Allow listener to run

    // Verify auto-filled key
    expect(find.text('full_price'), findsOneWidget);

    // Overwrite key
    await tester.enterText(find.byType(TextField).last, 'custom_price');
    
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.label, 'Full Price');
    expect(result!.key, 'custom_price');
    expect(result!.type, 'text'); // Default type
  });
}
