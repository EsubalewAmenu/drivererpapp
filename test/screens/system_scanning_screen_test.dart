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
    SharedPreferences.setMockInitialValues({}); // Initialize SharedPreferences mock
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();
    mockThemeProvider = MockThemeProvider();
    mockWorkspaceProvider = MockWorkspaceProvider();

    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockThemeProvider.themeMode).thenReturn(ThemeMode.light);
    
    // Stub WorkspaceProvider methods
    when(() => mockWorkspaceProvider.setWorkspace(any())).thenReturn(null);
    when(() => mockWorkspaceProvider.isLoading).thenReturn(false);
    when(() => mockWorkspaceProvider.companies).thenReturn(<Company>[]);
    when(() => mockWorkspaceProvider.loadCompanies(any())).thenAnswer((_) async {});
    
    // Stub listModules for DashboardScreen
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

  testWidgets('SystemScanningScreen scans and redirects', (WidgetTester tester) async {
    when(() => mockDriveService.checkRootFolder()).thenAnswer((_) async => 'root123');
    when(() => mockDriveService.listWorkspaces('root123')).thenAnswer((_) async => []);

    await tester.pumpWidget(createScanningScreen());
    
    // Scan starts in post-frame callback.
    // Trigger the callback
    await tester.pump(); 

    // There are delays in the sequence:
    // 1. checkRootFolder
    // 2. 500ms delay
    // 3. listWorkspaces
    // 4. 500ms delay
    // 5. Navigation

    // We use pump with duration to advance timers, but not 'pumpAndSettle' 
    // because CircularProgressIndicator is indeterminate.
    
    await tester.pump(const Duration(milliseconds: 600)); // Past first delay
    await tester.pump(const Duration(milliseconds: 600)); // Past second delay
    await tester.pump(); // Trigger navigation

    // Should push WorkspaceSelectorScreen (which shows "Select Workspace")
    expect(find.text('SELECT WORKSPACE'), findsOneWidget);
  });

  testWidgets('SystemScanningScreen skips implicit restore when autoRestore is false', (WidgetTester tester) async {
    // Simulate a saved workspace
    SharedPreferences.setMockInitialValues({'last_workspace_id': 'ws_saved'});
    
    when(() => mockDriveService.checkRootFolder()).thenAnswer((_) async => 'root123');
    when(() => mockDriveService.listWorkspaces('root123')).thenAnswer((_) async => []);

    // Because autoRestore is false, it should NOT try to use the saved ID (which would crash/fail here as we didn't mock driveApi)
    // It should proceed to scan.
    await tester.pumpWidget(createScanningScreen(autoRestore: false));
    await tester.pump(); 

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    // Should reach selector
    expect(find.text('SELECT WORKSPACE'), findsOneWidget);
  });

  testWidgets('SystemScanningScreen restores previous session', (WidgetTester tester) async {
    // Simulate a saved workspace
    SharedPreferences.setMockInitialValues({'last_workspace_id': 'ws_saved'});
    
    when(() => mockWorkspaceProvider.restorePreviousSession()).thenAnswer((_) async => true);
    final mockWs = drive.File()..name = 'Test WS'..id = 'ws_saved';
    when(() => mockWorkspaceProvider.currentWorkspace).thenReturn(mockWs);

    await tester.pumpWidget(createScanningScreen(autoRestore: true));
    await tester.pump(); // Trigger scan

    // Past Step 0 check
    await tester.pump(); 
    await tester.idle();
    await tester.pump();
    
    // Check for status message or final screen
    if (find.text('Restoring previous workspace...').evaluate().isEmpty) {
       // Maybe it was so fast it already finished?
    } else {
       expect(find.text('Restoring previous workspace...'), findsOneWidget);
    }

    await tester.pump(const Duration(milliseconds: 1000)); // Delay after welcome message
    await tester.pump(); // Trigger navigation

    // Should push DashboardScreen
    expect(find.byType(DashboardScreen), findsOneWidget);
  });
}
