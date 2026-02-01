import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/landing_screen.dart';
import 'package:drivererpapp/screens/system_scanning_screen.dart';
import 'package:drivererpapp/screens/workspace_selector_screen.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/models/company_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthService extends Mock implements AuthService {}
class MockWorkspaceProvider extends Mock implements WorkspaceProvider {}
class MockDriveProvider extends Mock implements DriveProvider {}
class MockDriveService extends Mock implements DriveService {}

void main() {
  late MockAuthService mockAuthService;
  late MockWorkspaceProvider mockWorkspaceProvider;
  late MockDriveProvider mockDriveProvider;
  late MockDriveService mockDriveService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockAuthService = MockAuthService();
    mockWorkspaceProvider = MockWorkspaceProvider();
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();

    // Default behaviors
    when(() => mockAuthService.isAuthenticated).thenReturn(false);
    when(() => mockAuthService.authClient).thenReturn(null);
    when(() => mockAuthService.signInSilently()).thenAnswer((_) async {});
    when(() => mockWorkspaceProvider.isLoading).thenReturn(false);
    when(() => mockWorkspaceProvider.loadCompanies(any())).thenAnswer((_) async {});
    when(() => mockWorkspaceProvider.companies).thenReturn(<Company>[]);
    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockDriveService.getFileId(any(), any())).thenAnswer((_) async => null);
    when(() => mockDriveService.checkRootFolder()).thenAnswer((_) async => 'root123');
    when(() => mockDriveService.ensureCompanyRegistry(any())).thenAnswer((_) async => 'reg123');
    when(() => mockDriveProvider.updateClient(any())).thenReturn(null);
  });

  Widget createLandingScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
      ],
      child: const MaterialApp(
        home: LandingScreen(),
      ),
    );
  }

  testWidgets('LandingScreen should show branding and sign-in button', (WidgetTester tester) async {
    await tester.pumpWidget(createLandingScreen());
    await tester.pumpAndSettle();

    // Check for branding text
    expect(find.text('DRIVE ERP'), findsOneWidget);
    expect(find.text('Your Business. Your Drive. Your Data.'), findsOneWidget);

    // Check for sign-in button
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('LandingScreen should call signIn on button press and navigate', (WidgetTester tester) async {
    when(() => mockAuthService.signIn()).thenAnswer((_) async {
       when(() => mockAuthService.isAuthenticated).thenReturn(true);
       // Once navigated, SystemScanningScreen will check this
       when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    });

    await tester.pumpWidget(createLandingScreen());
    await tester.pumpAndSettle();

    final signInButton = find.text('Continue with Google');
    await tester.tap(signInButton);
    await tester.pump(); // Show loading dialog
    
    await tester.pump(const Duration(milliseconds: 100)); // Process the navigate
    await tester.pump(const Duration(milliseconds: 100)); 
    await tester.pump(const Duration(milliseconds: 100)); 

    expect(find.byType(SystemScanningScreen), findsOneWidget);
    
    // Clear any timers from SystemScanningScreen
    await tester.pumpAndSettle();
  });

  testWidgets('LandingScreen should show error on sign-in failure', (WidgetTester tester) async {
    when(() => mockAuthService.signIn()).thenThrow(Exception('Network error'));

    await tester.pumpWidget(createLandingScreen());
    await tester.pumpAndSettle();

    final signInButton = find.text('Continue with Google');
    await tester.tap(signInButton);
    await tester.pump(); // Dialog
    
    await tester.pump(const Duration(milliseconds: 100)); 
    await tester.pump(const Duration(milliseconds: 100)); 
    await tester.pumpAndSettle();

    expect(find.textContaining('Sign in failed: Exception: Network error'), findsOneWidget);
  });

  testWidgets('LandingScreen should auto-navigate if already authenticated silently', (WidgetTester tester) async {
    when(() => mockAuthService.isAuthenticated).thenReturn(true);
    when(() => mockAuthService.signInSilently()).thenAnswer((_) async {});
    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    
    await tester.pumpWidget(createLandingScreen());
    await tester.pump(); // PostFrame
    await tester.pumpAndSettle(); 

    expect(find.byType(WorkspaceSelectorScreen), findsOneWidget);
  });
}
