import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/dynamic_form/fields/relation_field.dart';
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
      icon: 'icon',
      primaryColor: '#000000',
      version: '1',
      settings: {},
      tabs: [
        TabConfig(id: 'users', label: 'Users', columns: [
          ColumnConfig(key: 'name', label: 'Name', type: 'text')
        ]),
      ],
      dashboard: DashboardConfig(kpiCards: []),
    );

    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
  });

  testWidgets('DynamicRelationField fetching items', (WidgetTester tester) async {
    final column = ColumnConfig(
      key: 'user',
      label: 'User',
      type: 'relation',
      options: 'users', // Refers to 'users' tab
    );

    // Mock response
    when(() => mockDriveService.fetchRecords(any(), any(), 'users'))
        .thenAnswer((_) async => [
              {'name': 'John Doe'},
              {'name': 'Jane Doe'},
            ]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DynamicRelationField(
              column: column,
              value: null,
              module: testModule,
              onChanged: (_) {},
              data: {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('USER'), findsOneWidget);

    // Tap to open
    await tester.tap(find.byType(InkWell));
    await tester.pump(); // Start loading
    await tester.pump(const Duration(milliseconds: 500)); // Wait for snackbar? Or just pumpSettle
    await tester.pumpAndSettle();

    // Check if dialog is open with items
    expect(find.text('Select Users'), findsOneWidget);
    expect(find.text('John Doe'), findsOneWidget);
    expect(find.text('Jane Doe'), findsOneWidget);
  });
}
