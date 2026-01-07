import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/dynamic_form/fields/dropdown_field.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';

class MockDriveProvider extends Mock implements DriveProvider {}
class MockDriveService extends Mock implements DriveService {}

void main() {
  late MockDriveProvider mockDriveProvider;
  late MockDriveService mockDriveService;

  setUp(() {
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();
    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
  });

  Widget createField({
    required ColumnConfig column,
    required String? value,
    required Function(String?) onChanged,
    required Map<String, dynamic> data,
    ModuleSchema? module,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: DynamicDropdownField(
            column: column,
            value: value,
            onChanged: onChanged,
            data: data,
            module: module,
          ),
        ),
      ),
    );
  }

  testWidgets('DynamicDropdownField renders static options', (WidgetTester tester) async {
    String? changedValue;
    final column = ColumnConfig(
      key: 'test_dropdown',
      label: 'Test Dropdown',
      type: 'select',
      options: ['Option 1', 'Option 2'],
    );

    await tester.pumpWidget(createField(
      column: column,
      value: null,
      onChanged: (val) => changedValue = val,
      data: {},
    ));

    expect(find.text('TEST DROPDOWN'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    expect(find.text('Option 1').last, findsOneWidget);
    await tester.tap(find.text('Option 1').last);
    await tester.pumpAndSettle();

    expect(changedValue, 'Option 1');
  });

  testWidgets('DynamicDropdownField loads dynamic options based on dependency', (WidgetTester tester) async {
    // Setup Schema
    // Tab 1 (Current) -> has 'parent_rel' (relation to Tab 2) and 'child_select' (depends on parent_rel.options)
    final parentRelCol = ColumnConfig(
      key: 'parent_rel', 
      label: 'Parent', 
      type: 'relation', 
      options: 'tab2_id' // Points to Tab 2
    );
    final childSelectCol = ColumnConfig(
      key: 'child_select', 
      label: 'Child Select', 
      type: 'select', 
      options: 'parent_rel.allowed_values' // Dependency
    );

    final tab1 = TabConfig(id: 'tab1_id', label: 'Tab 1', columns: [parentRelCol, childSelectCol]);
    final tab2 = TabConfig(id: 'tab2_id', label: 'Tab 2', columns: []);
    
    final module = ModuleSchema(
      id: 'test_mod_id', 
      name: 'Test Mod', 
      icon: 'folder',
      primaryColor: '#000000',
      version: '1.0',
      settings: {},
      dashboard: DashboardConfig(cards: []),
      tabs: [tab1, tab2]
    );

    // Setup Data
    final formData = {'parent_rel': 'Parent Item 1'};

    // Setup Mock Response
    when(() => mockDriveService.fetchRecords(any(), any(), 'tab2_id')).thenAnswer((_) async => [
      {'name': 'Parent Item 1', 'allowed_values': '[Alpha, Beta]'},
      {'name': 'Parent Item 2', 'allowed_values': '[Gamma]'},
    ]);

    await tester.pumpWidget(createField(
      column: childSelectCol,
      value: null,
      onChanged: (_) {},
      data: formData,
      module: module,
    ));

    // Should show loading initially? 
    // _loadOptions calls fetchRecords which is async.
    await tester.pump(); // Start future
    await tester.pump(const Duration(milliseconds: 100)); // Advance time

    // Expect loading indicator gone
    expect(find.byType(LinearProgressIndicator), findsNothing);
    // Tap dropdown
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    // Verify options from 'Parent Item 1'
    expect(find.text('Alpha').last, findsOneWidget);
    expect(find.text('Beta').last, findsOneWidget);
    expect(find.text('Gamma'), findsNothing);
  });
}
