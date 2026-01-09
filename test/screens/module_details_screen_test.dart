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
import 'dart:convert';
import 'package:flutter/services.dart';

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

  testWidgets('ModuleDetailsScreen handles activation error', (WidgetTester tester) async {
    final info = {
      'name': 'CRM',
      'desc': 'Customer Management',
      'icon': 'people',
      'color': '#3B82F6',
    };

    when(() => mockDriveService.createWorkspace(any(), any()))
        .thenThrow(Exception('Creation failed'));

    await tester.pumpWidget(createModuleDetailsScreen(info));

    await tester.tap(find.text('ACTIVATE'));
    await tester.pumpAndSettle();

    expect(find.text('Error activating module: Exception: Creation failed'), findsOneWidget);
    expect(find.text('ACTIVATE'), findsOneWidget); // Toggle back
  });

  testWidgets('ModuleDetailsScreen handles missing auth/workspace', (WidgetTester tester) async {
    final info = {
      'name': 'CRM',
      'desc': 'Customer Management',
      'icon': 'people',
      'color': '#3B82F6',
    };

    when(() => mockDriveProvider.driveService).thenReturn(null);

    await tester.pumpWidget(createModuleDetailsScreen(info));

    await tester.tap(find.text('ACTIVATE'));
    await tester.pumpAndSettle();

    expect(find.text('Error activating module: Exception: Authentication or Workspace missing'), findsOneWidget);
  });

  testWidgets('ModuleDetailsScreen seeds initial data during activation', (WidgetTester tester) async {
    final info = {
      'name': 'Inventory',
      'desc': 'Stock Management',
      'icon': 'inventory',
      'color': '#3B82F6',
    };

    // Mock asset loading
    final moduleJson = {
      'tabs': [
        {
          'id': 't1',
          'initial_data': [
            {'name': 'Item 1'},
            {'name': 'Item 2'},
          ]
        }
      ]
    };
    
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (ByteData? message) async {
        final Uint8List list = utf8.encoder.convert(jsonEncode(moduleJson));
        return list.buffer.asByteData();
      },
    );

    when(() => mockDriveService.createWorkspace(any(), any()))
        .thenAnswer((_) async => drive.File()..id = 'mod123');
    when(() => mockDriveService.saveRecord(any(), any(), any(), any()))
        .thenAnswer((_) async => drive.File());
    when(() => mockDriveService.listModules(any())).thenAnswer((_) async => []);

    await tester.pumpWidget(createModuleDetailsScreen(info));
    await tester.pumpAndSettle(); // Load config

    await tester.tap(find.text('ACTIVATE'));
    await tester.pumpAndSettle();
    
    verify(() => mockDriveService.saveRecord('mod123', 'Inventory', 't1', any())).called(2);
    expect(find.byType(DashboardScreen), findsOneWidget);
    
    // Cleanup mock handler
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', null);
  });

  testWidgets('ModuleDetailsScreen handles unknown module and icon defaults', (tester) async {
    final info = {
      'name': 'Custom Module',
      'desc': 'Description',
      'icon': 'unknown_icon_123',
      'color': '#3B82F6',
    };

    // Mock asset loading with unknown icon
    final moduleJson = {
      'icon': 'unknown_icon_123',
      'tabs': []
    };
    
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (ByteData? message) async {
        final Uint8List list = utf8.encoder.convert(jsonEncode(moduleJson));
        return list.buffer.asByteData();
      },
    );

    await tester.pumpWidget(createModuleDetailsScreen(info));
    await tester.pumpAndSettle();

    expect(find.text('CUSTOM MODULE'), findsOneWidget);
    // Should show default pros
    expect(find.text('Streamlined Workflow'), findsOneWidget);
    
    // Cleanup mock handler
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', null);
  });
}
