import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:drivererpapp/screens/workspace_selector_screen.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/theme_provider.dart';
import 'package:drivererpapp/providers/sync_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';

class MockWorkspaceProvider extends Mock implements WorkspaceProvider {}
class MockDriveProvider extends Mock implements DriveProvider {}
class MockDriveService extends Mock implements DriveService {}
class MockSyncProvider extends Mock implements SyncProvider {}
class MockThemeProvider extends Mock implements ThemeProvider {}

void main() {
  late MockWorkspaceProvider mockWorkspaceProvider;
  late MockDriveProvider mockDriveProvider;
  late MockDriveService mockDriveService;
  late MockSyncProvider mockSyncProvider;
  late MockThemeProvider mockThemeProvider;

  setUpAll(() {
    registerFallbackValue(drive.File());
  });

  setUp(() {
    mockWorkspaceProvider = MockWorkspaceProvider();
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();
    mockSyncProvider = MockSyncProvider();
    mockThemeProvider = MockThemeProvider();

    when(() => mockThemeProvider.themeMode).thenReturn(ThemeMode.light);
    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockDriveService.listModules(any())).thenAnswer((_) async => []);
  });

  Widget createWorkspaceSelector(List<drive.File> workspaces) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ChangeNotifierProvider<SyncProvider>.value(value: mockSyncProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: mockThemeProvider),
      ],
      child: MaterialApp(
        home: WorkspaceSelectorScreen(
          workspaces: workspaces,
          rootFolderId: 'root123',
        ),
      ),
    );
  }

  testWidgets('WorkspaceSelectorScreen shows empty state when no workspaces', (WidgetTester tester) async {
    await tester.pumpWidget(createWorkspaceSelector([]));

    expect(find.text('No workspaces found.\nCreate one to get started.'), findsOneWidget);
    expect(find.text('CREATE OR JOIN NEW WORKSPACE'), findsOneWidget);
  });

  testWidgets('WorkspaceSelectorScreen lists available workspaces', (WidgetTester tester) async {
    final workspaces = [
      drive.File()..id = 'ws1'..name = 'Company A',
      drive.File()..id = 'ws2'..name = 'Company B',
    ];

    await tester.pumpWidget(createWorkspaceSelector(workspaces));

    expect(find.text('Company A'), findsOneWidget);
    expect(find.text('Company B'), findsOneWidget);
  });

  testWidgets('WorkspaceSelectorScreen sets workspace and navigates', (WidgetTester tester) async {
    final workspaces = [
      drive.File()..id = 'ws1'..name = 'Company A',
    ];

    await tester.pumpWidget(createWorkspaceSelector(workspaces));

    await tester.tap(find.text('Company A'));
    await tester.pumpAndSettle();

    verify(() => mockWorkspaceProvider.setWorkspace(any())).called(1);
    // Should navigate to Dashboard (check for KPI label again)
    expect(find.text('NET PROFIT ENGINE'), findsOneWidget);
  });
}
