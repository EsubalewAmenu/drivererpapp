import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drivererpapp/screens/system_scanning_screen.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/providers/theme_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';

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
    // Be sure to mock methods called by WorkspaceProvider if any during init, 
    // but WorkspaceProvider.getLastWorkspaceId is static and uses SharedPreferences directly.
    // However, setWorkspace is called on the provider instance.
    when(() => mockWorkspaceProvider.setWorkspace(any())).thenReturn(null);
  });

  Widget createScanningScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: mockThemeProvider),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
      ],
      child: const MaterialApp(
        home: SystemScanningScreen(),
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
}
