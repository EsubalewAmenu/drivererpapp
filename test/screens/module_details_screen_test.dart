import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/module_details_screen.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/screens/dashboard_screen.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class MockDriveProvider extends Mock implements DriveProvider {}
class MockWorkspaceProvider extends Mock implements WorkspaceProvider {}
class MockDriveService extends Mock implements DriveService {}

void main() {
  late MockDriveProvider mockDriveProvider;
  late MockWorkspaceProvider mockWorkspaceProvider;
  late MockDriveService mockDriveService;

  setUp(() {
    mockDriveProvider = MockDriveProvider();
    mockWorkspaceProvider = MockWorkspaceProvider();
    mockDriveService = MockDriveService();
    
    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockWorkspaceProvider.currentWorkspace).thenReturn(drive.File()..id = 'ws123'..name = 'My Workspace');
    when(() => mockWorkspaceProvider.loadCompanies(any())).thenAnswer((_) async {});
  });

  Widget createModuleDetailsScreen(Map<String, String> info) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
      ],
      child: MaterialApp(
        home: ModuleDetailsScreen(moduleInfo: info),
      ),
    );
  }

  testWidgets('ModuleDetailsScreen displays module info', (WidgetTester tester) async {
    final info = {
      'name': 'CRM',
      'desc': 'Customer Management',
      'icon': 'people',
      'color': '#3B82F6',
    };
    
    await tester.pumpWidget(createModuleDetailsScreen(info));

    expect(find.text('CRM'), findsOneWidget);
    expect(find.text('Customer Management'), findsOneWidget);
    expect(find.text('ACTIVATE'), findsOneWidget);
  });

  testWidgets('ModuleDetailsScreen activates module', (WidgetTester tester) async {
    final info = {
      'name': 'CRM',
      'desc': 'Customer Management',
      'icon': 'people',
      'color': '#3B82F6',
    };

    when(() => mockDriveService.createWorkspace(any(), any()))
        .thenAnswer((_) async => drive.File()..id = 'mod123');
    when(() => mockDriveService.listModules(any())).thenAnswer((_) async => []);

    await tester.pumpWidget(createModuleDetailsScreen(info));

    await tester.tap(find.text('ACTIVATE'));
    await tester.pump();
    
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    
    await tester.pumpAndSettle();
    
    verify(() => mockDriveService.createWorkspace('ws123', 'CRM')).called(1);
    expect(find.byType(DashboardScreen), findsOneWidget);
  });
}
