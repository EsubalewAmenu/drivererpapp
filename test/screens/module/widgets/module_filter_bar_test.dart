import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/module/widgets/module_filter_bar.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('ModuleFilterBar displays search field and filter icon', (WidgetTester tester) async {
    final searchController = TextEditingController();
    final tab = TabConfig(id: 't1', label: 'Stocks', columns: []);
    
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ModuleFilterBar(
          tab: tab,
          primaryColor: Colors.blue,
          searchController: searchController,
          activeFilter: 'all',
          activeFilters: [],
          showFilters: true,
          onFilterChanged: (_) {},
          onOpenSettings: () {},
        ),
      ),
    ));

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search stocks...'), findsOneWidget);
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
  });

  testWidgets('ModuleFilterBar displays filter chips when enabled', (WidgetTester tester) async {
    final searchController = TextEditingController();
    final filters = [
      QuickFilter(key: 'f1', label: 'Low Stock', field: 'qty', operator: '<', value: '10'),
    ];
    final tab = TabConfig(id: 't1', label: 'Stocks', columns: []);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ModuleFilterBar(
          tab: tab,
          primaryColor: Colors.blue,
          searchController: searchController,
          activeFilter: 'all',
          activeFilters: filters,
          showFilters: true,
          onFilterChanged: (_) {},
          onOpenSettings: () {},
        ),
      ),
    ));

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Low Stock'), findsOneWidget);
  });

  testWidgets('ModuleFilterBar triggers onFilterChanged when a chip is tapped', (WidgetTester tester) async {
    String? selectedFilter;
    final searchController = TextEditingController();
    final filters = [
      QuickFilter(key: 'f1', label: 'Low Stock', field: 'qty', operator: '<', value: '10'),
    ];
    final tab = TabConfig(id: 't1', label: 'Stocks', columns: []);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ModuleFilterBar(
          tab: tab,
          primaryColor: Colors.blue,
          searchController: searchController,
          activeFilter: 'all',
          activeFilters: filters,
          showFilters: true,
          onFilterChanged: (key) => selectedFilter = key,
          onOpenSettings: () {},
        ),
      ),
    ));

    await tester.tap(find.text('Low Stock'));
    expect(selectedFilter, equals('f1'));

    await tester.tap(find.text('All'));
    expect(selectedFilter, equals('all'));
  });

  testWidgets('ModuleFilterBar triggers onOpenSettings when icon tapped', (WidgetTester tester) async {
    bool opened = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ModuleFilterBar(
          tab: TabConfig(id: 't1', label: 'T', columns: []),
          primaryColor: Colors.blue,
          searchController: TextEditingController(),
          activeFilter: 'all',
          activeFilters: [],
          showFilters: true,
          onFilterChanged: (_) {},
          onOpenSettings: () => opened = true,
        ),
      ),
    ));

    await tester.tap(find.byIcon(Icons.tune_rounded));
    expect(opened, isTrue);
  });
}
