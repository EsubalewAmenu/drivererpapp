import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/widgets/app_drawer.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/theme_provider.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/screens/settings_screen.dart';
import 'package:drivererpapp/screens/landing_screen.dart';
import 'package:drivererpapp/screens/workspace_selector_screen.dart';
import 'package:drivererpapp/models/company_model.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class MockWorkspaceProvider extends Mock implements WorkspaceProvider {}
class MockAuthService extends Mock implements AuthService {}
class MockDriveProvider extends Mock implements DriveProvider {}
class MockDriveService extends Mock implements DriveService {}
class MockThemeProvider extends Mock implements ThemeProvider {}

void main() {
  late MockWorkspaceProvider mockWorkspaceProvider;
  late MockAuthService mockAuthService;
  late MockDriveProvider mockDriveProvider;
  late MockDriveService mockDriveService;
  late MockThemeProvider mockThemeProvider;

  setUp(() {
    mockWorkspaceProvider = MockWorkspaceProvider();
    mockAuthService = MockAuthService();
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();
    mockThemeProvider = MockThemeProvider();
    
    when(() => mockWorkspaceProvider.currentWorkspace).thenReturn(drive.File()..name = 'Test Workspace'..id = 'ws123');
    when(() => mockWorkspaceProvider.isLoading).thenReturn(false);
    when(() => mockWorkspaceProvider.companies).thenReturn(<Company>[]);
    when(() => mockWorkspaceProvider.loadCompanies(any())).thenAnswer((_) async {});

    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockThemeProvider.themeMode).thenReturn(ThemeMode.light);
    when(() => mockThemeProvider.isDarkMode).thenReturn(false);
    when(() => mockAuthService.isAuthenticated).thenReturn(true);
    when(() => mockAuthService.signInSilently()).thenAnswer((_) async {});
    
    when(() => mockDriveService.listModules(any())).thenAnswer((_) async => <drive.File>[]);
  });

  Widget createDrawer() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: mockThemeProvider),
      ],
      child: const MaterialApp(
        home: Scaffold(
          drawer: AppDrawer(),
          body: Center(child: Text('Main Content')),
        ),
      ),
    );
  }

  testWidgets('AppDrawer displays workspace info', (WidgetTester tester) async {
    await tester.pumpWidget(createDrawer());
    
    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    expect(find.text('DRIVE ERP'), findsOneWidget);
    expect(find.text('Test Workspace'), findsOneWidget);
  });

  testWidgets('AppDrawer logout works', (WidgetTester tester) async {
    when(() => mockAuthService.signOut()).thenAnswer((_) async {
       when(() => mockAuthService.isAuthenticated).thenReturn(false);
    });

    await tester.pumpWidget(createDrawer());
    
    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log Out'));
    await tester.pump(); 
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle(); 

    verify(() => mockAuthService.signOut()).called(1);
    expect(find.byType(LandingScreen), findsOneWidget);
  });

  testWidgets('AppDrawer navigation to Settings', (WidgetTester tester) async {
    await tester.pumpWidget(createDrawer());
    
    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('AppDrawer switching workspace navigates to scan results', (WidgetTester tester) async {
    when(() => mockDriveService.checkRootFolder()).thenAnswer((_) async => 'root123');
    when(() => mockDriveService.listWorkspaces('root123')).thenAnswer((_) async => [drive.File()..name = 'WS 1'..id = '1']);

    await tester.pumpWidget(createDrawer());
    
    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Switch Workspace'));
    await tester.pumpAndSettle();
    
    expect(find.byType(WorkspaceSelectorScreen), findsOneWidget);
  });
}
