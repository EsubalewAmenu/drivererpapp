import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/common/history_dialog.dart';
import 'package:drivererpapp/screens/module_screen.dart';
import 'package:drivererpapp/screens/schema_editor_screen.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/services/schema_service.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:googleapis/drive/v3.dart' as drive;

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
      dashboard: DashboardConfig(cards: []),
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
      dashboard: DashboardConfig(cards: [DashboardCard(label: 'Stock', formula: 'SUM(qty)', format: 'number')]),
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
    when(() => mockDriveService.getFileRevisions(any())).thenAnswer((_) async => []);
  });

  Widget createModuleScreen({ModuleSchema? module}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ChangeNotifierProvider<SchemaProvider>.value(value: mockSchemaProvider),
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
      ],
      child: MaterialApp(
        home: ModuleScreen(module: module ?? testModule),
      ),
    );
  }

  Future<void> settleDashboard(WidgetTester tester) async {
    await tester.pumpAndSettle();
    // ModuleDashboard has a 300ms timer in initState
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  group('ModuleScreen', () {
    testWidgets('shows loading state initially', (WidgetTester tester) async {
      when(() => mockSchemaService.syncConfig(any())).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return fullModule.toJson();
      });

      await tester.pumpWidget(createModuleScreen());
      await tester.pump();
      
      expect(find.text('LOADING BLUEPRINT...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      // Wait for sync to complete
      await tester.pumpAndSettle();
      // Wait for Dashboard timer
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
    });

    testWidgets('loads and renders dashboard and tabs', (WidgetTester tester) async {
      await tester.pumpWidget(createModuleScreen());
      await settleDashboard(tester);

      expect(find.text('INVENTORY'), findsAtLeastNWidgets(1));
      expect(find.text('DASHBOARD'), findsOneWidget);
      expect(find.text('ITEMS'), findsOneWidget);

      expect(find.text('PERFORMANCE OVERVIEW'), findsOneWidget);
      expect(find.text('STOCK'), findsOneWidget);
    });

    testWidgets('switches to tab and shows list', (WidgetTester tester) async {
      await tester.pumpWidget(createModuleScreen());
      await settleDashboard(tester);

      await tester.tap(find.text('ITEMS'));
      // ModuleTabScreen might have animations or simple loading
      await tester.pumpAndSettle();
      
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('navigates to SchemaEditorScreen', (WidgetTester tester) async {
      await tester.pumpWidget(createModuleScreen());
      await settleDashboard(tester);

      final editButton = find.byTooltip('Edit Blueprint');
      expect(editButton, findsOneWidget);
      
      await tester.tap(editButton);
      await tester.pumpAndSettle();
      
      expect(find.byType(SchemaEditorScreen), findsOneWidget);
      expect(find.text('BLUEPRINT EDITOR'), findsOneWidget);
    });

    testWidgets('opens History Dialog', (WidgetTester tester) async {
      await tester.pumpWidget(createModuleScreen());
      await settleDashboard(tester);

      final historyButton = find.byTooltip('Version History');
      expect(historyButton, findsOneWidget);
      
      await tester.tap(historyButton);
      await tester.pumpAndSettle();
      
      expect(find.byType(HistoryDialog), findsOneWidget);
      expect(find.text('File History'), findsOneWidget); 
    });
  });
}
