import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:drivererpapp/screens/dashboard_screen.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/providers/theme_provider.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockDriveProvider extends Mock implements DriveProvider {}
class MockDriveService extends Mock implements DriveService {}
class MockWorkspaceProvider extends Mock implements WorkspaceProvider {}
class MockThemeProvider extends Mock implements ThemeProvider {}

void main() {
  late MockDriveProvider mockDriveProvider;
  late MockDriveService mockDriveService;
  late MockWorkspaceProvider mockWorkspaceProvider;
  late MockThemeProvider mockThemeProvider;
  late drive.File testWorkspace;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();
    mockWorkspaceProvider = MockWorkspaceProvider();
    mockThemeProvider = MockThemeProvider();
    
    testWorkspace = drive.File()..id = 'ws1'..name = 'Test Workspace';

    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockWorkspaceProvider.currentWorkspace).thenReturn(testWorkspace);
    when(() => mockThemeProvider.themeMode).thenReturn(ThemeMode.light);
    
    when(() => mockDriveService.listModules('ws1')).thenAnswer((_) async => [
      drive.File()..id = 'mod1'..name = 'CRM',
      drive.File()..id = 'mod2'..name = 'Inventory',
    ]);
    when(() => mockDriveService.getFileId(any(), any())).thenAnswer((_) async => 'f123');
    when(() => mockDriveService.getFileContent(any())).thenAnswer((_) async => '{}');
    when(() => mockDriveService.readModuleConfig(any())).thenAnswer((_) async => {});
    when(() => mockDriveService.getFileModifiedTime(any())).thenAnswer((_) async => DateTime.now());
  });
  
  Widget createDashboardScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: mockThemeProvider),
        ChangeNotifierProvider<SchemaProvider>(create: (_) => SchemaProvider(driveService: mockDriveService)),
      ],
      child: MaterialApp(
        home: const DashboardScreen(),
      ),
    );
  }

  testWidgets('DashboardScreen renders workspace name and KPIs', (WidgetTester tester) async {
    await tester.pumpWidget(createDashboardScreen());
    await tester.pump(); // Start FutureBuilder
    await tester.pump(const Duration(milliseconds: 100)); // Finish FutureBuilder

    expect(find.text('TEST WORKSPACE'), findsOneWidget); 
    expect(find.text('NET PROFIT ENGINE'), findsOneWidget); 
  });

  testWidgets('DashboardScreen displays modules from Drive', (WidgetTester tester) async {
    await tester.pumpWidget(createDashboardScreen());
    await tester.pumpAndSettle();

    expect(find.text('CRM'), findsAtLeastNWidgets(1));
    expect(find.text('Inventory'), findsAtLeastNWidgets(1));
  });

  testWidgets('DashboardScreen handles no modules gracefully', (WidgetTester tester) async {
    when(() => mockDriveService.listModules('ws1')).thenAnswer((_) async => []);
    
    await tester.pumpWidget(createDashboardScreen());
    await tester.pumpAndSettle();

    expect(find.textContaining('No modules installed'), findsOneWidget);
    expect(find.text('CRM'), findsOneWidget); 
  });

  testWidgets('DashboardScreen navigates to module on tap', (WidgetTester tester) async {
    await tester.pumpWidget(createDashboardScreen());
    await tester.pumpAndSettle();

    final moduleFinder = find.text('CRM').first;
    await tester.ensureVisible(moduleFinder);
    await tester.tap(moduleFinder);
    
    // Process navigation and loading
    for (int i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('CRM'), findsAtLeastNWidgets(1));
  });

  testWidgets('DashboardScreen navigates to marketplace module on tap', (WidgetTester tester) async {
    when(() => mockDriveService.listModules('ws1')).thenAnswer((_) async => []);

    await tester.pumpWidget(createDashboardScreen());
    await tester.pumpAndSettle();

    final marketplaceFinder = find.text('CRM').first;
    await tester.ensureVisible(marketplaceFinder);
    await tester.tap(marketplaceFinder);
    
    for (int i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('KEY BENEFITS'), findsOneWidget); 
  });
}
