import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/schema_editor_screen.dart';
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

  setUp(() {
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();
    mockThemeProvider = MockThemeProvider();

    testModule = ModuleSchema(
      id: 'mod1',
      name: 'Test Module',
      icon: 'inventory',
      primaryColor: '#F59E0B',
      version: '1.0.0',
      settings: {},
      tabs: [
        TabConfig(id: 't1', label: 'Tab 1', columns: []),
      ],
      dashboard: DashboardConfig(kpiCards: []),
    );

    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockThemeProvider.themeMode).thenReturn(ThemeMode.light);
  });

  Widget createSchemaEditor() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: mockThemeProvider),
      ],
      child: MaterialApp(
        home: SchemaEditorScreen(module: testModule),
      ),
    );
  }

  testWidgets('SchemaEditorScreen renders all edit tabs', (WidgetTester tester) async {
    await tester.pumpWidget(createSchemaEditor());

    expect(find.text('STRUCTURE'), findsOneWidget);
    expect(find.text('DASHBOARD'), findsOneWidget);
    expect(find.text('SETTINGS'), findsOneWidget);
    
    // Tab 1 from schema should be visible in Structure tab
    expect(find.text('Tab 1'), findsOneWidget);
  });

  testWidgets('SchemaEditorScreen switches tabs', (WidgetTester tester) async {
    await tester.pumpWidget(createSchemaEditor());

    await tester.tap(find.text('DASHBOARD'));
    await tester.pumpAndSettle();
    
    // "Add KPI Card" button should be visible in Dashboard tab
    expect(find.text('Add KPI Card'), findsOneWidget);

    await tester.tap(find.text('SETTINGS'));
    await tester.pumpAndSettle();
    
    expect(find.text('No settings defined.'), findsOneWidget);
  });
}
