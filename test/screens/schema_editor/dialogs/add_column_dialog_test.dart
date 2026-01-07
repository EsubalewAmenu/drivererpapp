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
    await tester.enterText(find.byType(TextField), 'Price');
    
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.label, 'Price');
    expect(result!.key, 'price');
    expect(result!.type, 'text'); // Default type
  });
}
