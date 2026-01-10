import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/screens/schema_editor/dashboard_card_edit_screen.dart';
import 'package:drivererpapp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final module = ModuleSchema(
    id: 'test_mod',
    name: 'Test Module',
    icon: 'star',
    primaryColor: '#000000',
    version: '1.0',
    settings: {},
    dashboard: DashboardConfig(cards: []),
    tabs: [
      TabConfig(
        id: 'stocks',
        label: 'Stocks',
        columns: [
          ColumnConfig(key: 'name', label: 'Item Name', type: 'text'),
          ColumnConfig(key: 'qty', label: 'Quantity', type: 'number'),
          ColumnConfig(key: 'price', label: 'Price', type: 'currency'),
        ],
      ),
    ],
  );

  Widget createSubject(DashboardCard card) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: DashboardCardEditScreen(
        card: card,
        module: module,
        index: 0,
      ),
    );
  }

  testWidgets('DashboardCardEditScreen initializes in builder mode for known formulas', (WidgetTester tester) async {
    final card = DashboardCard(label: 'Total Qty', formula: '=SUM(stocks!B:B)', format: 'number');
    
    await tester.pumpWidget(createSubject(card));

    expect(find.text('Use Formula Builder'), findsOneWidget);
    // Switch should be on
    final switchWidget = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(switchWidget.value, isTrue);
    
    // Check specific fields populated
    expect(find.text('Stocks'), findsOneWidget); // Sheet dropdown
    expect(find.text('Quantity'), findsOneWidget); // Column dropdown (B is index 1 -> qty)
  });

  testWidgets('DashboardCardEditScreen builder generates correct formula', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final card = DashboardCard(label: 'New Card', formula: '', format: 'number');
    
    await tester.pumpWidget(createSubject(card));

    // Enable Builder Mode
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    // 1. Select Sheet -> Stocks
    final sheetDropdown = find.text('Select Sheet');
    await tester.ensureVisible(sheetDropdown);
    await tester.tap(sheetDropdown);
    await tester.pumpAndSettle();
    
    await tester.tap(find.text('Stocks').last); 
    await tester.pumpAndSettle();

    // 2. Select Field -> Price (Index 2 -> C)
    final fieldDropdown = find.text('Select Field');
    await tester.ensureVisible(fieldDropdown);
    await tester.tap(fieldDropdown);
    await tester.pumpAndSettle();
    
    final priceItem = find.text('Price').last;
    // ensureVisible doesn't work well on popped up menu items in test environment usually without scaffolding, 
    // but try standard tap
    await tester.tap(priceItem);
    await tester.pumpAndSettle();

    // 3. Select Operation -> Average
    final opDropdown = find.text('Select Operation');
    await tester.ensureVisible(opDropdown);
    await tester.tap(opDropdown);
    await tester.pumpAndSettle();
    
    await tester.tap(find.text('Average').last);
    await tester.pumpAndSettle();

    // Verify Generated Formula
    await tester.tap(find.text('GENERATED FORMULA')); // Focus something else to ensure text field commits?
    await tester.pumpAndSettle();
    
    expect(find.text('=AVERAGE(stocks!C:C)'), findsOneWidget);
  });
  
  testWidgets('DashboardCardEditScreen count_if shows input and generates correct formula', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final card = DashboardCard(label: 'Low Stock', formula: '', format: 'number');
    
    await tester.pumpWidget(createSubject(card));

    // Enable Builder Mode
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    // 1. Select Sheet -> Stocks
    final sheetDropdown = find.text('Select Sheet');
    await tester.ensureVisible(sheetDropdown);
    await tester.tap(sheetDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stocks').last);
    await tester.pumpAndSettle();

    // 2. Select Field -> Quantity
    final fieldDropdown = find.text('Select Field');
    await tester.ensureVisible(fieldDropdown);
    await tester.tap(fieldDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quantity').last); // B
    await tester.pumpAndSettle();

    // 3. Select Operation -> Count If...
    final opDropdown = find.text('Select Operation');
    await tester.ensureVisible(opDropdown);
    await tester.tap(opDropdown);
    await tester.pumpAndSettle();
    
    await tester.tap(find.text('Count If...').last);
    await tester.pumpAndSettle();
    
    // 4. Enter condition
    final conditionField = find.byType(TextField).last;
    await tester.ensureVisible(conditionField);
    await tester.enterText(conditionField, '<10');
    await tester.pump();

    // Verify Generated Formula
    // stocks!B:B -> Quantity is 2nd column (index 1) -> B
    // CountIf condition input might need to lose focus or pump
    await tester.tap(find.text('GENERATED FORMULA')); 
    await tester.pumpAndSettle();

    expect(find.text('=COUNTIF(stocks!B:B, "<10")'), findsOneWidget);
  });
}
