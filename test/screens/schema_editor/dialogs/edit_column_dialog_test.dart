import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/schema_editor/dialogs/edit_column_dialog.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('EditColumnDialog renders correctly and can save', (WidgetTester tester) async {
    final column = ColumnConfig(key: 'col1', label: 'Column 1', type: 'text');
    final tab = TabConfig(id: 't1', label: 'Tab 1', columns: [column]);
    
    ColumnConfig? updatedColumn;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                updatedColumn = await showDialog<ColumnConfig>(
                  context: context,
                  builder: (context) => EditColumnDialog(
                    column: column,
                    tab: tab,
                  ),
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

    expect(find.text('Edit Column'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Column 1'), findsOneWidget);

    // Change label
    await tester.enterText(find.widgetWithText(TextField, 'Column 1'), 'Updated Label');
    
    // Tap Save
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(updatedColumn, isNotNull);
    expect(updatedColumn!.label, 'Updated Label');
  });
}
