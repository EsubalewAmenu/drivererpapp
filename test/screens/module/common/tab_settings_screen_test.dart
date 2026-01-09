import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/module/common/tab_settings_screen.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  late TabConfig testTab;

  setUp(() {
    // Set a larger surface size to avoid scrolling issues in tests
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.implicitView!.physicalSize = const Size(1024, 1024);
    binding.platformDispatcher.implicitView!.devicePixelRatio = 1.0;

    testTab = TabConfig(
      id: 't1',
      label: 'Test Tab',
      columns: [
        ColumnConfig(key: 'name', label: 'Name', type: 'text'),
        ColumnConfig(key: 'age', label: 'Age', type: 'number'),
        ColumnConfig(key: 'is_active', label: 'Is Active', type: 'boolean'),
      ],
      quickFilters: [
        QuickFilter(label: 'Active Only', key: 'active', field: 'is_active', operator: '==', value: true),
      ],
      enableCustomFilters: true,
      listTemplate: ListTemplateConfig(
        template: 'high_density',
        titleKey: 'name',
      ),
    );
  });

  Widget createTabSettingsScreen(TabConfig tab) {
    return MaterialApp(
      home: TabSettingsScreen(
        tab: tab,
        primaryColor: Colors.blue,
      ),
    );
  }

  testWidgets('TabSettingsScreen initializes with correct data', (WidgetTester tester) async {
    await tester.pumpWidget(createTabSettingsScreen(testTab));
    
    expect(find.text('Test Tab Settings'), findsOneWidget);
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('List'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    
    // Check initial filter
    expect(find.text('Active Only'), findsOneWidget);
    expect(find.text('is_active == true'), findsOneWidget);
  });

  testWidgets('TabSettingsScreen can toggle filters enabled', (WidgetTester tester) async {
    await tester.pumpWidget(createTabSettingsScreen(testTab));
    
    final switchFinder = find.byType(SwitchListTile).first;
    expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
    
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    
    expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);
    expect(find.text('Filters are disabled for this tab.'), findsOneWidget);
  });

  testWidgets('TabSettingsScreen can switch tabs and update Display template', (WidgetTester tester) async {
    await tester.pumpWidget(createTabSettingsScreen(testTab));
    
    // Switch to List tab
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();
    
    expect(find.text('CHOOSE TEMPLATE'), findsOneWidget);
    expect(find.text('High Density'), findsOneWidget);
    
    // Change to Standard Card
    await tester.tap(find.text('Standard Card'));
    await tester.pumpAndSettle();
    
    // Verify standard card features appear (e.g., EXTRA DETAILS section)
    expect(find.text('EXTRA DETAILS'), findsOneWidget);
  });

  testWidgets('TabSettingsScreen handles conditional logic toggles in List tab', (WidgetTester tester) async {
    await tester.pumpWidget(createTabSettingsScreen(testTab));
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();

    final titleLogicSwitch = find.ancestor(
      of: find.text('Conditional Title'),
      matching: find.byType(SwitchListTile),
    );
    
    await tester.tap(titleLogicSwitch);
    await tester.pumpAndSettle();
    
    expect(find.text('Condition (e.g. Is Individual?)'), findsOneWidget);
    expect(find.text('If True'), findsOneWidget);
    expect(find.text('If False'), findsOneWidget);
  });

  testWidgets('TabSettingsScreen handles Detail Layout and visibility', (WidgetTester tester) async {
    await tester.pumpWidget(createTabSettingsScreen(testTab));
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    expect(find.text('CHOOSE LAYOUT'), findsOneWidget);
    expect(find.text('Show All Fields'), findsOneWidget);
    
    final showAllSwitch = find.ancestor(
      of: find.text('Show All Fields'),
      matching: find.byType(SwitchListTile),
    );
    
    await tester.tap(showAllSwitch);
    await tester.pumpAndSettle();
    
    // Now checkboxes for fields should be visible
    expect(find.widgetWithText(CheckboxListTile, 'Name'), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, 'Age'), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, 'Is Active'), findsOneWidget);
  });

  testWidgets('TabSettingsScreen returns updated config on Save', (WidgetTester tester) async {
    Map<String, dynamic>? resultData;
    
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            resultData = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => TabSettingsScreen(tab: testTab, primaryColor: Colors.blue)),
            );
          },
          child: const Text('Open'),
        ),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Disable filters
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    // Tap Save
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(resultData, isNotNull);
    expect(resultData!['enableFilters'], isFalse);
  });

  testWidgets('TabSettingsScreen can remove a filter', (WidgetTester tester) async {
    await tester.pumpWidget(createTabSettingsScreen(testTab));
    
    expect(find.text('Active Only'), findsOneWidget);
    
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    
    expect(find.text('No custom filters added yet.'), findsOneWidget);
  });

  testWidgets('TabSettingsScreen can update Display templage and mapping', (WidgetTester tester) async {
    await tester.pumpWidget(createTabSettingsScreen(testTab));
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();

    // Mapping title to age
    await tester.tap(find.text('Name')); // Title dropdown
    await tester.pumpAndSettle();
    await tester.tap(find.text('Age').last);
    await tester.pumpAndSettle();

    // Verify it changed
    expect(find.text('Age'), findsWidgets);
  });

  testWidgets('TabSettingsScreen can toggle Subtitle logic', (WidgetTester tester) async {
    await tester.pumpWidget(createTabSettingsScreen(testTab));
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();

    final subtitleLogicSwitch = find.ancestor(
      of: find.text('Conditional Subtitle'),
      matching: find.byType(SwitchListTile),
    );
    
    await tester.tap(subtitleLogicSwitch);
    await tester.pumpAndSettle();
    
    expect(find.text('Condition'), findsWidgets);
  });

  testWidgets('TabSettingsScreen can toggle Trailing logic in Standard template', (WidgetTester tester) async {
    await tester.pumpWidget(createTabSettingsScreen(testTab));
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();

    // Change to Standard Card first
    await tester.tap(find.text('Standard Card'));
    await tester.pumpAndSettle();

    final trailingLogicSwitch = find.ancestor(
      of: find.text('Conditional Trailing (Badge)'),
      matching: find.byType(SwitchListTile),
    );
    
    await tester.tap(trailingLogicSwitch);
    await tester.pumpAndSettle();
    
    expect(find.text('Condition'), findsWidgets);
  });

  testWidgets('TabSettingsScreen can switch Detail Layout to Modern Visual', (WidgetTester tester) async {
    await tester.pumpWidget(createTabSettingsScreen(testTab));
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    expect(find.text('Classic centered header with rounded borders'), findsOneWidget);
    
    await tester.tap(find.text('Modern Visual'));
    await tester.pumpAndSettle();
    
    expect(find.text('Full-width image header with integrated titles'), findsOneWidget);
  });
}
