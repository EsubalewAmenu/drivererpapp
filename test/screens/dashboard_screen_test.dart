import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/dashboard_screen.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class MockDriveProvider extends Mock implements DriveProvider {}
class MockWorkspaceProvider extends Mock implements WorkspaceProvider {}
class MockDriveService extends Mock implements DriveService {}
class MockDriveFile extends Mock implements drive.File {}

void main() {
  late MockDriveProvider mockDriveProvider;
  late MockWorkspaceProvider mockWorkspaceProvider;
  late MockDriveService mockDriveService;

  setUp(() {
    mockDriveProvider = MockDriveProvider();
    mockWorkspaceProvider = MockWorkspaceProvider();
    mockDriveService = MockDriveService();

    final workspaceFile = MockDriveFile();
    when(() => workspaceFile.id).thenReturn('ws123');
    when(() => workspaceFile.name).thenReturn('Test Workspace');

    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockWorkspaceProvider.currentWorkspace).thenReturn(workspaceFile);
    when(() => mockWorkspaceProvider.isLoading).thenReturn(false);
  });

  Widget createDashboardScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
      ],
      child: const MaterialApp(
        home: DashboardScreen(),
      ),
    );
  }

  testWidgets('DashboardScreen renders KPIs and modules', (WidgetTester tester) async {
    final mockFile = MockDriveFile();
    when(() => mockFile.name).thenReturn('HR');
    when(() => mockFile.id).thenReturn('mod123');

    when(() => mockDriveService.listModules('ws123'))
        .thenAnswer((_) async => [mockFile]);

    await tester.pumpWidget(createDashboardScreen());
    await tester.pump(); 
    await tester.pump(); 

    expect(find.text('TEST WORKSPACE'), findsOneWidget);
    expect(find.text('NET PROFIT ENGINE'), findsOneWidget);
    expect(find.text('CORE MODULES'), findsOneWidget);
    
    expect(find.text('HR'), findsAtLeastNWidgets(1));
  });

  testWidgets('DashboardScreen period selection changes KPIs', (WidgetTester tester) async {
    when(() => mockDriveService.listModules(any()))
        .thenAnswer((_) async => []);

    await tester.pumpWidget(createDashboardScreen());
    await tester.pumpAndSettle();

    // Default is Today: Profit = 1250 - 450 = 800.00
    expect(find.text(r'$800.00'), findsOneWidget);

    // Change to Week: 8500 - 3200 = 5300
    await tester.tap(find.text('TODAY'));
    await tester.pumpAndSettle();
    
    await tester.tap(find.text('WEEK').last);
    await tester.pumpAndSettle();

    expect(find.text(r'$5300.00'), findsOneWidget);
  });
}
