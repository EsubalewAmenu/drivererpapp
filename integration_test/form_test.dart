import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/screens/module_screen.dart';

class MockDriveProvider extends Mock implements DriveProvider {}
class MockDriveService extends Mock implements DriveService {}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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
        TabConfig(
          id: 'items',
          label: 'Items',
          columns: [
            ColumnConfig(key: 'name', label: 'Item Name', type: 'text', isRequired: true),
            ColumnConfig(key: 'qty', label: 'Quantity', type: 'number'),
          ],
        ),
      ],
      dashboard: DashboardConfig(kpiCards: []),
    );

    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockDriveService.getFileId(any(), any())).thenAnswer((_) async => null);
    when(() => mockDriveService.fetchRecords(any(), any(), any())).thenAnswer((_) async => []);
  });

  Widget createTestApp() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
      ],
      child: MaterialApp(
        home: ModuleScreen(module: testModule),
      ),
    );
  }

  testWidgets('Form Submission Flow: Module -> New Record -> Save', (tester) async {
    await tester.pumpWidget(createTestApp());
    await tester.pumpAndSettle();

    // 1. Go to Items Tab
    await tester.tap(find.text('ITEMS'));
    await tester.pumpAndSettle();

    // 2. Tap Add FAB
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    // 3. Fill Form
    await tester.enterText(find.byType(TextFormField).first, 'Samosa');
    await tester.enterText(find.byType(TextFormField).last, '50');

    // 4. Save
    when(() => mockDriveService.saveRecord(any(), any(), any(), any()))
        .thenAnswer((_) async => {});

    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    // 5. Verify saveRecord called
    verify(() => mockDriveService.saveRecord(
      'module123',
      'Inventory',
      'items',
      any(that: containsPair('name', 'Samosa')),
    )).called(1);

    // 6. Verify back on list screen
    expect(find.text('INVENTORY'), findsOneWidget);
  });
}
