import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:drivererpapp/screens/workspace_selector_screen.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/theme_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/models/company_model.dart';

class MockWorkspaceProvider extends Mock implements WorkspaceProvider {}
class MockDriveProvider extends Mock implements DriveProvider {}
class MockDriveService extends Mock implements DriveService {}
class MockThemeProvider extends Mock implements ThemeProvider {}

void main() {
  late MockWorkspaceProvider mockWorkspaceProvider;
  late MockDriveProvider mockDriveProvider;
  late MockDriveService mockDriveService;
  late MockThemeProvider mockThemeProvider;

  setUpAll(() {
    registerFallbackValue(drive.File());
  });

  setUp(() {
    mockWorkspaceProvider = MockWorkspaceProvider();
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();
    mockThemeProvider = MockThemeProvider();

    when(() => mockThemeProvider.themeMode).thenReturn(ThemeMode.light);
    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockDriveService.listModules(any())).thenAnswer((_) async => []);
    
    // Default stubs
    when(() => mockWorkspaceProvider.isLoading).thenReturn(false);
    when(() => mockWorkspaceProvider.companies).thenReturn([]);
    when(() => mockWorkspaceProvider.loadCompanies(any())).thenAnswer((_) async {});
    when(() => mockWorkspaceProvider.setWorkspace(any())).thenReturn(null);
  });

  Widget createWorkspaceSelector() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: mockThemeProvider),
      ],
      child: MaterialApp(
        home: WorkspaceSelectorScreen(
          rootFolderId: 'root123',
        ),
      ),
    );
  }

  testWidgets('WorkspaceSelectorScreen shows empty state when no companies', (WidgetTester tester) async {
    when(() => mockWorkspaceProvider.companies).thenReturn([]);
    await tester.pumpWidget(createWorkspaceSelector());
    // Pump to allow initState -> loadCompanies to fire (though mocked) and UI to rebuild
    await tester.pump();

    expect(find.text('No workspaces found.\nCreate one to get started.'), findsOneWidget);
    expect(find.text('CREATE NEW WORKSPACE'), findsOneWidget);
  });

  testWidgets('WorkspaceSelectorScreen lists available companies', (WidgetTester tester) async {
    final companies = [
      Company(id: '1', name: 'Company A', folderId: 'f1', role: 'Owner'),
      Company(id: '2', name: 'Company B', folderId: 'f2', role: 'Admin'),
    ];
    when(() => mockWorkspaceProvider.companies).thenReturn(companies);

    await tester.pumpWidget(createWorkspaceSelector());
    await tester.pump();

    expect(find.text('Company A'), findsOneWidget);
    expect(find.text('Company B'), findsOneWidget);
    expect(find.text('Role: Owner'), findsOneWidget);
    expect(find.text('Role: Admin'), findsOneWidget);
  });

  testWidgets('WorkspaceSelectorScreen sets workspace and navigates', (WidgetTester tester) async {
    final companies = [
      Company(id: '1', name: 'Company A', folderId: 'f1', role: 'Owner'),
    ];
    when(() => mockWorkspaceProvider.companies).thenReturn(companies);

    await tester.pumpWidget(createWorkspaceSelector());
    await tester.pump();

    await tester.tap(find.text('Company A'));
    await tester.pumpAndSettle();

    verify(() => mockWorkspaceProvider.setWorkspace(any())).called(1);
    // Should navigate to Dashboard (check for KPI label again)
    expect(find.text('NET PROFIT ENGINE'), findsOneWidget);
  });
}
