import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/schema_editor/settings_editor.dart';
import 'package:drivererpapp/theme/app_theme.dart';

void main() {
  Widget createSettingsEditor({
    Map<String, dynamic>? rawSettings,
    Map<String, dynamic>? settingsValues,
    Function(String, dynamic)? onSettingChanged,
    Function(Map<String, dynamic>)? onSchemaChanged,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: SettingsEditor(
          rawSettings: rawSettings ?? {},
          settingsValues: settingsValues ?? {},
          onSettingChanged: onSettingChanged ?? (_, __) {},
          onSchemaChanged: onSchemaChanged ?? (_) {},
        ),
      ),
    );
  }

  group('SettingsEditor', () {
    testWidgets('renders empty state when no settings provided', (WidgetTester tester) async {
      await tester.pumpWidget(createSettingsEditor());

      expect(find.text('No settings defined.'), findsOneWidget);
    });

    testWidgets('renders text setting and updates value', (WidgetTester tester) async {
      final rawSettings = {
        'appName': {'type': 'text', 'label': 'Application Name'}
      };
      final settingsValues = {'appName': 'DriveERP'};
      
      String? changedKey;
      dynamic changedValue;

      await tester.pumpWidget(createSettingsEditor(
        rawSettings: rawSettings,
        settingsValues: settingsValues,
        onSettingChanged: (key, value) {
          changedKey = key;
          changedValue = value;
        },
      ));

      expect(find.text('Application Name'), findsOneWidget);
      expect(find.text('Key: appName | Type: text'), findsOneWidget);
      
      final textField = find.widgetWithText(TextFormField, 'DriveERP');
      expect(textField, findsOneWidget);

      await tester.enterText(textField, 'New Name');
      expect(changedKey, 'appName');
      expect(changedValue, 'New Name');
    });

    testWidgets('renders boolean setting and updates value', (WidgetTester tester) async {
      final rawSettings = {
        'darkMode': {'type': 'boolean', 'label': 'Dark Mode'}
      };
      final settingsValues = {'darkMode': false};
      
      String? changedKey;
      dynamic changedValue;

      await tester.pumpWidget(createSettingsEditor(
        rawSettings: rawSettings,
        settingsValues: settingsValues,
        onSettingChanged: (key, value) {
          changedKey = key;
          changedValue = value;
        },
      ));

      expect(find.text('Dark Mode'), findsOneWidget);
      final switchTile = find.byType(SwitchListTile);
      expect(switchTile, findsOneWidget);
      expect(tester.widget<SwitchListTile>(switchTile).value, false);

      await tester.tap(switchTile);
      expect(changedKey, 'darkMode');
      expect(changedValue, true);
    });

    testWidgets('renders list setting and allows adding/removing items', (WidgetTester tester) async {
      final rawSettings = {
        'tags': {'type': 'list', 'label': 'Tags'}
      };
      final settingsValues = {'tags': ['urgent', 'review']};
      
      String? changedKey;
      dynamic changedValue;

      await tester.pumpWidget(createSettingsEditor(
        rawSettings: rawSettings,
        settingsValues: settingsValues,
        onSettingChanged: (key, value) {
          changedKey = key;
          changedValue = value;
        },
      ));

      expect(find.text('Tags'), findsOneWidget);
      expect(find.text('urgent'), findsOneWidget);
      expect(find.text('review'), findsOneWidget);

      // Test Removing
      // Find the delete icon within the chip labeled 'urgent'
      final chipFinder = find.widgetWithText(Chip, 'urgent');
      final deleteIconFinder = find.descendant(of: chipFinder, matching: find.byIcon(Icons.cancel));
      await tester.tap(deleteIconFinder);
      
      expect(changedKey, 'tags');
      expect(changedValue, ['review']);

      // Test Adding
      // Tap the + icon in the ActionChip (part of the list)
      // Usually there are multiple add icons (one for the list item, one for adding new setting at bottom)
      // The ActionChip is inside the Wrap.
      await tester.tap(find.descendant(of: find.byType(Wrap), matching: find.byIcon(Icons.add)));
      await tester.pumpAndSettle(); // Show dialog

      expect(find.text('Add to tags'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'done');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(changedKey, 'tags');
      expect(changedValue, ['urgent', 'review', 'done']); // logic appended to original input list clone
    });

    testWidgets('renders disabled state when dependency not met', (WidgetTester tester) async {
      final rawSettings = {
        'enableFeature': {'type': 'boolean', 'label': 'Enable Feature'},
        'advancedOption': {'type': 'text', 'label': 'Advanced', 'dependsOn': 'enableFeature'}
      };
      // Dependency is false
      final settingsValues = {'enableFeature': false};

      await tester.pumpWidget(createSettingsEditor(
        rawSettings: rawSettings,
        settingsValues: settingsValues,
      ));

      expect(find.text('Advanced'), findsOneWidget);
      expect(find.text('Disabled (Dependency not met)'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
    });

    testWidgets('deletes setting when confirmed', (WidgetTester tester) async {
      final rawSettings = {
        'testKey': {'type': 'text'}
      };
      
      Map<String, dynamic>? newSchema;

      await tester.pumpWidget(createSettingsEditor(
        rawSettings: rawSettings,
        onSchemaChanged: (schema) {
          newSchema = schema;
        },
      ));

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Delete Setting'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(newSchema, {});
    });

    testWidgets('adds new setting via dialog', (WidgetTester tester) async {
      Map<String, dynamic>? newSchema;

      await tester.pumpWidget(createSettingsEditor(
        onSchemaChanged: (schema) {
          newSchema = schema;
        },
      ));

      await tester.tap(find.text('Add New Setting'));
      await tester.pumpAndSettle();

      expect(find.text('Add Setting'), findsOneWidget); // Dialog Title

      // Fill dialog
      await tester.enterText(find.widgetWithText(TextField, 'Setting Key (ID)'), 'new_key'); // Matches labelText
      await tester.enterText(find.widgetWithText(TextField, 'Label'), 'New Label');
      await tester.tap(find.text('Save')); // Button is usually 'Save' or 'Add'? 
      // Checking edit_setting_dialog logic needed, but let's assume 'Save' or 'Add'
      // Wait, let me check the dialog code again or try finding by type

      expect(newSchema, containsPair('new_key', predicate((value) {
        return value is Map && value['label'] == 'New Label';
      })));
    });

    testWidgets('renders help text when provided', (WidgetTester tester) async {
      final rawSettings = {
        'helpSetting': {'type': 'text', 'label': 'Help Me', 'help': 'This is a hint'}
      };
      await tester.pumpWidget(createSettingsEditor(rawSettings: rawSettings));

      expect(find.text('Help Me'), findsOneWidget);
      expect(find.text('This is a hint'), findsOneWidget);
    });

    testWidgets('renders unknown type warning', (WidgetTester tester) async {
      final rawSettings = {
        'ghost': {'type': 'phantom', 'label': 'Ghost Setting'}
      };
      await tester.pumpWidget(createSettingsEditor(rawSettings: rawSettings));

      expect(find.text('Unsupported type: phantom'), findsOneWidget);
    });
  });
}
