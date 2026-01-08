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
        DashboardCard(label: 'Total Sales', formula: 'SUM(A:A)', format: 'currency'),
        DashboardCard(label: 'Active Users', formula: 'COUNT(B:B)', format: 'number'),
      ]),
    );

    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
  });

  Widget createModuleDashboard() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ModuleDashboard(
            module: testModule,
            primaryColor: Colors.amber,
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

    // Initial state shows placeholder/syncing
    await tester.pump(); // Start animations
    await tester.pump(const Duration(milliseconds: 300)); // Delay in initState
    await tester.pump(); // Final setState

    expect(find.text('Syncing...'), findsAtLeastNWidgets(2));
  });
}
