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
    Key? key,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: DynamicDropdownField(
            key: key,
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

    final tab1 = TabConfig(id: 'tab1_id', label: 'Tab 1', fileId: 'tab1_sheet', columns: [parentRelCol, childSelectCol]);
    final tab2 = TabConfig(id: 'tab2_id', label: 'Tab 2', fileId: 'tab2_sheet', columns: []);
    
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
    when(() => mockDriveService.fetchRecordsBySpreadsheetId(
      any(),
      'tab2_id',
    )).thenAnswer((_) async => [
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

  testWidgets('DynamicDropdownField updates label based on dynamicLabel config', (WidgetTester tester) async {
    final parentRelCol = ColumnConfig(
      key: 'parent_rel', 
      label: 'Parent', 
      type: 'relation', 
      options: 'tab2_id'
    );
    final childSelectCol = ColumnConfig(
      key: 'child_select', 
      label: 'Child Select', 
      type: 'select', 
      options: 'parent_rel.allowed_values',
      dynamicLabel: 'parent_rel.custom_label'
    );

    final tab1 = TabConfig(id: 'tab1_id', label: 'Tab 1', fileId: 'tab1_sheet', columns: [parentRelCol, childSelectCol]);
    final tab2 = TabConfig(id: 'tab2_id', label: 'Tab 2', fileId: 'tab2_sheet', columns: []);
    
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

    when(() => mockDriveService.fetchRecordsBySpreadsheetId(any(), 'tab2_id'))
        .thenAnswer((_) async => [
          {'name': 'Parent Item 1', 'custom_label': 'Category Selector', 'allowed_values': '[A, B]'},
        ]);

    await tester.pumpWidget(createField(
      column: childSelectCol,
      value: null,
      onChanged: (_) {},
      data: {'parent_rel': 'Parent Item 1'},
      module: module,
    ));

    await tester.pumpAndSettle();

    expect(find.text('CATEGORY SELECTOR'), findsOneWidget);
  });

  testWidgets('DynamicDropdownField handles dependent visibility', (WidgetTester tester) async {
    final parentRelCol = ColumnConfig(
      key: 'parent_rel', 
      label: 'Parent', 
      type: 'relation', 
      options: 'tab2_id'
    );
    // Tab 2 has a column 'is_active' which child depends on
    final childSelectCol = ColumnConfig(
      key: 'child_select', 
      label: 'Child Select', 
      type: 'select', 
      options: 'parent_rel.allowed_values',
    );

    final tab1 = TabConfig(id: 'tab1_id', label: 'Tab 1', fileId: 'tab1_sheet', columns: [parentRelCol, childSelectCol]);
    // Define Tab 2 structure where 'allowed_values' depends on 'is_active'
    final tab2 = TabConfig(id: 'tab2_id', label: 'Tab 2', fileId: 'tab2_sheet', columns: [
      ColumnConfig(key: 'allowed_values', label: 'Values', type: 'text', dependsOn: 'is_active')
    ]);
    
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

    // Case 1: is_active is false
    when(() => mockDriveService.fetchRecordsBySpreadsheetId(any(), 'tab2_id'))
        .thenAnswer((_) async => [
          {'name': 'Parent Item 1', 'is_active': false, 'allowed_values': '[A, B]'},
        ]);

    await tester.pumpWidget(createField(
      column: childSelectCol,
      value: null,
      onChanged: (_) {},
      data: {'parent_rel': 'Parent Item 1'},
      module: module,
      key: const Key('case1'),
    ));

    await tester.pumpAndSettle();

    // Should be hidden
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);

    // Case 2: is_active is true
    when(() => mockDriveService.fetchRecordsBySpreadsheetId(any(), 'tab2_id'))
        .thenAnswer((_) async => [
          {'name': 'Parent Item 1', 'is_active': true, 'allowed_values': '[A, B]'},
        ]);

    await tester.pumpWidget(createField(
      column: childSelectCol,
      value: null,
      onChanged: (_) {},
      data: {'parent_rel': 'Parent Item 1'},
      module: module,
      key: const Key('case2'),
    ));

    await tester.pumpAndSettle();

    // Should be visible
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
  });

  testWidgets('DynamicDropdownField reloads when dependency value changes in data', (WidgetTester tester) async {
    final parentRelCol = ColumnConfig(
      key: 'parent_rel', 
      label: 'Parent', 
      type: 'relation', 
      options: 'tab2_id'
    );
    final childSelectCol = ColumnConfig(
      key: 'child_select', 
      label: 'Child Select', 
      type: 'select', 
      options: 'parent_rel.allowed_values',
    );

    final tab1 = TabConfig(id: 'tab1_id', label: 'Tab 1', fileId: 'tab1_sheet', columns: [parentRelCol, childSelectCol]);
    final tab2 = TabConfig(id: 'tab2_id', label: 'Tab 2', fileId: 'tab2_sheet', columns: []);
    
    final module = ModuleSchema(
      id: 'test_mod_id', name: 'Test Mod', icon: 'folder', primaryColor: '#000000', version: '1.0',
      settings: {}, dashboard: DashboardConfig(cards: []),
      tabs: [tab1, tab2]
    );

    int fetchCount = 0;
    when(() => mockDriveService.fetchRecordsBySpreadsheetId(any(), 'tab2_id'))
        .thenAnswer((_) async {
          fetchCount++;
          if (fetchCount == 1) {
            return [{'name': 'P1', 'allowed_values': '[A]'}];
          } else {
            return [{'name': 'P2', 'allowed_values': '[B]'}];
          }
        });

    // Initial render with P1
    await tester.pumpWidget(createField(
      column: childSelectCol,
      value: null,
      onChanged: (_) {},
      data: {'parent_rel': 'P1'},
      module: module,
    ));
    await tester.pumpAndSettle();
    expect(fetchCount, 1);

    // Update with P2
    await tester.pumpWidget(createField(
      column: childSelectCol,
      value: null,
      onChanged: (_) {},
      data: {'parent_rel': 'P2'},
      module: module,
    ));
    await tester.pumpAndSettle();
    
    // Should have called fetch again
    expect(fetchCount, 2);
  });
}
