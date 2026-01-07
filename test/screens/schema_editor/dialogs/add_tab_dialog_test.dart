import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/schema_editor/dialogs/add_tab_dialog.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('AddTabDialog can add new tab', (WidgetTester tester) async {
    TabConfig? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<TabConfig>(
                  context: context,
                  builder: (context) => const AddTabDialog(),
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

    expect(find.text('Add New Tab'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Customers');
    
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.label, 'Customers');
    expect(result!.id, 'customers');
  });
}
