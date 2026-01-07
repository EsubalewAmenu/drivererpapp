import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/dynamic_form_screen.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/theme_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';

class MockDriveProvider extends Mock implements DriveProvider {}
class MockThemeProvider extends Mock implements ThemeProvider {}
class MockDriveService extends Mock implements DriveService {}

void main() {
  late MockDriveProvider mockDriveProvider;
  late MockThemeProvider mockThemeProvider;
  late MockDriveService mockDriveService;
  late TabConfig testTab;
  late ModuleSchema testModule;

  setUp(() {
    mockDriveProvider = MockDriveProvider();
    mockThemeProvider = MockThemeProvider();
    mockDriveService = MockDriveService();

    testTab = TabConfig(id: 't1', label: 'Inventory', columns: [
      ColumnConfig(key: 'item', label: 'Item Name', type: 'text', isRequired: true),
      ColumnConfig(key: 'qty', label: 'Quantity', type: 'number', defaultValue: '10'),
    ]);

    testModule = ModuleSchema(
      id: 'mod1', 
      name: 'Inventory', 
      icon: 'inventory', 
      primaryColor: '#0000FF', 
      version: '1.0.0', 
      tabs: [testTab], 
      settings: {}, 
      dashboard: DashboardConfig(kpiCards: [])
    );

    when(() => mockThemeProvider.themeMode).thenReturn(ThemeMode.light);
    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockDriveService.saveRecord(any(), any(), any(), any())).thenAnswer((_) async {});
  });

  Widget createFormScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: mockThemeProvider),
      ],
      child: MaterialApp(
        home: DynamicFormScreen(
          tab: testTab,
          primaryColor: Colors.blue,
          module: testModule,
        ),
      ),
    );
  }

  testWidgets('DynamicFormScreen renders default values', (WidgetTester tester) async {
    await tester.pumpWidget(createFormScreen());

    expect(find.text('NEW INVENTORY'), findsOneWidget);
    
    // Find fields by finding the label above them (UPPERCASE)
    expect(find.text('ITEM NAME'), findsOneWidget);
    expect(find.text('QUANTITY'), findsOneWidget);

    // Check default value '10' for Quantity
    expect(find.text('10'), findsOneWidget);
  });

  testWidgets('DynamicFormScreen validates required fields', (WidgetTester tester) async {
    await tester.pumpWidget(createFormScreen());

    // Tap Save without entering Item Name (required)
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    // Verify saveRecord was NOT called
    verifyNever(() => mockDriveService.saveRecord(any(), any(), any(), any()));
    
    // Should see validation error? 
    // The exact error text depends on the validator.
    expect(find.text('This field is required'), findsOneWidget);
  });

  testWidgets('DynamicFormScreen saves valid data', (WidgetTester tester) async {
    await tester.pumpWidget(createFormScreen());

    // Enter Item Name
    await tester.enterText(find.byType(TextFormField).at(0), 'Screwdriver');
    // Quantity already has '10', let's change it
    await tester.enterText(find.byType(TextFormField).at(1), '50');
    
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    verify(() => mockDriveService.saveRecord(
      'mod1', 
      'Inventory', 
      't1', 
      any(that: isA<Map<String, dynamic>>()
        .having((m) => m['item'], 'item', 'Screwdriver')
        .having((m) => m['qty'], 'qty', '50') 
        // Note: Check if number string is passed as string or parsed? 
        // Based on logic, it seems text fields put strings into map.
      ),
    )).called(1);
    
    // Should pop or show success? 
    // If pop happens, we might not see the screen anymore.
    // The previous test didn't check for pop, but verify is enough.
  });
}
