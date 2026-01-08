import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/workspace_selector_screen.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/models/company_model.dart';
import 'package:drivererpapp/screens/dashboard_screen.dart';
import 'package:drivererpapp/screens/onboarding/onboarding_screen.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';

class MockWorkspaceProvider extends Mock implements WorkspaceProvider {}
class MockDriveProvider extends Mock implements DriveProvider {}
class MockDriveService extends Mock implements DriveService {}

void main() {
  late MockWorkspaceProvider mockWorkspaceProvider;
  late MockDriveProvider mockDriveProvider;
  late MockDriveService mockDriveService;

  setUp(() {
    mockWorkspaceProvider = MockWorkspaceProvider();
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();
    
    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    registerFallbackValue(drive.File());
  });

  Widget createSelectorScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
      ],
      child: const MaterialApp(
        home: WorkspaceSelectorScreen(rootFolderId: 'root123'),
      ),
    );
  }

  testWidgets('WorkspaceSelectorScreen shows loader then content', (WidgetTester tester) async {
    when(() => mockWorkspaceProvider.isLoading).thenReturn(true);
    when(() => mockWorkspaceProvider.loadCompanies(any())).thenAnswer((_) async {});

    await tester.pumpWidget(createSelectorScreen());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    when(() => mockWorkspaceProvider.isLoading).thenReturn(false);
    when(() => mockWorkspaceProvider.companies).thenReturn([
      Company(id: '1', name: 'Test Corp', folderId: 'f1', role: 'Owner'),
    ]);
    
    await tester.pump();
    expect(find.text('Test Corp'), findsOneWidget);
  });

  testWidgets('WorkspaceSelectorScreen selects workspace', (WidgetTester tester) async {
    when(() => mockWorkspaceProvider.isLoading).thenReturn(false);
    when(() => mockWorkspaceProvider.loadCompanies(any())).thenAnswer((_) async {});
    when(() => mockWorkspaceProvider.companies).thenReturn([
      Company(id: '1', name: 'Test Corp', folderId: 'f1', role: 'Owner'),
    ]);
    when(() => mockWorkspaceProvider.setWorkspace(any())).thenReturn(null);
    when(() => mockWorkspaceProvider.currentWorkspace).thenReturn(drive.File()..name = 'Test Corp'..id = 'f1');
    when(() => mockDriveService.listModules(any())).thenAnswer((_) async => []);

    await tester.pumpWidget(createSelectorScreen());
    await tester.tap(find.text('Test Corp'));
    await tester.pumpAndSettle();

    verify(() => mockWorkspaceProvider.setWorkspace(any())).called(1);
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('WorkspaceSelectorScreen navigates to Onboarding', (WidgetTester tester) async {
    when(() => mockWorkspaceProvider.isLoading).thenReturn(false);
    when(() => mockWorkspaceProvider.loadCompanies(any())).thenAnswer((_) async {});
    when(() => mockWorkspaceProvider.companies).thenReturn([]);

    await tester.pumpWidget(createSelectorScreen());
    await tester.tap(find.text('CREATE NEW WORKSPACE'));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
  });
}
