import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/schema_editor/dashboard_editor.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('DashboardEditor renders KPIs', (WidgetTester tester) async {
    final kpis = [
      KpiCard(label: 'Sales', calculation: 'SUM(sales)', format: 'currency'),
      KpiCard(label: 'Inventory', calculation: 'COUNT(items)', format: 'number'),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DashboardEditor(
          kpis: kpis,
          onAddKpi: () {},
          onDeleteKpi: (index) {},
          onEditKpi: (index, kpi) {},
        ),
      ),
    ));

    expect(find.text('Sales'), findsOneWidget);
    expect(find.text('Inventory'), findsOneWidget);
    expect(find.text('SUM(sales)'), findsOneWidget);
    expect(find.text('Add KPI Card'), findsOneWidget);
  });

  testWidgets('DashboardEditor calls callbacks', (WidgetTester tester) async {
    bool addCalled = false;
    int? deletedIndex;
    int? editedIndex;

    final kpis = [
      KpiCard(label: 'Sales', calculation: 'SUM(sales)', format: 'currency'),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DashboardEditor(
          kpis: kpis,
          onAddKpi: () {
            addCalled = true;
          },
          onDeleteKpi: (index) {
            deletedIndex = index;
          },
          onEditKpi: (index, kpi) {
            editedIndex = index;
          },
        ),
      ),
    ));

    await tester.scrollUntilVisible(find.text('Add KPI Card'), 500);
    await tester.tap(find.text('Add KPI Card'));
    expect(addCalled, isTrue);

    await tester.tap(find.byIcon(Icons.delete_outline));
    expect(deletedIndex, 0);

    await tester.tap(find.byIcon(Icons.edit_rounded));
    expect(editedIndex, 0);
  });
}
