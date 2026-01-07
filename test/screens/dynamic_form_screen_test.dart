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

void main() {
  late MockDriveProvider mockDriveProvider;
  late MockThemeProvider mockThemeProvider;
  late TabConfig testTab;

  setUp(() {
    mockDriveProvider = MockDriveProvider();
    mockThemeProvider = MockThemeProvider();

    testTab = TabConfig(id: 't1', label: 'Inventory', columns: [
      ColumnConfig(key: 'item', label: 'Item Name', type: 'text'),
      ColumnConfig(key: 'qty', label: 'Quantity', type: 'number'),
    ]);

    when(() => mockThemeProvider.themeMode).thenReturn(ThemeMode.light);
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
          module: ModuleSchema(
            id: 'mod1', 
            name: 'Inventory', 
            icon: 'inventory', 
            primaryColor: '#0000FF', 
            version: '1.0.0', 
            tabs: [testTab], 
            settings: {}, 
            dashboard: DashboardConfig(kpiCards: [])
          ),
        ),
      ),
    );
  }

  testWidgets('DynamicFormScreen renders and saves', (WidgetTester tester) async {
    final mockDriveService = MockDriveService();
    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockDriveService.saveRecord(any(), any(), any(), any())).thenAnswer((_) async => {});

    await tester.pumpWidget(createFormScreen());

    expect(find.text('NEW INVENTORY'), findsOneWidget);
    
    // Find fields by finding the label above them
    expect(find.text('ITEM NAME'), findsOneWidget);
    expect(find.text('QUANTITY'), findsOneWidget);

    // Enter text into text fields.
    await tester.enterText(find.byType(TextFormField).at(0), 'Screwdriver');
    await tester.enterText(find.byType(TextFormField).at(1), '50');
    
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    verify(() => mockDriveService.saveRecord('mod1', 'Inventory', 't1', any())).called(1);
  });
}

class MockDriveService extends Mock implements DriveService {}
