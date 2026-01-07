import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/schema_editor/dashboard_editor.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('DashboardEditor renders Cards', (WidgetTester tester) async {
    final cards = [
      DashboardCard(label: 'Sales', formula: 'SUM(sales)', format: 'currency'),
      DashboardCard(label: 'Inventory', formula: 'COUNT(items)', format: 'number'),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DashboardEditor(
          cards: cards,
          onAddCard: () {},
          onDeleteCard: (index) {},
          onEditCard: (index, card) {},
        ),
      ),
    ));

    expect(find.text('Sales'), findsOneWidget);
    expect(find.text('Inventory'), findsOneWidget);
    expect(find.text('SUM(sales)'), findsOneWidget);
    expect(find.text('Add Card'), findsOneWidget);
  });

  testWidgets('DashboardEditor calls callbacks', (WidgetTester tester) async {
    bool addCalled = false;
    int? deletedIndex;
    int? editedIndex;

    final cards = [
      DashboardCard(label: 'Sales', formula: 'SUM(sales)', format: 'currency'),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DashboardEditor(
          cards: cards,
          onAddCard: () {
            addCalled = true;
          },
          onDeleteCard: (index) {
            deletedIndex = index;
          },
          onEditCard: (index, card) {
            editedIndex = index;
          },
        ),
      ),
    ));

    await tester.scrollUntilVisible(find.text('Add Card'), 500);
    await tester.tap(find.text('Add Card'));
    expect(addCalled, isTrue);

    await tester.tap(find.byIcon(Icons.delete_outline));
    expect(deletedIndex, 0);

    await tester.tap(find.byIcon(Icons.edit_rounded));
    expect(editedIndex, 0);
  });
}
