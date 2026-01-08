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

  testWidgets('ModuleConfigurationScreen renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(createConfigScreen());
    await tester.pump(); 
    await tester.pumpAndSettle();

    expect(find.text('CONFIGURE CRM'), findsOneWidget);
    expect(find.text('Customize your module'), findsOneWidget);
    expect(find.text('COMPLETE SETUP'), findsOneWidget);
  });
}
