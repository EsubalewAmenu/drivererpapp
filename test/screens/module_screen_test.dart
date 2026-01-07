import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/module_screen.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockDriveProvider extends Mock implements DriveProvider {}
class MockDriveService extends Mock implements DriveService {}

void main() {
  late MockDriveProvider mockDriveProvider;
  late MockDriveService mockDriveService;
  late ModuleSchema testModule;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();

    testModule = ModuleSchema(
      id: 'module123',
      name: 'Inventory',
      icon: 'inventory',
      primaryColor: '#F59E0B',
      version: '1.0.0',
      settings: {},
      tabs: [], // Initial empty tabs to trigger blueprint loading UI
      dashboard: DashboardConfig(kpiCards: []),
    );

    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockDriveService.fetchRecords(any(), any(), any())).thenAnswer((_) async => []);
    when(() => mockDriveService.getFileId(any(), any())).thenAnswer((_) async => 'f123');
    when(() => mockDriveService.readModuleConfig(any())).thenAnswer((_) async => testModule.toJson());
    when(() => mockDriveService.getFileModifiedTime(any())).thenAnswer((_) async => DateTime.now());
  });

  Widget createModuleScreen({ModuleSchema? module}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ChangeNotifierProvider<SchemaProvider>(create: (_) => SchemaProvider(driveService: mockDriveService)),
      ],
      child: MaterialApp(
        home: ModuleScreen(module: module ?? testModule),
      ),
    );
  }

  testWidgets('ModuleScreen should show blueprint loading state when tabs are empty', (WidgetTester tester) async {
    when(() => mockDriveService.getFileId(any(), any())).thenAnswer((_) => Completer<String?>().future);

    await tester.pumpWidget(createModuleScreen());
    await tester.pump(); 
    
    expect(find.text('LOADING BLUEPRINT...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('ModuleScreen should show dashboard cards in loading state', (WidgetTester tester) async {
    final fullModule = ModuleSchema(
      id: 'module123',
      name: 'Inventory',
      icon: 'inventory',
      primaryColor: '#F59E0B',
      version: '1.0.0',
      settings: {},
      tabs: [TabConfig(id: 'items', label: 'Items', columns: [])],
      dashboard: DashboardConfig(kpiCards: [KpiCard(label: 'Stock', calculation: 'SUM(qty)', format: 'number')]),
    );

    when(() => mockDriveService.getFileId(any(), 'config')).thenAnswer((_) async => 'conf123');
    when(() => mockDriveService.readModuleConfig('conf123')).thenAnswer((_) async => fullModule.toJson());
    
    // Make record fetching hang so cards stay in loading state
    final labelsCompleter = Completer<List<Map<String, dynamic>>>();
    when(() => mockDriveService.fetchRecords(any(), any(), any())).thenAnswer((_) => labelsCompleter.future);

    await tester.pumpWidget(createModuleScreen());
    
    // Process Blueprint loading
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('INVENTORY'), findsAtLeastNWidgets(1));
    expect(find.text('PERFORMANCE OVERVIEW'), findsOneWidget);
    expect(find.text('STOCK'), findsOneWidget);
    
    // Should show the loading placeholder
    expect(find.text('---'), findsOneWidget);
    
    // Clean up
    labelsCompleter.complete([]);
    await tester.pump(const Duration(milliseconds: 500));
  });
}
