import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/module/common/tab_settings_screen.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  late TabConfig testTab;

  setUp(() {
    // Set a larger surface size to avoid scrolling issues in tests
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.implicitView!.physicalSize = const Size(1024, 2048);
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

  testWidgets('TabSettingsScreen handles Detail Field Visibility', (WidgetTester tester) async {
    await tester.pumpWidget(createTabSettingsScreen(testTab));
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    final showAllSwitch = find.ancestor(of: find.text('Show All Fields'), matching: find.byType(SwitchListTile));
    await tester.tap(showAllSwitch);
    await tester.pumpAndSettle();
    
    expect(find.widgetWithText(CheckboxListTile, 'Name'), findsOneWidget);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Name'));
    await tester.pumpAndSettle();
    
    // Scroll down if needed
    await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -300));
    await tester.pumpAndSettle();
    
    expect(find.widgetWithText(CheckboxListTile, 'Age'), findsOneWidget);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Age'));
    await tester.pumpAndSettle();
  });

  testWidgets('TabSettingsScreen handles conditional logic in Detail tab', (WidgetTester tester) async {
    await tester.pumpWidget(createTabSettingsScreen(testTab));
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    final titleLogicSwitch = find.ancestor(of: find.text('Conditional Title'), matching: find.byType(SwitchListTile));
    await tester.tap(titleLogicSwitch);
    await tester.pumpAndSettle();
    expect(find.text('Condition (e.g. Is Individual?)'), findsOneWidget);

    final subtLogicSwitch = find.ancestor(of: find.text('Conditional Subtitle'), matching: find.byType(SwitchListTile));
    await tester.tap(subtLogicSwitch);
    await tester.pumpAndSettle();
    expect(find.text('Condition Column'), findsOneWidget);
  });

  testWidgets('TabSettingsScreen saves configuration with detail template logic', (WidgetTester tester) async {
    Map<String, dynamic>? resultData;
    
    await tester.pumpWidget(MaterialApp(
      home: TabSettingsScreen(
        tab: testTab,
        primaryColor: Colors.blue,
        onSave: (data) => resultData = data,
      ),
    ));

    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    // Scroll to see the title logic if needed
    await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -300));
    await tester.pumpAndSettle();

    // Toggle conditional title in details
    final titleLogicSwitch = find.ancestor(of: find.text('Conditional Title'), matching: find.byType(SwitchListTile)).last;
    await tester.tap(titleLogicSwitch);
    await tester.pumpAndSettle();

    // Select condition column
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    
    await tester.tap(find.text('Is Active').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(resultData, isNotNull);
    final detailConfig = resultData!['detailTemplate'] as DetailTemplateConfig;
    expect(detailConfig.titleLogic?.conditionKey, 'is_active');
  });

  testWidgets('TabSettingsScreen handles filter removal', (WidgetTester tester) async {
    Map<String, dynamic>? resultData;
    
    final tabWithFilter = TabConfig(
      id: 'tab1',
      label: 'Test Tab',
      columns: testTab.columns,
      quickFilters: [
        QuickFilter(key: 'q1', label: 'name contains abc', field: 'name', operator: 'contains', value: 'abc'),
      ],
    );

    await tester.pumpWidget(MaterialApp(
      home: TabSettingsScreen(
        tab: tabWithFilter,
        primaryColor: Colors.blue,
        onSave: (data) => resultData = data,
      ),
    ));

    expect(find.text('name contains abc'), findsNWidgets(2));

    // Remove the filter
    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(resultData, isNotNull);
    final filters = resultData!['filters'] as List<QuickFilter>;
    expect(filters, isEmpty);
  });

  testWidgets('TabSettingsScreen saves auto-load tables and list trailing logic', (tester) async {
    tester.view.physicalSize = const Size(1024, 2048);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    Map<String, dynamic>? resultData;
    
    await tester.pumpWidget(MaterialApp(
      home: TabSettingsScreen(
        tab: testTab,
        primaryColor: Colors.blue,
        onSave: (data) => resultData = data,
      ),
    ));

    // 1. Details tab: toggle Auto-load Tables
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    final autoLoadSwitch = find.ancestor(of: find.text('Auto-load Tables'), matching: find.byType(SwitchListTile));
    await tester.tap(autoLoadSwitch);
    await tester.pumpAndSettle();

    // 2. List tab: change template and set trailing logic
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Standard Card'));
    await tester.pumpAndSettle();

    final trailingLogicSwitch = find.ancestor(of: find.text('Conditional Trailing (Badge)'), matching: find.byType(SwitchListTile));
    await tester.ensureVisible(trailingLogicSwitch);
    await tester.tap(trailingLogicSwitch);
    await tester.pumpAndSettle();

    // Set condition for trailing - with title/subtitle logic off, it should be the 3rd dropdown (index 2)
    final dropdowns = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(dropdowns.at(2));
    await tester.tap(dropdowns.at(2));
    await tester.pumpAndSettle();
    
    await tester.tap(find.text('Is Active').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(resultData, isNotNull);
    expect(resultData!['load_sub_table_data_automatically'], isFalse); 
    
    final listConfig = resultData!['listTemplate'] as ListTemplateConfig;
    expect(listConfig.template, 'standard');
    expect(listConfig.trailingLogic?.conditionKey, 'is_active');
  });
}
