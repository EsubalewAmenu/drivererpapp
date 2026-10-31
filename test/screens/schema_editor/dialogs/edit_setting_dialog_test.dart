import 'package:drivererpapp/models/schema_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/schema_editor/dialogs/edit_setting_dialog.dart';

void main() {
  testWidgets('EditSettingDialog handles adding new setting', (
    WidgetTester tester,
  ) async {
    Map<String, dynamic>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (context) =>
                      const EditSettingDialog(existingKeys: []),
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

    await tester.enterText(
      find.widgetWithText(TextField, 'Setting Key (ID)'),
      'test_key',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Label'),
      'Test Label',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!['key'], 'test_key');
  });

  testWidgets('EditSettingDialog handles editing existing setting', (
    WidgetTester tester,
  ) async {
    final existingSetting = SettingItem(
      label: 'Existing',
      type: 'text',
      value: 'val',
    );

    Map<String, dynamic>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (context) => EditSettingDialog(
                    settingKey: 'exist_key',
                    settingData: existingSetting.toJson(),
                    existingKeys: const ['exist_key', 'other'],
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

    expect(find.text('Edit Setting'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Label'),
      'Updated Label',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result!['data']['label'], 'Updated Label');
  });

  testWidgets('EditSettingDialog handles list type and options', (
    WidgetTester tester,
  ) async {
    Map<String, dynamic>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (context) =>
                      const EditSettingDialog(existingKeys: []),
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

    // Fill basic info
    await tester.enterText(
      find.widgetWithText(TextField, 'Setting Key (ID)'),
      'list_key',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Label'),
      'List Label',
    );

    // Select 'list' type
    await tester.tap(find.text('TEXT')); // Dropdown initial value
    await tester.pumpAndSettle();
    await tester.tap(find.text('LIST'));
    await tester.pumpAndSettle();

    expect(find.text('Options'), findsOneWidget);

    // Add option
    final addIcon = find.byIcon(Icons.add);
    await tester.ensureVisible(addIcon);
    await tester.tap(addIcon);
    await tester.pumpAndSettle();

    expect(find.text('Add Option'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Option 1');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Option 1'), findsOneWidget);

    // Remove option
    final removeIcon = find.byIcon(Icons.cancel).first;
    await tester.tap(removeIcon);
    await tester.pumpAndSettle();
    expect(find.text('Option 1'), findsNothing);

    // Add again and save
    await tester.tap(addIcon);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Option 2');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result!['data']['type'], 'list');
    expect(result!['data']['options'], contains('Option 2'));
  });

  testWidgets('EditSettingDialog validates existing keys', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) =>
                      const EditSettingDialog(existingKeys: ['duplicate_key']),
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

    await tester.enterText(
      find.widgetWithText(TextField, 'Setting Key (ID)'),
      'duplicate_key',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Label'),
      'Some Label',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Key already exists!'), findsOneWidget);
  });

  testWidgets('EditSettingDialog dependsOn and validation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) =>
                      const EditSettingDialog(existingKeys: []),
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

    // Check dependsOn
    await tester.enterText(
      find.widgetWithText(TextField, 'Depends On (Key)'),
      'parent_key',
    );

    // Test validation (empty label)
    await tester.enterText(
      find.widgetWithText(TextField, 'Setting Key (ID)'),
      'valid_key',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Add Setting'), findsOneWidget); // Dialog still open

    // Test cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Add Setting'), findsNothing);
  });
}
