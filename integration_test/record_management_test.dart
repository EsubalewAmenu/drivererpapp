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
import 'package:drivererpapp/screens/dashboard_screen.dart';
import 'package:drivererpapp/screens/record_detail_screen.dart';
import 'package:drivererpapp/screens/settings_screen.dart';
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
    when(() => mockDriveService.getFileModifiedTime(any())).thenAnswer((_) async => DateTime.now());
  });

  Widget createTestWidget({
    required WorkspaceProvider workspaceProvider,
    required DriveProvider driveProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaceProvider),
        ChangeNotifierProvider<DriveProvider>.value(value: driveProvider),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<SchemaProvider>(create: (_) => SchemaProvider(driveService: mockDriveService)),
      ],
      child: const MaterialApp(
        home: DashboardScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }

  testWidgets('Record Management: Details, History, and Visual Templates', (tester) async {
    debugPrint('TEST: Starting record_management_test');
    
    final workspace = drive.File()..id = 'ws1'..name = 'ERP Lab';
    final moduleFile = drive.File()..id = 'mod1'..name = 'Inventory';
    
    when(() => mockDriveService.listModules('ws1')).thenAnswer((_) async => [moduleFile]);
    
    // Mock records for Inventory -> Stocks
    when(() => mockDriveService.fetchRecords('mod1', 'Inventory', 'stocks',
      offset: any(named: 'offset'), limit: any(named: 'limit'), fetchSubTables: any(named: 'fetchSubTables'), descending: any(named: 'descending')))
      .thenAnswer((_) async => [
        {'record_id': 'item-001', 'item_name': 'MacBook Pro', 'quantity': 5, 'price': 2500},
      ]);

    // Mock history for record
    when(() => mockDriveService.listFileVersions(any())).thenAnswer((_) async => [
      drive.Revision()..id = 'v1'..modifiedTime = DateTime.now().subtract(const Duration(days: 1)),
      drive.Revision()..id = 'v2'..modifiedTime = DateTime.now(),
    ]);

    final workspaceProvider = WorkspaceProvider();
    workspaceProvider.setWorkspace(workspace);
    final driveProvider = TestDriveProvider(mockDriveService);

    await tester.pumpWidget(createTestWidget(
      workspaceProvider: workspaceProvider,
      driveProvider: driveProvider,
    ));

    await tester.pumpAndSettle();

    // 1. Navigate to Module
    await tester.tap(find.text('Inventory'));
    await tester.pumpAndSettle();

    // 2. Select record
    await tester.tap(find.text('MacBook Pro'));
    await tester.pumpAndSettle();

    expect(find.byType(RecordDetailScreen), findsOneWidget);
    expect(find.text('ITEM-001'), findsOneWidget);

    // 3. Check History inside record
    await tester.tap(find.byIcon(Icons.history_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Version History'), findsOneWidget);
    await tester.tap(find.text('CLOSE'));
    await tester.pumpAndSettle();

    // 4. Go to Settings via Dashboard Drawer (Back out first)
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    // 5. Change Template to "Modern Visual"
    await tester.tap(find.text('STANDARD'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MODERN VISUAL').last);
    await tester.pumpAndSettle();

    // 6. Go back and verify visual change in RecordDetail
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    
    await tester.tap(find.text('Inventory'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MacBook Pro'));
    await tester.pumpAndSettle();

    // In modern mode, the record ID is usually in a header section "RECORD ENTRY"
    expect(find.text('RECORD ENTRY'), findsOneWidget);
  });
}
