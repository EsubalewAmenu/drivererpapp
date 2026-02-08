import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/module/module_dashboard.dart';
import 'package:fl_chart/fl_chart.dart';
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
      id: 'mod1',
      name: 'Test Module',
      icon: 'inventory',
      primaryColor: '#F59E0B',
      version: '1.0.0',
      settings: {},
      tabs: [],
      dashboard: DashboardConfig(cards: [
        DashboardCard(label: 'Total Sales', formula: '=SUM(sheet1!A:A)', format: 'currency'),
        DashboardCard(label: 'Active Users', formula: '=COUNT(sheet1!B:B)', format: 'number'),
      ]),
    );

    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockDriveService.executeGvizQuery(any(), any(), any()))
        .thenAnswer((_) async => 1000);
    when(() => mockDriveService.executeGvizTableQuery(any(), any(), any()))
      .thenAnswer((_) async => [
          {'ColA': 'Jan', 'ColB': 10},
          {'ColA': 'Feb', 'ColB': 20},
        ]);
  });

  Widget createModuleDashboard({Color primary = Colors.amber}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ModuleDashboard(
            module: testModule,
            primaryColor: primary,
          ),
        ),
      ),
    );
  }

  testWidgets('ModuleDashboard renders performance overview and cards', (WidgetTester tester) async {
    await tester.pumpWidget(createModuleDashboard());

    expect(find.text('PERFORMANCE OVERVIEW'), findsOneWidget);
    expect(find.text('Total Sales'.toUpperCase()), findsOneWidget);
    expect(find.text('Active Users'.toUpperCase()), findsOneWidget);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('1,000'), findsAtLeastNWidgets(1));
  });

  testWidgets('ModuleDashboard displays KPI card and refresh works', (WidgetTester tester) async {
    when(() => mockDriveService.executeGvizQuery(any(), any(), any())).thenAnswer((_) async => 100);

    testModule = ModuleSchema(
      id: 'm2',
      name: 'KPI Module',
      icon: 'analytics',
      primaryColor: '#2196F3',
      version: '1.0',
      settings: {},
      tabs: [],
      dashboard: DashboardConfig(cards: [DashboardCard(label: 'Total', formula: '=SUM(sheet1!A:A)', format: '', type: 'kpi')]),
    );

      await tester.pumpWidget(createModuleDashboard(primary: Colors.blue));
      await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('PERFORMANCE OVERVIEW'), findsOneWidget);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('TOTAL'), findsOneWidget);
    expect(find.textContaining('100'), findsAtLeastNWidgets(1));
  });

  testWidgets('ModuleDashboard renders chart and list cards', (WidgetTester tester) async {
    final chartModule = ModuleSchema(
      id: 'm3',
      name: 'Chart Module',
      icon: 'chart',
      primaryColor: '#10B981',
      version: '1.0',
      settings: {},
      tabs: [],
      dashboard: DashboardConfig(cards: [
        DashboardCard(label: 'Sales Chart', formula: '=CHART(sheet1!A:B)', type: 'bar', format: ''),
        DashboardCard(label: 'Data List', formula: '=CHART(sheet1!A:B)', type: 'list', format: ''),
      ]),
    );

    await tester.pumpWidget(MultiProvider(
      providers: [ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider)],
      child: MaterialApp(home: Scaffold(body: ModuleDashboard(module: chartModule, primaryColor: Colors.green))),
    ));

    // Allow init delay
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));

    // Chart widget should be present for bar type
    expect(find.byType(BarChart), findsOneWidget);
    // DataTable for list type should appear
    expect(find.byType(DataTable), findsOneWidget);
  });

  testWidgets('ModuleDashboard displays progress and alert states', (WidgetTester tester) async {
    when(() => mockDriveService.executeGvizQuery(any(), any(), any())).thenAnswer((_) async => 0.5);

    final progressModule = ModuleSchema(
      id: 'm4',
      name: 'Progress Module',
      icon: 'progress',
      primaryColor: '#EF4444',
      version: '1.0',
      settings: {},
      tabs: [],
      dashboard: DashboardConfig(cards: [
        DashboardCard(label: 'Completion', formula: '=CHART(sheet1!A:B)', type: 'progress', format: ''),
        DashboardCard(label: 'Shortages', formula: '=SUM(sheet1!B:B)', type: 'kpi', format: ''),
      ]),
    );

    when(() => mockDriveService.executeGvizQuery(any(), any(), any())).thenAnswer((inv) async {
      final q = inv.positionalArguments[2] as String;
      if (q.contains('B')) return 5; // shortages >0
      return 0; 
    });

    when(() => mockDriveService.executeGvizTableQuery(any(), any(), any())).thenAnswer((inv) async {
      return [
        {'ColA': 'label', 'ColB': 0.5},
      ];
    });

    await tester.pumpWidget(MultiProvider(
      providers: [ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider)],
      child: MaterialApp(home: Scaffold(body: ModuleDashboard(module: progressModule, primaryColor: Colors.red))),
    ));

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));

    // Progress shows percentage text
    expect(find.textContaining('%'), findsWidgets);
    // Shortages should show warning icon when >0
    expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
  });

  testWidgets('ModuleDashboard renders PieChart and BarChart cards', (WidgetTester tester) async {
    testModule = ModuleSchema(
      id: 'charts',
      name: 'Charts',
      icon: 'analytics',
      primaryColor: '#2196F3',
      version: '1.0',
      settings: {},
      tabs: [],
      dashboard: DashboardConfig(cards: [
        DashboardCard(label: 'Pie', formula: '=CHART(S1!A:B)', format: '', type: 'pie'),
        DashboardCard(label: 'Bar', formula: '=CHART(S2!A:B)', format: '', type: 'bar'),
      ]),
    );

    await tester.pumpWidget(createModuleDashboard());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500)); // Extra for any minor overhead

    expect(find.byType(PieChart), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
  });

  testWidgets('ModuleDashboard handles empty cards list', (WidgetTester tester) async {
    testModule = ModuleSchema(
      id: 'empty',
      name: 'Empty',
      icon: 'analytics',
      primaryColor: '#2196F3',
      version: '1.0',
      settings: {},
      tabs: [],
      dashboard: DashboardConfig(cards: []),
    );

    await tester.pumpWidget(createModuleDashboard());
    await tester.pump(const Duration(milliseconds: 900)); // Clear all timers
    await tester.pump();

    // The header is still there, but no cards. 
    expect(find.text('PERFORMANCE OVERVIEW'), findsOneWidget);
  });
}
