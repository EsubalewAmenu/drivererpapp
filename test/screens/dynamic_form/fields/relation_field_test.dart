import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/dynamic_form/fields/relation_field.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/providers/schema_provider.dart';

class MockDriveProvider extends Mock implements DriveProvider {}
class MockDriveService extends Mock implements DriveService {}

void main() {
  late MockDriveProvider mockDriveProvider;
  late MockDriveService mockDriveService;
  late SchemaProvider schemaProvider;
  late ModuleSchema testModule;

  setUp(() {
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();
    // Use a real SchemaProvider and preload the test module into its memory cache.
    schemaProvider = SchemaProvider();

    testModule = ModuleSchema(
      id: 'mod1',
      name: 'Test Module',
      icon: 'icon',
      primaryColor: '#000000',
      version: '1',
      settings: {},
      tabs: [
        TabConfig(id: 'users', label: 'Users', columns: [
          ColumnConfig(key: 'name', label: 'Name', type: 'text'),
          ColumnConfig(key: 'dept', label: 'Dept', type: 'text'),
        ]),
      ],
      dashboard: DashboardConfig(cards: []),
    );

    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    schemaProvider.updateMemoryCache(testModule.id, testModule);
  });

  testWidgets('DynamicRelationField fetching and selecting items', (WidgetTester tester) async {
    final column = ColumnConfig(
      key: 'user',
      label: 'User',
      type: 'relation',
      options: 'users', // Refers to 'users' tab
    );

    String? selectedValue;

    // Mock response
    when(() => mockDriveService.fetchRecords(
      any(), 
      any(), 
      'users',
      offset: any(named: 'offset'),
      limit: any(named: 'limit'),
      fetchSubTables: any(named: 'fetchSubTables'),
      descending: any(named: 'descending'),
      searchQuery: any(named: 'searchQuery'),
      quickFilter: any(named: 'quickFilter'),
    )).thenAnswer((_) async => [
      {'name': 'John Doe'},
      {'name': 'Jane Doe'},
    ]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SchemaProvider>.value(value: schemaProvider),
          ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DynamicRelationField(
              column: column,
              value: null,
              module: testModule,
              onChanged: (v) => selectedValue = v,
              data: {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('USER'), findsOneWidget);

    // Tap to open
    await tester.tap(find.byType(InkWell));
    await tester.pump(); 
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Check if dialog is open then type to search (search-first behavior)
    expect(find.text('Search users'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Jo');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    // Check items now appear
    expect(find.text('John Doe'), findsOneWidget);

    // Select John Doe
    await tester.tap(find.text('John Doe'));
    await tester.pumpAndSettle();

    // Check if callback was called and dialog closed
    expect(selectedValue, 'John Doe');
    expect(find.text('Search users'), findsNothing);
  });

  testWidgets('DynamicRelationField dependency filtering', (WidgetTester tester) async {
    final column = ColumnConfig(
      key: 'user',
      label: 'User',
      type: 'relation',
      options: 'users',
      dependsOn: 'selected_dept',
    );

    // Mock response with items from different departments
    when(() => mockDriveService.fetchRecords(
      any(), 
      any(), 
      'users',
      offset: any(named: 'offset'),
      limit: any(named: 'limit'),
      fetchSubTables: any(named: 'fetchSubTables'),
      descending: any(named: 'descending'),
      searchQuery: any(named: 'searchQuery'),
      quickFilter: any(named: 'quickFilter'),
    )).thenAnswer((_) async => [
      {'name': 'Engineer 1', 'selected_dept': 'Engineering'},
      {'name': 'Sales 1', 'selected_dept': 'Sales'},
    ]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SchemaProvider>.value(value: schemaProvider),
          ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DynamicRelationField(
              column: column,
              value: null,
              module: testModule,
              onChanged: (_) {},
              data: {'selected_dept': 'Engineering'},
            ),
          ),
        ),
      ),
    );

    // Tap to open
    await tester.tap(find.byType(InkWell));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Type to search (search-first behavior) then check dependency filter
    await tester.enterText(find.byType(TextField), 'En');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    // Should only see Engineer 1
    expect(find.text('Engineer 1'), findsOneWidget);
    expect(find.text('Sales 1'), findsNothing);
  });

  testWidgets('DynamicRelationField blocked if dependency parent is missing', (WidgetTester tester) async {
    final column = ColumnConfig(
      key: 'user',
      label: 'User',
      type: 'relation',
      options: 'users',
      dependsOn: 'selected_dept',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SchemaProvider>.value(value: schemaProvider),
          ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DynamicRelationField(
              column: column,
              value: null,
              module: testModule,
              onChanged: (_) {},
              data: {}, // Missing selected_dept
            ),
          ),
        ),
      ),
    );

    // Tap should show snackbar and NOT open dialog
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(find.text('Please select a value for selected_dept first'), findsOneWidget);
    expect(find.text('Search users'), findsNothing);
  });
}
