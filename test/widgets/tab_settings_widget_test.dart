import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/screens/module/common/tab_settings_screen.dart';

void main() {
  testWidgets('TabSettingsScreen shows FAB and toggles work and Save calls onSave', (tester) async {
    final tab = TabConfig(
      id: 't1',
      label: 'Test',
      columns: [ColumnConfig(key: 'c1', label: 'Col1', type: 'text'), ColumnConfig(key: 'c2', label: 'Col2', type: 'text')],
      quickFilters: [],
      enableCustomFilters: true,
    );

    Map<String, dynamic>? saved;

    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        return Center(
          child: ElevatedButton(
            child: const Text('open'),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => TabSettingsScreen(tab: tab, primaryColor: Colors.blue, onSave: (m) => saved = m)));
            },
          ),
        );
      }),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Filters tab is selected by default and filters are enabled -> FAB present
    expect(find.byType(FloatingActionButton), findsOneWidget);

    // Toggle Conditional Title in List tab: switch to List tab
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();

    // Find Conditional Title switch and toggle
    final condTitle = find.widgetWithText(SwitchListTile, 'Conditional Title');
    expect(condTitle, findsOneWidget);
    await tester.tap(condTitle);
    await tester.pumpAndSettle();

    // Tap Save to invoke onSave
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!['enableFilters'], isA<bool>());
    expect(saved!.containsKey('listTemplate'), isTrue);
    expect(saved!.containsKey('detailTemplate'), isTrue);
  });
}
