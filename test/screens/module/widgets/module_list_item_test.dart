import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/module/widgets/module_list_item.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  final testTab = TabConfig(
    id: 't1', 
    label: 'Stocks', 
    columns: [
      ColumnConfig(key: 'name', label: 'Item Name', type: 'text'),
      ColumnConfig(key: 'qty', label: 'Quantity', type: 'number'),
    ]
  );

  testWidgets('ModuleListItem renders high_density template by default', (WidgetTester tester) async {
    final item = {'name': 'Apple', 'qty': '50'};
    
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ModuleListItem(
          item: item,
          tab: testTab,
          primaryColor: Colors.blue,
          onTap: () {},
        ),
      ),
    ));

    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    // High density usually shows a small colored bar
    expect(find.byType(Container), findsAtLeastNWidgets(1));
  });

  testWidgets('ModuleListItem renders standard template when configured', (WidgetTester tester) async {
    final standardTab = testTab.copyWith(
      listTemplate: ListTemplateConfig(
        template: 'standard',
        titleKey: 'name',
        subtitleKey: 'qty',
      ),
    );
    final item = {'name': 'Banana', 'qty': '20'};

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ModuleListItem(
          item: item,
          tab: standardTab,
          primaryColor: Colors.blue,
          onTap: () {},
        ),
      ),
    ));

    expect(find.text('Banana'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
  });

  testWidgets('ModuleListItem handles conditional logic for titles', (WidgetTester tester) async {
    final logicTab = testTab.copyWith(
      listTemplate: ListTemplateConfig(
        template: 'high_density',
        titleLogic: ConditionalLogic(
          conditionKey: 'is_urgent',
          truthyKey: 'urgent_msg',
          falsyKey: 'name',
        ),
      ),
    );

    // Test Truthy
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ModuleListItem(
          item: {'name': 'Normal', 'is_urgent': true, 'urgent_msg': 'URGENT!'},
          tab: logicTab,
          primaryColor: Colors.red,
          onTap: () {},
        ),
      ),
    ));
    expect(find.text('URGENT!'), findsOneWidget);
    expect(find.text('Normal'), findsNothing);

    // Test Falsy (string "false")
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ModuleListItem(
          item: {'name': 'Normal', 'is_urgent': 'false', 'urgent_msg': 'URGENT!'},
          tab: logicTab,
          primaryColor: Colors.red,
          onTap: () {},
        ),
      ),
    ));
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('URGENT!'), findsNothing);
  });
}
