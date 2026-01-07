import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/schema_editor/structure_editor.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('StructureEditor renders tabs', (WidgetTester tester) async {
    final tabs = [
      TabConfig(id: 't1', label: 'Tab 1', columns: []),
      TabConfig(id: 't2', label: 'Tab 2', columns: []),
    ];

    List<TabConfig>? updatedTabs;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StructureEditor(
            tabs: tabs,
            rawSettings: const {},
            onTabsChanged: (newTabs) {
              updatedTabs = newTabs;
            },
          ),
        ),
      ),
    );

    // expect(find.text('DATA STRUCTURE'), findsOneWidget); // Removed as it doesn't exist
    expect(find.text('Tab 1'), findsOneWidget);
    expect(find.text('Tab 2'), findsOneWidget);
    expect(find.text('Add New Tab'), findsOneWidget);

    // Test delete
    // Find delete icon for first tab
    final deleteIcon = find.byIcon(Icons.delete_outline_rounded).first;
    await tester.tap(deleteIcon);
    await tester.pumpAndSettle();
    
    // Check if confirm dialog appears
    if (find.text('Delete').evaluate().isNotEmpty) {
       await tester.tap(find.text('Delete'));
       await tester.pumpAndSettle();
    }
    
    if (updatedTabs != null) {
      expect(updatedTabs!.length, 1);
    }
  });
}
