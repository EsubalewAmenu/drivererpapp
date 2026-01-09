import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:drivererpapp/theme/app_theme.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/providers/theme_provider.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:drivererpapp/screens/schema_editor_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthService extends Mock implements AuthService {}
class MockDriveService extends Mock implements DriveService {}

class TestDriveProvider extends DriveProvider {
  final DriveService? mockService;
  TestDriveProvider(this.mockService);
  @override
  DriveService? get driveService => mockService;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthService mockAuthService;
  late MockDriveService mockDriveService;

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    AppTheme.useGoogleFonts = false;
    registerFallbackValue(drive.File());
  });

  setUp(() {
    mockAuthService = MockAuthService();
    mockDriveService = MockDriveService();

    when(() => mockAuthService.isAuthenticated).thenReturn(true);
    when(() => mockAuthService.currentUser).thenReturn(null);
  });

  testWidgets('Schema Blueprint Editor: Detailed Flow (Tabs, Columns, KPIs)', (tester) async {
    debugPrint('TEST: Starting schema_blueprint_detailed_test');
    
    final module = drive.File()..id = 'mod1'..name = 'Test Lab';
    
    when(() => mockDriveService.getFileId('mod1', 'config')).thenAnswer((_) async => 'config_id');
    when(() => mockDriveService.readModuleConfig('config_id')).thenAnswer((_) async => <String, dynamic>{
      'id': 'mod1',
      'name': 'Test Lab',
      'icon': 'science',
      'primaryColor': '#4A90E2',
      'version': '1.0.0',
      'tabs': <dynamic>[],
      'dashboard': <String, dynamic>{'cards': <dynamic>[]},
      'settings': <String, dynamic>{}
    });

    final workspaceProvider = WorkspaceProvider();
    final driveProvider = TestDriveProvider(mockDriveService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
          ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaceProvider),
          ChangeNotifierProvider<DriveProvider>.value(value: driveProvider),
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<SchemaProvider>(create: (_) => SchemaProvider(driveService: mockDriveService)),
        ],
        child: MaterialApp(
          home: SchemaEditorScreen(module: module),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Add a Tab
    await tester.tap(find.text('ADD TAB'));
    await tester.pumpAndSettle();
    
    await tester.enterText(find.widgetWithText(TextField, 'Tab Label'), 'Observations');
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    
    expect(find.text('Observations'), findsOneWidget);

    // 2. Add a Column to the Tab
    await tester.tap(find.byIcon(Icons.add_circle_outline_rounded)); // Add column in current tab (Observations)
    await tester.pumpAndSettle();
    
    await tester.enterText(find.widgetWithText(TextField, 'Column Key'), 'note');
    await tester.enterText(find.widgetWithText(TextField, 'Label'), 'Notes');
    // Default type is text
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    
    expect(find.text('Notes'), findsOneWidget);

    // 3. Switch to Dashboard tab
    await tester.tap(find.text('DASHBOARD'));
    await tester.pumpAndSettle();
    
    // 4. Add a KPI Card
    await tester.tap(find.text('ADD KPI CARD'));
    await tester.pumpAndSettle();
    
    await tester.enterText(find.widgetWithText(TextField, 'Card Label'), 'Total Notes');
    await tester.enterText(find.widgetWithText(TextField, 'Calculation Formula'), 'COUNT(A:A)');
    // Default format is number
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    
    expect(find.text('Total Notes'), findsOneWidget);

    // 5. Switch to Settings tab
    await tester.tap(find.text('SETTINGS'));
    await tester.pumpAndSettle();
    
    // 6. Change Module Name
    await tester.enterText(find.widgetWithText(TextField, 'Module Name'), 'Advanced Lab');
    
    // 7. Save and Activate
    when(() => mockDriveService.updateModuleConfig(any(), any())).thenAnswer((_) async => {});
    
    await tester.tap(find.text('ACTIVATE'));
    await tester.pumpAndSettle();

    // Verification: Activation flow usually goes back or shows snackbar.
    // Since we started directly in SchemaEditorScreen, it should attempt to navigate back.
    expect(find.byType(SchemaEditorScreen), findsNothing);
  });
}
