import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/module_configuration_screen.dart';
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

    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    
    final mockWorkspace = MockDriveFile();
    when(() => mockWorkspace.id).thenReturn('ws123');
    when(() => mockWorkspace.name).thenReturn('Test Workspace');
    
    when(() => mockWorkspaceProvider.currentWorkspace).thenReturn(mockWorkspace);
    when(() => mockWorkspaceProvider.isLoading).thenReturn(false);

    // Mock for DashboardScreen which is navigated to after activation
    when(() => mockDriveService.listModules(any())).thenAnswer((_) async => []);
  });

  Widget createConfigScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
      ],
      child: const MaterialApp(
        home: ModuleConfigurationScreen(
          moduleInfo: {
            'name': 'CRM',
            'icon': 'people',
            'desc': 'Customer Relationship Management',
            'color': '#3B82F6'
          },
        ),
      ),
    );
  }

  testWidgets('ModuleConfigurationScreen renders and activates', (WidgetTester tester) async {
    await tester.pumpWidget(createConfigScreen());
    await tester.pump(); 
    await tester.pumpAndSettle();

    expect(find.text('CONFIGURE CRM'), findsOneWidget);
    
    // crm.json has "settings" -> "name" -> "label": "Name"
    expect(find.text('NAME'), findsOneWidget);

    // Mock activation
    final moduleFolder = MockDriveFile();
    when(() => moduleFolder.id).thenReturn('folder123');
    when(() => mockDriveService.createWorkspace(any(), any()))
        .thenAnswer((_) async => moduleFolder);

    // Tap COMPLETE SETUP
    await tester.tap(find.text('COMPLETE SETUP'));
    
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    
    verify(() => mockDriveService.createWorkspace('ws123', 'CRM')).called(1);
    expect(find.text('CRM activated successfully!'), findsOneWidget);
  });

  testWidgets('ModuleConfigurationScreen handles activation error', (WidgetTester tester) async {
    await tester.pumpWidget(createConfigScreen());
    await tester.pumpAndSettle();

    when(() => mockDriveService.createWorkspace(any(), any()))
        .thenThrow(Exception('Drive error'));

    await tester.tap(find.text('COMPLETE SETUP'));
    await tester.pumpAndSettle();

    expect(find.text('Error activating module: Exception: Drive error'), findsOneWidget);
  });

  testWidgets('ModuleConfigurationScreen handles missing services', (WidgetTester tester) async {
    when(() => mockWorkspaceProvider.currentWorkspace).thenReturn(null);
    
    await tester.pumpWidget(createConfigScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('COMPLETE SETUP'));
    await tester.pumpAndSettle();

    expect(find.text('Error activating module: Exception: Drive Service or Workspace missing'), findsOneWidget);
  });

  testWidgets('ModuleConfigurationScreen handles config loading failure', (WidgetTester tester) async {
    // We can't easily mock DefaultAssetBundle in a simple widget test without more boilerplate,
    // but the code already has a try-catch that falls back to defaults.
    // The current CRM test already covers the success case.
    
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
      ],
      child: const MaterialApp(
        home: ModuleConfigurationScreen(
          moduleInfo: {
            'name': 'NonExistent',
            'color': '#000000'
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();
    
    expect(find.text('CONFIGURE NONEXISTENT'), findsOneWidget);
    // Should fallback to showing name field
    expect(find.text('NAME'), findsOneWidget);
  });
}
