import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/schema_editor/structure_editor.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('StructureEditor displays tabs and handles add/delete', (WidgetTester tester) async {
    final tabsItems = [
      TabConfig(id: 't1', label: 'Tab 1', columns: []),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            return StructureEditor(
              tabs: tabsItems,
              rawSettings: {},
              onTabsChanged: (newTabs) {
                setState(() {
                  tabsItems.clear();
                  tabsItems.addAll(newTabs);
                });
              },
            );
          },
        ),
      ),
    ));

    expect(find.text('Tab 1'), findsOneWidget);
    expect(find.text('Add New Tab'), findsOneWidget);

    // Test Delete
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    
    expect(find.text('Delete Tab'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(tabsItems.isEmpty, isTrue);

    // Test Add
    await tester.tap(find.text('Add New Tab'));
    await tester.pumpAndSettle();
    
    expect(find.text('Add New Tab'), findsWidgets);
    await tester.enterText(find.byType(TextField), 'New Tab');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(tabsItems.last.label, 'New Tab');

    // Test Edit
    await tester.tap(find.byIcon(Icons.edit_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('Edit Tab'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Updated Tab');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(tabsItems.first.label, 'Updated Tab');

    // Test Expand and Add Column
    await tester.tap(find.text('Updated Tab'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Column'));
    await tester.pumpAndSettle();
    expect(find.text('Add Column'), findsWidgets);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
}
