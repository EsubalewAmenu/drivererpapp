import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/module_screen.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';

class MockDriveProvider extends Mock implements DriveProvider {}
class MockDriveService extends Mock implements DriveService {}

void main() {
  late MockDriveProvider mockDriveProvider;
  late MockDriveService mockDriveService;
  late ModuleSchema testModule;

  setUp(() {
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();

    testModule = ModuleSchema(
      id: 'module123',
      name: 'Inventory',
      icon: 'inventory',
      primaryColor: '#F59E0B',
      version: '1.0.0',
      settings: {},
      tabs: [
        TabConfig(id: 'items', label: 'Items', columns: []),
      ],
      dashboard: DashboardConfig(kpiCards: []),
    );

    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    // Common stubs to avoid Null subtype errors
    when(() => mockDriveService.fetchRecords(any(), any(), any())).thenAnswer((_) async => []);
  });

  Widget createModuleScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
      ],
      child: MaterialApp(
        home: ModuleScreen(module: testModule),
      ),
    );
  }

  testWidgets('ModuleScreen should show loading state initially', (WidgetTester tester) async {
    // Stub getFileId to return a long-running future
    final completer = Completer<String?>();
    when(() => mockDriveService.getFileId(any(), any())).thenAnswer((_) => completer.future);

    await tester.pumpWidget(createModuleScreen());
    await tester.pump(); // Start the future
    
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    
    // Clean up
    completer.complete(null);
    await tester.pump(); // Process completion
    await tester.pump(const Duration(milliseconds: 100)); // Process any follow-up steps
  });

  testWidgets('ModuleScreen should show tabs after loading schema', (WidgetTester tester) async {
    // Stub getFileId to return a fake ID (avoids asset fallback)
    when(() => mockDriveService.getFileId(any(), any())).thenAnswer((_) async => 'config123');
    when(() => mockDriveService.readModuleConfig(any())).thenAnswer((_) async => {
      'settings': {'name': {'value': 'Inventory'}},
      'dashboard': {'kpiCards': []},
      'tabs': [
        {'id': 'items', 'label': 'Items', 'columns': []}
      ]
    });

    await tester.pumpWidget(createModuleScreen());
    await tester.pumpAndSettle();

    expect(find.text('INVENTORY'), findsOneWidget);
    expect(find.text('DASHBOARD'), findsOneWidget);
    expect(find.text('ITEMS'), findsOneWidget);
  });
}
