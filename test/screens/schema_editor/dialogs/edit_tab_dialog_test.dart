import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/schema_editor/dialogs/edit_tab_dialog.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('EditTabDialog can update tab label', (WidgetTester tester) async {
    final tab = TabConfig(id: 't1', label: 'Tab 1', columns: []);
    TabConfig? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<TabConfig>(
                  context: context,
                  builder: (context) => EditTabDialog(tab: tab),
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

    expect(find.text('Edit Tab'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Updated Tab');
    
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.label, 'Updated Tab');
  });
}
