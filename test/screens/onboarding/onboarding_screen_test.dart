import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/onboarding/onboarding_screen.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/models/company_model.dart';
import 'package:drivererpapp/screens/dashboard_screen.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;

class MockWorkspaceProvider extends Mock implements WorkspaceProvider {}
class MockDriveProvider extends Mock implements DriveProvider {}
class MockDriveService extends Mock implements DriveService {}
class MockSheetsApi extends Mock implements sheets.SheetsApi {}
class MockSpreadsheetsResource extends Mock implements sheets.SpreadsheetsResource {}
class MockValuesResource extends Mock implements sheets.SpreadsheetsValuesResource {}
class MockAuthService extends Mock implements AuthService {}

class _TestGoogleAccount extends Fake implements GoogleSignInAccount {
  final String _email;
  _TestGoogleAccount(this._email);
  @override
  String get email => _email;
}

void main() {
  // Disable Provider runtime-type check for tests that inject mock instances
  Provider.debugCheckInvalidValueType = null;
  late MockWorkspaceProvider mockWorkspaceProvider;
  late MockDriveProvider mockDriveProvider;
  late MockDriveService mockDriveService;
  late MockAuthService mockAuthService;

  setUp(() {
    mockWorkspaceProvider = MockWorkspaceProvider();
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();
    mockAuthService = MockAuthService();

    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockWorkspaceProvider.loadCompanies(any())).thenAnswer((_) async {});
    when(() => mockAuthService.currentUser).thenReturn(_TestGoogleAccount('test@example.com'));
    
    registerFallbackValue(Company(id: '1', name: 'Test', folderId: 'f1', role: 'Owner'));
    registerFallbackValue(drive.File());
  });

  Widget createOnboardingScreen() {
    return MultiProvider(
      providers: [
        Provider<AuthService>.value(value: mockAuthService),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
      ],
      child: const MaterialApp(
        home: OnboardingScreen(rootFolderId: 'root123'),
      ),
    );
  }

  testWidgets('OnboardingScreen full flow: Create New Company', (WidgetTester tester) async {
    when(() => mockDriveService.createWorkspace(any(), any()))
        .thenAnswer((_) async => drive.File()..id = 'ws123'..name = 'My Business');
    when(() => mockWorkspaceProvider.registerNewCompany(any(), any()))
        .thenAnswer((_) async {});
    when(() => mockWorkspaceProvider.saveUserAccessSpreadsheetId(any())).thenAnswer((_) async {});
    when(() => mockDriveService.getOrCreateSubFolder(any(), any())).thenAnswer((_) async => 'ua_folder');
    when(() => mockDriveService.ensureUserAccessSpreadsheet(any(), any())).thenAnswer((_) async => 'ua_sheet');
    when(() => mockWorkspaceProvider.setWorkspace(any())).thenReturn(null);
    when(() => mockWorkspaceProvider.currentWorkspace).thenReturn(drive.File()..id = 'ws123'..name = 'My Business');
    when(() => mockWorkspaceProvider.companies).thenReturn(<Company>[]);
    // Provide empty user_access sheet for created workspace
    final mockSheetsApi2 = MockSheetsApi();
    final mockSpreadsheets2 = MockSpreadsheetsResource();
    final mockValues2 = MockValuesResource();
    when(() => mockSheetsApi2.spreadsheets).thenReturn(mockSpreadsheets2);
    when(() => mockSpreadsheets2.values).thenReturn(mockValues2);
    when(() => mockDriveService.sheetsApi).thenReturn(mockSheetsApi2);
    when(() => mockValues2.get(any(), 'modules!A1:Z')).thenAnswer((_) async => sheets.ValueRange(values: []));

    await tester.pumpWidget(createOnboardingScreen());

    // Step 0: Choice
    expect(find.text('Create New Company'), findsOneWidget);
    await tester.tap(find.text('Create New Company'));
    await tester.pumpAndSettle();

    // Step 1: Identity
    expect(find.text('IDENTITY'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'My Business');
    await tester.tap(find.text('LAUNCH WORKSPACE'));
    
    verify(() => mockDriveService.createWorkspace('root123', 'My Business')).called(1);
    
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('OnboardingScreen: Validation empty name', (WidgetTester tester) async {
    await tester.pumpWidget(createOnboardingScreen());
    await tester.tap(find.text('Create New Company'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('LAUNCH WORKSPACE'));
    await tester.pump();
    
    expect(find.text('Please enter a business name'), findsOneWidget);
  });
}
