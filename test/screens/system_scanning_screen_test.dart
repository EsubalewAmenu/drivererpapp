import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drivererpapp/screens/system_scanning_screen.dart';
import 'package:drivererpapp/screens/dashboard_screen.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/providers/theme_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/models/company_model.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class MockDriveProvider extends Mock implements DriveProvider {}
class MockDriveService extends Mock implements DriveService {}
class MockThemeProvider extends Mock implements ThemeProvider {}
class MockWorkspaceProvider extends Mock implements WorkspaceProvider {}

void main() {
  late MockDriveProvider mockDriveProvider;
  late MockDriveService mockDriveService;
  late MockThemeProvider mockThemeProvider;
  late MockWorkspaceProvider mockWorkspaceProvider;

  setUpAll(() {
    registerFallbackValue(drive.File());
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();
    mockThemeProvider = MockThemeProvider();
    mockWorkspaceProvider = MockWorkspaceProvider();

    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockThemeProvider.themeMode).thenReturn(ThemeMode.light);
    
    when(() => mockWorkspaceProvider.setWorkspace(any())).thenReturn(null);
    when(() => mockWorkspaceProvider.isLoading).thenReturn(false);
    when(() => mockWorkspaceProvider.companies).thenReturn(<Company>[]);
    when(() => mockWorkspaceProvider.loadCompanies(any())).thenAnswer((_) async {});
    when(() => mockWorkspaceProvider.currentWorkspace).thenReturn(drive.File()..name = 'Test WS'..id = 'ws123');
    
    when(() => mockDriveService.listModules(any())).thenAnswer((_) async => <drive.File>[]);
  });

  Widget createScanningScreen({bool autoRestore = true}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: mockThemeProvider),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
      ],
      child: MaterialApp(
        home: SystemScanningScreen(autoRestore: autoRestore),
      ),
    );
  }

  testWidgets('SystemScanningScreen scans and redirects to selector', (WidgetTester tester) async {
    when(() => mockDriveService.checkRootFolder()).thenAnswer((_) async => 'root123');
    when(() => mockDriveService.listWorkspaces('root123')).thenAnswer((_) async => []);

    await tester.pumpWidget(createScanningScreen());
    await tester.pump(); // PostFrame
    
    await tester.pump(const Duration(milliseconds: 600)); 
    await tester.pump(const Duration(milliseconds: 600)); 
    await tester.pump(); 

    expect(find.text('SELECT WORKSPACE'), findsOneWidget);
  });

  testWidgets('SystemScanningScreen handles error and allows retry', (WidgetTester tester) async {
    when(() => mockDriveService.checkRootFolder()).thenThrow(Exception('No connection'));

    await tester.pumpWidget(createScanningScreen());
    await tester.pump(); // PostFrame
    await tester.pump(const Duration(seconds: 2)); 

    // Debug: print all text
    for (final element in find.byType(Text).evaluate()) {
      final textWidget = element.widget as Text;
      print('Text on screen: "${textWidget.data}"');
    }

    expect(find.textContaining('System Error'), findsOneWidget);
    expect(find.text('RETRY CONNECTION'), findsOneWidget);

    when(() => mockDriveService.checkRootFolder()).thenAnswer((_) async => 'root123');
    when(() => mockDriveService.listWorkspaces('root123')).thenAnswer((_) async => []);

    await tester.tap(find.text('RETRY CONNECTION'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    
    // Debug: print all text
    for (final element in find.byType(Text).evaluate()) {
      final textWidget = element.widget as Text;
      print('Text on screen (post-retry): "${textWidget.data}"');
    }

    expect(find.text('SELECT WORKSPACE'), findsOneWidget);
  });

  testWidgets('SystemScanningScreen auto-restores to Dashboard', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'last_workspace_id': 'ws123'});
    when(() => mockWorkspaceProvider.restorePreviousSession()).thenAnswer((_) async => true);
    
    await tester.pumpWidget(createScanningScreen());
    await tester.pump(); // PostFrame
    
    // Auto-restore might show some messages
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('SystemScanningScreen skip restore when autoRestore is false', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'last_workspace_id': 'ws_saved'});
    
    when(() => mockDriveService.checkRootFolder()).thenAnswer((_) async => 'root123');
    when(() => mockDriveService.listWorkspaces('root123')).thenAnswer((_) async => []);

    await tester.pumpWidget(createScanningScreen(autoRestore: false));
    await tester.pump(); 

    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump();

    expect(find.text('SELECT WORKSPACE'), findsOneWidget);
  });
}
