import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/schema_editor/dialogs/edit_setting_dialog.dart';

void main() {
  testWidgets('EditSettingDialog can add new setting', (WidgetTester tester) async {
    Map<String, dynamic>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (context) => const EditSettingDialog(
                    existingKeys: [],
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

    expect(find.text('Add Setting'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Setting Key (ID)'), 'test_key');
    await tester.enterText(find.widgetWithText(TextField, 'Label'), 'Test Label');
    
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!['key'], 'test_key');
    expect(result!['data']['label'], 'Test Label');
  });
}
