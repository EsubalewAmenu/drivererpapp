import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/module_screen.dart';
import 'package:drivererpapp/screens/schema_editor_screen.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/services/schema_service.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockDriveProvider extends Mock implements DriveProvider {}
class MockDriveService extends Mock implements DriveService {}
class MockSchemaProvider extends Mock implements SchemaProvider {}
class MockSchemaService extends Mock implements SchemaService {}
class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockDriveProvider mockDriveProvider;
  late MockDriveService mockDriveService;
  late MockSchemaProvider mockSchemaProvider;
  late MockSchemaService mockSchemaService;
  late MockAuthService mockAuthService;
  late ModuleSchema testModule;
  late ModuleSchema fullModule;

  setUpAll(() {
    registerFallbackValue(drive.File());
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();
    mockSchemaProvider = MockSchemaProvider();
    mockSchemaService = MockSchemaService();
    mockAuthService = MockAuthService();

    testModule = ModuleSchema(
      id: 'module123',
      name: 'Inventory',
      icon: 'inventory',
      primaryColor: '#F59E0B',
      version: '1.0.0',
      settings: {},
      tabs: [], // Initial empty tabs
      dashboard: DashboardConfig(kpiCards: []),
    );

    fullModule = ModuleSchema(
      id: 'module123',
      name: 'Inventory',
      icon: 'inventory',
      primaryColor: '#F59E0B',
      version: '1.0.0',
      settings: {},
      tabs: [TabConfig(id: 'items', label: 'Items', columns: [
        ColumnConfig(key: 'name', label: 'Name', type: 'text')
      ])],
      dashboard: DashboardConfig(kpiCards: [KpiCard(label: 'Stock', calculation: 'SUM(qty)', format: 'number')]),
    );

    // Default connection
    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockSchemaProvider.service).thenReturn(mockSchemaService);
    
    // Default Schema Loading behavior
    when(() => mockSchemaProvider.getFromMemory(any())).thenReturn(null);
    when(() => mockSchemaService.getCachedConfig(any())).thenAnswer((_) async => null);
    when(() => mockSchemaService.syncConfig(any())).thenAnswer((_) async => fullModule.toJson());
    
    // Drive Service defaults
    when(() => mockDriveService.fetchRecords(any(), any(), any())).thenAnswer((_) async => []);
    when(() => mockDriveService.getFileId(any(), any())).thenAnswer((_) async => 'f123');
    when(() => mockDriveService.getFileModifiedTime(any())).thenAnswer((_) async => DateTime.now());
  });

  Widget createModuleScreen({ModuleSchema? module}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ChangeNotifierProvider<SchemaProvider>.value(value: mockSchemaProvider),
        Provider<AuthService>.value(value: mockAuthService), // For ModuleTabScreen -> RecordDetailScreen maybe?
      ],
      child: MaterialApp(
        home: ModuleScreen(module: module ?? testModule),
      ),
    );
  }

  group('ModuleScreen', () {
    testWidgets('shows loading state initially', (WidgetTester tester) async {
      // Delay sync to show loading
      when(() => mockSchemaService.syncConfig(any())).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return fullModule.toJson();
      });

      await tester.pumpWidget(createModuleScreen());
      await tester.pump(); // Start Init
      
      expect(find.text('LOADING BLUEPRINT...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      await tester.pumpAndSettle(); // Resolve
    });

    testWidgets('loads and renders dashboard and tabs', (WidgetTester tester) async {
      await tester.pumpWidget(createModuleScreen());
      await tester.pumpAndSettle();

      expect(find.text('INVENTORY'), findsAtLeastNWidgets(1));
      expect(find.text('DASHBOARD'), findsOneWidget); // Tab Label
      expect(find.text('ITEMS'), findsOneWidget); // Tab Label

      expect(find.text('PERFORMANCE OVERVIEW'), findsOneWidget);
      expect(find.text('STOCK'), findsOneWidget);
    });

    testWidgets('switches to tab and shows list', (WidgetTester tester) async {
      await tester.pumpWidget(createModuleScreen());
      await tester.pumpAndSettle();

      // Tap Items Tab
      await tester.tap(find.text('ITEMS'));
      await tester.pumpAndSettle();
      
      // Should show empty list message or headers
      // Since fetchRecords returns [], it depends on ModuleTabScreen implementation
      // Assuming it shows "No records found" or just the list view
      // We can check if floating action button is visible which suggests list view
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('navigates to SchemaEditorScreen', (WidgetTester tester) async {
      await tester.pumpWidget(createModuleScreen());
      await tester.pumpAndSettle();

      final editButton = find.byTooltip('Edit Blueprint');
      expect(editButton, findsOneWidget);
      
      await tester.tap(editButton);
      await tester.pumpAndSettle();
      
      expect(find.byType(SchemaEditorScreen), findsOneWidget);
      expect(find.text('BLUEPRINT EDITOR'), findsOneWidget);
    });

    // testWidgets('opens History Dialog', (WidgetTester tester) async {
    //   await tester.pumpWidget(createModuleScreen());
    //   await tester.pumpAndSettle();

    //   final historyButton = find.byTooltip('Version History');
    //   expect(historyButton, findsOneWidget);
      
    //   await tester.tap(historyButton);
    //   await tester.pumpAndSettle();
      
    //   // This might fail if HistoryDialog needs specific setup or mocks we missed
    //   // But we can check if a Dialog appeared
    //   expect(find.text('Version History'), findsOneWidget); 
    // });
  });
}
