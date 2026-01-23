import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/module/module_dashboard.dart';
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
    await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();

    expect(find.text('PERFORMANCE OVERVIEW'), findsOneWidget);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();

    expect(find.text('TOTAL'), findsOneWidget);
    expect(find.textContaining('100'), findsAtLeastNWidgets(1));
  });
}
