import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:drivererpapp/screens/dynamic_form_screen.dart';
import 'package:drivererpapp/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    SharedPreferences.setMockInitialValues({});
    AppTheme.useGoogleFonts = false;
    registerFallbackValue(drive.File());
  });

  setUp(() {
    mockDriveService = MockDriveService();
    when(() => mockDriveService.getFileModifiedTime(any())).thenAnswer((_) async => DateTime.now());
    
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
      dashboard: DashboardConfig(cards: []),
    );
  });

  testWidgets('Direct Save Error Reporting', (tester) async {
    debugPrint('TEST: Starting sync_test (Direct Save Error reporting) flow');
    final driveProvider = TestDriveProvider(mockDriveService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DriveProvider>.value(value: driveProvider),
          ChangeNotifierProvider<SchemaProvider>(create: (_) => SchemaProvider(driveService: mockDriveService)),
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

    // 1. Simulate Offline: Make saveRecord throw SocketException (Fast Fail)
    when(() => mockDriveService.saveRecord(any(), any(), any(), any()))
        .thenThrow(Exception('Failed host lookup: www.googleapis.com'));

    // 2. Fill and Save
    await tester.enterText(find.byType(TextField).first, 'Offline Item');
    await tester.tap(find.text('SAVE'));
    
    // Progress Snackbars take time to appear and disappear
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // Wait for "Saving to Drive..." to potentially start disappearing
    await tester.pump(const Duration(seconds: 1)); // Wait for Error Snackbox

    bool foundError = false;
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final allText = tester.allWidgets.whereType<Text>().map((t) => t.data ?? '').join(' | ');
      if (allText.contains('Network connection error')) {
        foundError = true;
        break;
      }
    }

    // 3. Verify error message
    expect(foundError, isTrue, reason: 'Network connection error snackbar should be visible');
    
    // 4. Cleanup snackbars manually to speed up test
    ScaffoldMessenger.of(tester.element(find.byType(DynamicFormScreen))).clearSnackBars();
    await tester.pumpAndSettle();
    
    // 5. Simulate Online: Make saveRecord succeed
    when(() => mockDriveService.saveRecord(any(), any(), any(), any()))
        .thenAnswer((_) async => {});

    // 6. Save again
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    // 7. Verify success via verify call (even if UI was popped)
    verify(() => mockDriveService.saveRecord('mod1', 'Inventory', 'stocks', any())).called(2);
  });
}
