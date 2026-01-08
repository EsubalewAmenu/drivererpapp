import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:drivererpapp/screens/onboarding/onboarding_screen.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/models/company_model.dart';

class MockDriveProvider extends Mock implements DriveProvider {}
class MockDriveService extends Mock implements DriveService {}
class MockWorkspaceProvider extends Mock implements WorkspaceProvider {}

void main() {
  late MockDriveProvider mockDriveProvider;
  late MockDriveService mockDriveService;
  late MockWorkspaceProvider mockWorkspaceProvider;

  setUp(() {
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();
    mockWorkspaceProvider = MockWorkspaceProvider();

    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockDriveService.listModules(any())).thenAnswer((_) async => []);
    
    // Register Company fallback
    registerFallbackValue(drive.File());
    registerFallbackValue(Company(id: '0', name: 'Fallback', folderId: 'f0', role: 'Owner'));

    // Stub registerNewCompany
    when(() => mockWorkspaceProvider.registerNewCompany(any(), any()))
        .thenAnswer((_) async {});
    when(() => mockWorkspaceProvider.setWorkspace(any())).thenReturn(null);
  });

  Widget createOnboardingScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
      ],
      child: const MaterialApp(
        home: OnboardingScreen(rootFolderId: 'root123'),
      ),
    );
  }

  testWidgets('OnboardingScreen flow: Create New Company', (WidgetTester tester) async {
    when(() => mockDriveService.createWorkspace(any(), any()))
        .thenAnswer((_) async => drive.File()..id = 'ws1'..name = 'My Business');

    await tester.pumpWidget(createOnboardingScreen());

    // Step 0: Choices
    expect(find.text('Create New Company'), findsOneWidget);
    await tester.tap(find.text('Create New Company'));
    await tester.pumpAndSettle();

    // Step 1: Identity
    expect(find.text('IDENTITY'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'My Business');
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();

    // Step 2: Industry
    expect(find.text('INDUSTRY FOCUS'), findsOneWidget);
    await tester.tap(find.text('Retail'));
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();

    // Step 3: Toolkit
    expect(find.text('INITIAL TOOLKIT'), findsOneWidget);
    await tester.tap(find.text('Inventory'));
    await tester.tap(find.text('LAUNCH WORKSPACE'));
    
    // Process activation
    await tester.pump(); // Start creating
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    
    await tester.pumpAndSettle(); // Finish and navigate

    // Should navigate to Dashboard
    expect(find.text('NET PROFIT ENGINE'), findsOneWidget);
    
    verify(() => mockDriveService.createWorkspace('root123', 'My Business')).called(1);
    // Should also create the selected module
    verify(() => mockDriveService.createWorkspace('ws1', 'Inventory')).called(1);
  });

  testWidgets('OnboardingScreen flow: Join Network', (WidgetTester tester) async {
    await tester.pumpWidget(createOnboardingScreen());

    await tester.tap(find.text('Join Network'));
    await tester.pumpAndSettle();

    expect(find.text('JOIN NETWORK'), findsOneWidget);
    expect(find.text('Enter Invitation Code'), findsOneWidget);
    
    await tester.tap(find.text('LAUNCH WORKSPACE'));
    await tester.pumpAndSettle();
    
    expect(find.text('NET PROFIT ENGINE'), findsOneWidget);
  });
}
