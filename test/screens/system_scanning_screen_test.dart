import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/system_scanning_screen.dart';
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

  setUp(() {
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();
    mockThemeProvider = MockThemeProvider();

    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockThemeProvider.themeMode).thenReturn(ThemeMode.light);
  });

  Widget createScanningScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: mockThemeProvider),
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
    // Allow it to run through all steps.
    // We use a longer timeout because of several 500ms delays in the sequence.
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Should push WorkspaceSelectorScreen (which shows "Select Workspace")
    expect(find.text('SELECT WORKSPACE'), findsOneWidget);
  });
}
