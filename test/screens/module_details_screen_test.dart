import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:drivererpapp/screens/module_details_screen.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';

class MockDriveProvider extends Mock implements DriveProvider {}
class MockDriveService extends Mock implements DriveService {}
class MockWorkspaceProvider extends Mock implements WorkspaceProvider {}

void main() {
  late MockDriveProvider mockDriveProvider;
  late MockDriveService mockDriveService;
  late MockWorkspaceProvider mockWorkspaceProvider;
  late drive.File workspaceFile;

  setUp(() {
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();
    mockWorkspaceProvider = MockWorkspaceProvider();

    workspaceFile = drive.File()..id = 'ws1'..name = 'Test WS';

    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockWorkspaceProvider.currentWorkspace).thenReturn(workspaceFile);
    when(() => mockDriveService.listModules(any())).thenAnswer((_) async => []);
  });

  testWidgets('ModuleDetailsScreen activates module and navigates to Dashboard', (WidgetTester tester) async {
    final moduleInfo = {'name': 'Inventory', 'icon': 'inventory', 'color': '#F59E0B', 'desc': 'Stock & Warehouse'};

    when(() => mockDriveService.createWorkspace(any(), any())).thenAnswer((_) async => drive.File()..id = 'created'..name = 'created');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
          ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
        ],
        child: const MaterialApp(
          home: SizedBox.shrink(),
        ),
      ),
    );

    // Push ModuleDetailsScreen onto navigator
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
          ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
        ],
        child: MaterialApp(
          home: ModuleDetailsScreen(moduleInfo: moduleInfo),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify UI shows module title
    expect(find.text('INVENTORY'), findsOneWidget);

    // Tap Activate
    final activate = find.text('ACTIVATE');
    expect(activate, findsOneWidget);
    await tester.tap(activate);

    // Allow async work
    await tester.pumpAndSettle();

    // After activation, DashboardScreen is pushed; check for KPI label
    expect(find.text('NET PROFIT ENGINE'), findsOneWidget);
    verify(() => mockDriveService.createWorkspace('ws1', 'Inventory')).called(1);
  });
}
