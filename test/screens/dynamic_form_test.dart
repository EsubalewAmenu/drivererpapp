import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/dynamic_form_screen.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';

class MockDriveProvider extends Mock implements DriveProvider {}
class MockDriveService extends Mock implements DriveService {}

void main() {
  late MockDriveProvider mockDriveProvider;
  late MockDriveService mockDriveService;
  late TabConfig testTab;
  late ModuleSchema testModule;

  setUp(() {
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();

    testTab = TabConfig(
      id: 'items',
      label: 'Items',
      columns: [
        ColumnConfig(key: 'name', label: 'Name', type: 'text', isRequired: true),
        ColumnConfig(key: 'qty', label: 'Quantity', type: 'number'),
      ],
    );

    testModule = ModuleSchema(
      id: 'module123',
      name: 'Inventory',
      icon: 'inventory',
      primaryColor: '#F59E0B',
      version: '1.0.0',
      settings: {},
      tabs: [testTab],
      dashboard: DashboardConfig(kpiCards: []),
    );

    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
  });

  Widget createDynamicFormScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
      ],
      child: MaterialApp(
        home: DynamicFormScreen(
          tab: testTab,
          primaryColor: Colors.amber,
          module: testModule,
        ),
      ),
    );
  }

  testWidgets('DynamicFormScreen should render fields', (WidgetTester tester) async {
    await tester.pumpWidget(createDynamicFormScreen());

    expect(find.text('NAME'), findsOneWidget);
    expect(find.text('QUANTITY'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('DynamicFormScreen should show validation error for required field', (WidgetTester tester) async {
    await tester.pumpWidget(createDynamicFormScreen());

    final saveButton = find.text('SAVE');
    await tester.tap(saveButton);
    await tester.pump();

    expect(find.text('This field is required'), findsOneWidget);
  });

  testWidgets('DynamicFormScreen should call saveRecord on valid submission', (WidgetTester tester) async {
    when(() => mockDriveService.saveRecord(any(), any(), any(), any()))
        .thenAnswer((_) async => {});

    await tester.pumpWidget(createDynamicFormScreen());

    await tester.enterText(find.byType(TextFormField).first, 'Test Item');
    await tester.enterText(find.byType(TextFormField).last, '10');

    final saveButton = find.text('SAVE');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    verify(() => mockDriveService.saveRecord(
      any(), 
      any(), 
      any(), 
      any()
    )).called(1);
  });

  testWidgets('DynamicFormScreen loads list field from JSON string', (WidgetTester tester) async {
    final listTab = TabConfig(
      id: 'list_tab',
      label: 'List Tab',
      columns: [
        ColumnConfig(key: 'options', label: 'Options', type: 'list'),
      ],
    );

    // Simulate data coming from Sheet as JSON string
    final encodedList = '["OptionA","OptionB"]';

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        ],
        child: MaterialApp(
          home: DynamicFormScreen(
            tab: listTab,
            primaryColor: Colors.blue,
            module: testModule,
            initialData: {'options': encodedList},
          ),
        ),
      ),
    );

    expect(find.text('OptionA'), findsOneWidget);
    expect(find.text('OptionB'), findsOneWidget);
  });
}
