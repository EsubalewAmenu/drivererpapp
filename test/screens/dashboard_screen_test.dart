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
  });
  
  Widget createDashboardScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: mockThemeProvider),
      ],
      child: MaterialApp(
        home: const DashboardScreen(),
      ),
    );
  }

  testWidgets('DashboardScreen renders workspace name and KPIs', (WidgetTester tester) async {
    await tester.pumpWidget(createDashboardScreen());
    await tester.pumpAndSettle();

    expect(find.text('TEST WORKSPACE'), findsOneWidget); // Uppercased in UI
    expect(find.text('NET PROFIT ENGINE'), findsOneWidget); // "Overview" section is named this
  });

  testWidgets('DashboardScreen displays modules from Drive', (WidgetTester tester) async {
    await tester.pumpWidget(createDashboardScreen());
    await tester.pumpAndSettle();

    expect(find.text('CRM'), findsAtLeastNWidgets(1));
    expect(find.text('Inventory'), findsAtLeastNWidgets(1));
    expect(find.text('No modules installed.\nVisit the Marketplace to expand.'), findsNothing);
  });

  testWidgets('DashboardScreen handles no modules gracefully', (WidgetTester tester) async {
    when(() => mockDriveService.listModules('ws1')).thenAnswer((_) async => []);
    
    await tester.pumpWidget(createDashboardScreen());
    await tester.pumpAndSettle();

    // Should verify empty state in Core Modules
    expect(find.text('No modules installed.\nVisit the Marketplace to expand.'), findsOneWidget);
    
    // CRM should still be visible in Expansion Marketplace
    expect(find.text('CRM'), findsOneWidget); 
  });
}
