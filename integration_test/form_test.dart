import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/providers/sync_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:drivererpapp/screens/landing_screen.dart';

class MockAuthService extends Mock implements AuthService {}
class MockDriveService extends Mock implements DriveService {}
class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class TestDriveProvider extends DriveProvider {
  final DriveService? mockService;
  TestDriveProvider(this.mockService);
  
  @override
  DriveService? get driveService => mockService;
  @override
  void updateClient(http.Client? client) {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthService mockAuthService;
  late MockDriveService mockDriveService;
  late MockGoogleSignInAccount mockUser;

  setUpAll(() {
    registerFallbackValue(drive.File());
    registerFallbackValue(ModuleSchema(
      id: '', name: '', icon: '', primaryColor: '', version: '',
      settings: {}, dashboard: DashboardConfig(kpiCards: []), tabs: []
    ));
  });

  setUp(() {
    mockAuthService = MockAuthService();
    mockDriveService = MockDriveService();
    mockUser = MockGoogleSignInAccount();

    when(() => mockUser.displayName).thenReturn('Test User');
    when(() => mockUser.email).thenReturn('test@example.com');
    when(() => mockAuthService.currentUser).thenReturn(mockUser);
    when(() => mockAuthService.isAuthenticated).thenReturn(false);
    when(() => mockAuthService.signInSilently()).thenAnswer((_) async {});
    
    when(() => mockAuthService.signIn()).thenAnswer((_) async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
    });

    when(() => mockDriveService.checkRootFolder()).thenAnswer((_) async => 'root123');
    when(() => mockDriveService.listWorkspaces(any())).thenAnswer((_) async => []);
  });

  testWidgets('End-to-End Form Submission Flow', (tester) async {
    final workspace = drive.File()..id = 'ws1'..name = 'ERP Workspace';
    final moduleFolder = drive.File()..id = 'mod1'..name = 'Inventory';
    
    final moduleSchema = ModuleSchema(
      id: 'mod1',
      name: 'Inventory',
      icon: 'inventory',
      primaryColor: '#F59E0B',
      version: '1.0.0',
      settings: {},
      tabs: [
        TabConfig(
          id: 'stocks',
          label: 'Stocks',
          columns: [
            ColumnConfig(key: 'item', label: 'Item Name', type: 'text', isRequired: true),
            ColumnConfig(key: 'qty', label: 'Quantity', type: 'number'),
          ],
        ),
      ],
      dashboard: DashboardConfig(kpiCards: []),
    );

    when(() => mockDriveService.listWorkspaces('root123')).thenAnswer((_) async => [workspace]);
    when(() => mockDriveService.listModules('ws1')).thenAnswer((_) async => [moduleFolder]);
    when(() => mockDriveService.getFileId('mod1', 'config')).thenAnswer((_) async => 'config_file');
    when(() => mockDriveService.readModuleConfig('config_file')).thenAnswer((_) async => moduleSchema.toJson());
    when(() => mockDriveService.getFileId('mod1', 'stocks')).thenAnswer((_) async => 'stocks_sheet');
    when(() => mockDriveService.fetchRecords(any(), any(), any())).thenAnswer((_) async => []);
    when(() => mockDriveService.saveRecord(any(), any(), any(), any())).thenAnswer((_) async => {});

    final driveProvider = TestDriveProvider(mockDriveService);
    final syncProvider = SyncProvider()..updateDriveProvider(driveProvider);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
          ChangeNotifierProvider<WorkspaceProvider>(create: (_) => WorkspaceProvider()),
          ChangeNotifierProvider<DriveProvider>.value(value: driveProvider),
          ChangeNotifierProvider<SyncProvider>.value(value: syncProvider),
        ],
        child: const MaterialApp(
          home: LandingScreen(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    // Scanning screen delay - Wait for scanning to finish and transition to selector
    // SystemScanningScreen has a delay of 500ms + network mocks
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    
    expect(find.text('ERP Workspace'), findsOneWidget);
    await tester.tap(find.text('ERP Workspace'));
    await tester.pumpAndSettle();

    // Dashboard load delay
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    
    // Tap the Inventory card
    final inventoryCard = find.descendant(
      of: find.byType(GridView),
      matching: find.text('Inventory'),
    );
    await tester.tap(inventoryCard.first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('STOCKS'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    await tester.enterText(textFields.first, 'MacBook Pro M3');
    await tester.enterText(textFields.last, '10');
    await tester.pumpAndSettle();

    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    verify(() => mockDriveService.saveRecord(
      'mod1',
      'Inventory',
      'stocks',
      any(that: containsPair('item', 'MacBook Pro M3')),
    )).called(1);

    expect(find.text('STOCKS'), findsOneWidget);
  });
}
