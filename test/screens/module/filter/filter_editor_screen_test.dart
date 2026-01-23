import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/module/filter/filter_editor_screen.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('FilterEditorScreen saves QuickFilter with auto-label', (tester) async {
    final columns = [ColumnConfig(key: 'name', label: 'Name', type: 'text')];

    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return ElevatedButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => FilterEditorScreen(columns: columns),
          ));
          // Push the result into a text widget so the test can assert after pop
          if (result != null) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(body: Text((result as QuickFilter).label))));
          }
        },
        child: const Text('Open'),
      );
    })));

    // Open the editor
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Enter a value and save
    await tester.enterText(find.byType(TextField).at(1), 'Alice');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // After save the auto-generated label should be visible
    expect(find.textContaining('Name'), findsOneWidget);
  });
}
