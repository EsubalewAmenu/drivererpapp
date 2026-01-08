import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/module/module_tab_screen.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/providers/theme_provider.dart';

class MockDriveProvider extends Mock implements DriveProvider {}
class MockDriveService extends Mock implements DriveService {}
class MockThemeProvider extends Mock implements ThemeProvider {}

void main() {
  late MockDriveProvider mockDriveProvider;
  late MockDriveService mockDriveService;
  late MockThemeProvider mockThemeProvider;
  late ModuleSchema testModule;
  late TabConfig testTab;

  setUp(() {
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();
    mockThemeProvider = MockThemeProvider();

    testTab = TabConfig(id: 't1', label: 'Tab 1', columns: [
      ColumnConfig(key: 'name', label: 'Name', type: 'text'),
    ]);

    testModule = ModuleSchema(
      id: 'mod1',
      name: 'Test Module',
      icon: 'inventory',
      primaryColor: '#F59E0B',
      version: '1.0.0',
      settings: {},
      tabs: [testTab],
      dashboard: DashboardConfig(cards: []),
    );

    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockThemeProvider.themeMode).thenReturn(ThemeMode.light);
    when(() => mockDriveService.fetchRecords('mod1', 'Test Module', 't1')).thenAnswer((_) async => [
      {'name': 'Record 1'},
      {'name': 'Record 2'},
    ]);
  });

  Widget createModuleTabScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: mockThemeProvider),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ModuleTabScreen(
            tab: testTab,
            primaryColor: Colors.blue,
            module: testModule,
          ),
        ),
      ),
    );
  }

  testWidgets('ModuleTabScreen loads and displays records', (WidgetTester tester) async {
    await tester.pumpWidget(createModuleTabScreen());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    
    await tester.pumpAndSettle();

    expect(find.text('Record 1'), findsOneWidget);
    expect(find.text('Record 2'), findsOneWidget);
  });

  testWidgets('ModuleTabScreen search filters records', (WidgetTester tester) async {
    await tester.pumpWidget(createModuleTabScreen());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Record 1');
    await tester.pump(); // No need for settle, it's just search

    // One in the TextField, one in the list tile
    expect(find.text('Record 1'), findsNWidgets(2));
    expect(find.text('Record 2'), findsNothing);
  });
}
