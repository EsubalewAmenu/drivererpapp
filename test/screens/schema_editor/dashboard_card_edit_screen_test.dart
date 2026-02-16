import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/screens/schema_editor/dashboard_card_edit_screen.dart';
import 'package:drivererpapp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;

class MockDriveProvider extends Mock implements DriveProvider {}
class MockDriveService extends Mock implements DriveService {}
class MockSheetsApi extends Mock implements sheets.SheetsApi {}
class MockSpreadsheetsResource extends Mock implements sheets.SpreadsheetsResource {}
class MockSpreadsheetsValuesResource extends Mock implements sheets.SpreadsheetsValuesResource {}

void main() {
  late MockDriveProvider mockDriveProvider;
  late MockDriveService mockDriveService;
  late MockSheetsApi mockSheetsApi;
  late MockSpreadsheetsResource mockSpreadsheets;
  late MockSpreadsheetsValuesResource mockValues;

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
        fileId: 'stocks_sheet_id',
      ),
    ],
  );

  setUp(() {
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();
    mockSheetsApi = MockSheetsApi();
    mockSpreadsheets = MockSpreadsheetsResource();
    mockValues = MockSpreadsheetsValuesResource();

    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockDriveService.sheetsApi).thenReturn(mockSheetsApi);
    when(() => mockSheetsApi.spreadsheets).thenReturn(mockSpreadsheets);
    when(() => mockSpreadsheets.values).thenReturn(mockValues);

    when(() => mockSpreadsheets.get(any())).thenAnswer((_) async =>
        sheets.Spreadsheet(sheets: [
          sheets.Sheet(properties: sheets.SheetProperties(title: 'stocks', sheetId: 0)),
        ]));

    when(() => mockValues.get(any(), any())).thenAnswer((_) async =>
        sheets.ValueRange(values: [[
          'Item Name',
          'Quantity',
          'Price',
        ]]));
  });

  Widget createSubject(DashboardCard card) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ],
        child: DashboardCardEditScreen(
          card: card,
          module: module,
          index: 0,
        ),
      ),
    );
  }

  testWidgets('DashboardCardEditScreen initializes in builder mode for known formulas', (WidgetTester tester) async {
    final card = DashboardCard(
      label: 'Total Qty',
      formula: '=SUM(Test Module:stocks:stocks!B:B)',
      format: 'number',
    );
    
    await tester.pumpWidget(createSubject(card));
    await tester.pumpAndSettle();

    expect(find.text('Use Formula Builder'), findsOneWidget);
    // Switch should be on
    final switchWidget = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(switchWidget.value, isTrue);
    
    // Check specific fields populated
    expect(find.text('Stocks'), findsOneWidget); // Tab dropdown
    // Column dropdown should include Quantity
    final columnDropdown = find.byType(DropdownButton<String>).at(2);
    await tester.tap(columnDropdown, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Quantity'), findsWidgets);
    await tester.tap(find.text('Quantity').last, warnIfMissed: false);
    await tester.pumpAndSettle();
  });

  testWidgets('DashboardCardEditScreen builder generates correct formula', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final card = DashboardCard(label: 'New Card', formula: '', format: 'number');
    
    await tester.pumpWidget(createSubject(card));

    // Builder mode is enabled by default

    // 1. Select Tab -> Stocks
    final tabDropdown = find.byType(DropdownButton<String>).at(0);
    await tester.tap(tabDropdown, warnIfMissed: false);
    await tester.pumpAndSettle();
    
    await tester.tap(find.text('Stocks').last, warnIfMissed: false); 
    await tester.pumpAndSettle();

    // 2. Select Sheet -> stocks
    final sheetDropdown = find.byType(DropdownButton<String>).at(1);
    await tester.tap(sheetDropdown, warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.tap(find.text('stocks').last, warnIfMissed: false);
    await tester.pumpAndSettle();

    // 3. Select Column -> Price (Index 2 -> C)
    final fieldDropdown = find.byType(DropdownButton<String>).at(2);
    await tester.tap(fieldDropdown, warnIfMissed: false);
    await tester.pumpAndSettle();
    
    final priceItem = find.text('Price').last;
    // ensureVisible doesn't work well on popped up menu items in test environment usually without scaffolding, 
    // but try standard tap
    await tester.tap(priceItem, warnIfMissed: false);
    await tester.pumpAndSettle();

    // 3. Select Operation -> Average
    final opDropdown = find.byType(DropdownButton<String>).at(3);
    await tester.tap(opDropdown, warnIfMissed: false);
    await tester.pumpAndSettle();
    
    await tester.tap(find.text('Average').last, warnIfMissed: false);
    await tester.pumpAndSettle();

    // Verify Generated Formula
    await tester.tap(find.text('FORMULA PREVIEW'), warnIfMissed: false);
    await tester.pumpAndSettle();
    
    expect(find.text('=AVERAGE(Test Module:stocks:stocks!C:C)'), findsOneWidget);
  });
  
  testWidgets('DashboardCardEditScreen count_if shows input and generates correct formula', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final card = DashboardCard(label: 'Low Stock', formula: '', format: 'number');
    
    await tester.pumpWidget(createSubject(card));

    // Builder mode is enabled by default

    // 1. Select Tab -> Stocks
    final tabDropdown = find.byType(DropdownButton<String>).at(0);
    await tester.tap(tabDropdown, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stocks').last);
    await tester.pumpAndSettle();

    // 2. Select Sheet -> stocks
    final sheetDropdown = find.byType(DropdownButton<String>).at(1);
    await tester.tap(sheetDropdown, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('stocks').last);
    await tester.pumpAndSettle();

    // 3. Select Column -> Quantity
    final fieldDropdown = find.byType(DropdownButton<String>).at(2);
    await tester.tap(fieldDropdown, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quantity').last); // B
    await tester.pumpAndSettle();

    // 3. Select Operation -> Count If...
    final opDropdown = find.byType(DropdownButton<String>).at(3);
    await tester.tap(opDropdown, warnIfMissed: false);
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
    await tester.tap(find.text('FORMULA PREVIEW'));
    await tester.pumpAndSettle();

    expect(find.textContaining('=COUNTIF(Test Module:stocks:stocks!B:B'), findsOneWidget);
  });

  testWidgets('DashboardCardEditScreen supports text format without crashing', (WidgetTester tester) async {
    final card = DashboardCard(label: 'Comparison', formula: '=CHART(sheet!A:B)', format: 'text', type: 'list');
    await tester.pumpWidget(createSubject(card));
    
    // Expect "TEXT" to be visible (uppercase in dropdown)
    expect(find.text('TEXT'), findsOneWidget);
  });
}
