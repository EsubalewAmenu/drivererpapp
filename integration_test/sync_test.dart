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
import 'package:drivererpapp/screens/dynamic_form_screen.dart';

class MockAuthService extends Mock implements AuthService {}
class MockDriveService extends Mock implements DriveService {}
class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class TestDriveProvider extends DriveProvider {
  DriveService? _mockService;
  TestDriveProvider(this._mockService);
  
  @override
  DriveService? get driveService => _mockService;
  
  void setMockService(DriveService? service) {
    _mockService = service;
    notifyListeners();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockDriveService mockDriveService;
  late TabConfig testTab;
  late ModuleSchema testModule;

  setUpAll(() {
    registerFallbackValue(drive.File());
  });

  setUp(() {
    mockDriveService = MockDriveService();
    
    testTab = TabConfig(
      id: 'stocks',
      label: 'Stocks',
      columns: [
        ColumnConfig(key: 'item', label: 'Item Name', type: 'text', isRequired: true),
      ],
    );

    testModule = ModuleSchema(
      id: 'mod1',
      name: 'Inventory',
      icon: 'inventory',
      primaryColor: '#F59E0B',
      version: '1.0.0',
      settings: {},
      tabs: [testTab],
      dashboard: DashboardConfig(kpiCards: []),
    );
  });

  testWidgets('Offline Queue and Sync Verification', (tester) async {
    final driveProvider = TestDriveProvider(mockDriveService);
    final syncProvider = SyncProvider()..updateDriveProvider(driveProvider);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DriveProvider>.value(value: driveProvider),
          ChangeNotifierProvider<SyncProvider>.value(value: syncProvider),
        ],
        child: MaterialApp(
          home: DynamicFormScreen(
            tab: testTab,
            primaryColor: Colors.orange,
            module: testModule,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Simulate Offline: Make saveRecord throw
    when(() => mockDriveService.saveRecord(any(), any(), any(), any()))
        .thenThrow(Exception('No Connectivity'));

    // 2. Fill and Save
    await tester.enterText(find.byType(TextField).first, 'Offline Item');
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    // 3. Verify it's in the queue
    expect(syncProvider.pendingCount, 1);
    // expect(find.text('Offline: Record added to sync queue'), findsOneWidget);

    // 4. Simulate Online: Make saveRecord succeed
    when(() => mockDriveService.saveRecord(any(), any(), any(), any()))
        .thenAnswer((_) async => {});

    // 5. Trigger Sync
    await syncProvider.sync();
    await tester.pumpAndSettle();

    // 6. Verify queue is empty and saveRecord was called
    expect(syncProvider.pendingCount, 0);
    // 3 calls: 1 from _saveForm, 1 from addToQueue (automatic sync), 1 from manual sync
    verify(() => mockDriveService.saveRecord('mod1', 'Inventory', 'stocks', any())).called(3);
  });
}
