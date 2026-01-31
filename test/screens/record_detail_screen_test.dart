import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/record_detail_screen.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/providers/drive_provider.dart';

import 'package:drivererpapp/services/drive_service.dart';

class MockDriveProvider extends Mock implements DriveProvider {}
class MockDriveService extends Mock implements DriveService {}

void main() {
  late MockDriveProvider mockDrive;
  late MockDriveService mockService;

  setUp(() {
    mockDrive = MockDriveProvider();
    mockService = MockDriveService();
    when(() => mockDrive.driveService).thenReturn(mockService);
    when(() => mockService.getFileId(any(), any())).thenAnswer((_) async => null);
    when(() => mockService.deleteRecordBySpreadsheetId(any(), any(), any())).thenAnswer((_) async => {});
  });

  Widget createScreen({
    required List<ColumnConfig> columns,
    required Map<String, dynamic> data,
    Map<String, SettingItem> settings = const {},
    DetailTemplateConfig? template,
    ModuleSchema? module,
    String? fileId,
  }) {
    return ChangeNotifierProvider<DriveProvider>.value(
      value: mockDrive,
      child: MaterialApp(
        home: RecordDetailScreen(
          columns: columns,
          data: data,
          settings: settings,
          primaryColor: Colors.blue,
          title: 'Test',
          detailTemplate: template,
          tab: TabConfig(id: 't1', label: 'Test', columns: columns, fileId: fileId),
          module: module,
        ),
      ),
    );
  }

  testWidgets('RecordDetailScreen Comprehensive', (tester) async {
    final cols = [
      ColumnConfig(key: 't', label: 'T', type: 'text'),
      ColumnConfig(key: 'f', label: 'F', type: 'formula'),
      ColumnConfig(key: 'i', label: 'I', type: 'image'),
      ColumnConfig(key: 'ie', label: 'IE', type: 'image'), // null value
      ColumnConfig(key: 'status', label: 'S', type: 'text'),
      ColumnConfig(key: 'tab', label: 'Tab', type: 'table', columns: [
        ColumnConfig(key: 's1', label: 'S1', type: 'text'),
      ]),
      ColumnConfig(key: 'tabe', label: 'TabE', type: 'table', columns: []),
      ColumnConfig(key: 'd1', label: 'D1', type: 'text', dependsOn: 'on'),
      ColumnConfig(key: 'd2', label: 'D2', type: 'text', dependsOn: 'off'),
      ColumnConfig(key: 'd3', label: 'D3', type: 'text', dependsOn: 'settings.son'),
      ColumnConfig(key: 'd4', label: 'D4', type: 'text', dependsOn: 'settings.soff'),
    ];

    final data = {
      't': 'val',
      'f': 'form',
      'i': 'url',
      'tab': [{'s1': 'v'}],
      'on': true,
      'off': false,
      'd1': 'v1',
      'd3': 'v3',
    };

    final settings = {
      'son': SettingItem(label: 'L', type: 'b', value: true),
      'soff': SettingItem(label: 'L', type: 'b', value: false),
    };

    await tester.pumpWidget(createScreen(columns: cols, data: data, settings: settings));
    await tester.pumpAndSettle();

    // Trigger all statuses
    final sCols = [ColumnConfig(key: 'status', label: 'S', type: 'text')];
    final statuses = ['paid', 'completed', 'active', 'delivered', 'pending', 'cancelled', 'error', 'failed', 'inactive', 'unknown'];
    for (var s in statuses) {
      await tester.pumpWidget(createScreen(columns: sCols, data: {'status': s}));
      await tester.pump();
    }

    // Modern template + missing title key
    await tester.pumpWidget(createScreen(
      columns: [],
      data: {},
      template: DetailTemplateConfig(template: 'modern', titleKey: 'none'),
    ));
    await tester.pumpAndSettle();
  });

  testWidgets('RecordDetailScreen handles negation dependsOn', (tester) async {
    final cols = [
      ColumnConfig(key: 'individual', label: 'Individual Only', type: 'text', dependsOn: 'is_individual'),
      ColumnConfig(key: 'company', label: 'Company Only', type: 'text', dependsOn: '!is_individual'),
    ];

    // Case 1: is_individual is true
    final dataIndividual = {
      'is_individual': true,
      'individual': 'John Doe',
      'company': 'ACME Corp',
    };

    await tester.pumpWidget(createScreen(columns: cols, data: dataIndividual));
    await tester.pumpAndSettle();

    expect(find.text('INDIVIDUAL ONLY'), findsOneWidget);
    expect(find.text('COMPANY ONLY'), findsNothing);

    // Case 2: is_individual is false
    final dataCompany = {
      'is_individual': false,
      'individual': 'John Doe',
      'company': 'ACME Corp',
    };

    await tester.pumpWidget(createScreen(columns: cols, data: dataCompany));
    await tester.pumpAndSettle();

    expect(find.text('INDIVIDUAL ONLY'), findsNothing);
    expect(find.text('COMPANY ONLY'), findsOneWidget);
  });

  testWidgets('RecordDetailScreen handles conditional title logic', (tester) async {
    final cols = [
      ColumnConfig(key: 'full_name', label: 'FullName', type: 'text'),
      ColumnConfig(key: 'company_name', label: 'CompanyName', type: 'text'),
    ];

    final logic = ConditionalLogic(
      conditionKey: 'is_individual',
      truthyKey: 'full_name',
      falsyKey: 'company_name',
    );

    final template = DetailTemplateConfig(
      template: 'standard',
      titleLogic: logic,
      subtitleLogic: ConditionalLogic(
        conditionKey: 'has_dept',
        truthyKey: 'dept',
        falsyKey: 'city',
      ),
    );

    // Case 1: Individual
    final data1 = {
      'is_individual': true,
      'full_name': 'Alice Smith',
      'company_name': 'Alice Corp',
      'has_dept': false,
      'city': 'New York',
    };

    await tester.pumpWidget(MaterialApp(
      home: RecordDetailScreen(
        data: data1,
        columns: cols,
        primaryColor: Colors.blue,
        title: 'Default',
        detailTemplate: template,
        tab: TabConfig(id: 't1', label: 'Test', columns: cols),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Alice Smith'), findsOneWidget);
    expect(find.text('New York'), findsOneWidget);

    // Case 2: Company
    final data2 = {
      'is_individual': false,
      'full_name': 'Bob Smith',
      'company_name': 'Bob Corp',
      'has_dept': true,
      'dept': 'Sales',
    };

    await tester.pumpWidget(MaterialApp(
      home: RecordDetailScreen(
        data: data2,
        columns: cols,
        primaryColor: Colors.blue,
        title: 'Default',
        detailTemplate: template,
        tab: TabConfig(id: 't1', label: 'Test', columns: cols),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Bob Corp'), findsOneWidget);
    expect(find.text('Sales'), findsOneWidget);
  });

  testWidgets('RecordDetailScreen handles other ConditionalLogic types', (tester) async {
    final template = DetailTemplateConfig(
      titleLogic: ConditionalLogic(
        conditionKey: 'score', // num
        truthyKey: 'has_score',
        falsyKey: 'no_score',
      ),
      subtitleLogic: ConditionalLogic(
        conditionKey: 'tags', // list
        truthyKey: 'has_tags',
        falsyKey: 'no_tags',
      ),
    );

    final data = {
      'score': 50,
      'has_score': 'Score Found',
      'no_score': 'Missing',
      'tags': ['a'],
      'has_tags': 'Tags Found',
      'no_tags': 'MT',
    };

    await tester.pumpWidget(MaterialApp(
      home: RecordDetailScreen(
        data: data,
        columns: const [],
        primaryColor: Colors.blue,
        title: 'Default',
        detailTemplate: template,
        tab: TabConfig(id: 't1', label: 'Test', columns: []),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Score Found'), findsOneWidget);
    expect(find.text('Tags Found'), findsOneWidget);
  });

  testWidgets('RecordDetailScreen handles table column type rendering', (tester) async {
    final columns = [
      ColumnConfig(
        key: 'items',
        label: 'Items',
        type: 'table',
        columns: [
          ColumnConfig(key: 'name', label: 'Name', type: 'text'),
          ColumnConfig(key: 'qty', label: 'Qty', type: 'number'),
        ],
      ),
    ];

    final data = {
      'items': [
        {'name': 'Apple', 'qty': 10},
        {'name': 'Orange', 'qty': 5},
      ],
    };

    await tester.pumpWidget(MaterialApp(
      home: RecordDetailScreen(
        data: data,
        columns: columns,
        primaryColor: Colors.blue,
        title: 'Items List',
        tab: TabConfig(id: 't1', label: 'Test', columns: columns),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ITEMS'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('Orange'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
  });

  testWidgets('RecordDetailScreen edit button navigates to DynamicFormScreen', (tester) async {
    final columns = [ColumnConfig(key: 'name', label: 'Name', type: 'text')];
    final data = {'name': 'Alice', 'record_id': 'r1'};

    await tester.pumpWidget(MaterialApp(
      home: RecordDetailScreen(
        data: data,
        columns: columns,
        primaryColor: Colors.blue,
        title: 'Alice',
        tab: TabConfig(id: 't1', label: 'Test', columns: columns),
      ),
    ));

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.text('EDIT TEST'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets('RecordDetailScreen deletion flow', (tester) async {
    final module = ModuleSchema(
      id: 'm1',
      name: 'M1',
      icon: 'box',
      primaryColor: '#000000',
      version: '1.0.0',
      settings: {},
      dashboard: DashboardConfig(cards: []),
      tabs: [],
    );
    final data = {'record_id': 'r1', 'name': 'Item 1'};
    final cols = [ColumnConfig(key: 'name', label: 'Name', type: 'text')];

    await tester.pumpWidget(createScreen(
      columns: cols,
      data: data,
      module: module,
      fileId: 'fid123',
    ));
    await tester.pumpAndSettle();

    // Find delete button - usually it's an IconButton in the AppBar
    final deleteButton = find.byIcon(Icons.delete_outline_rounded);
    expect(deleteButton, findsOneWidget);

    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    // Should see confirmation dialog
    expect(find.text('Delete Record'), findsOneWidget);
    expect(find.text('Are you sure you want to delete this record? This action cannot be undone.'), findsOneWidget);

    // Cancel deletion
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Record'), findsNothing);

    // Confirm deletion
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('DELETE'));
    await tester.pumpAndSettle();

    verify(() => mockService.deleteRecordBySpreadsheetId('fid123', 't1', 'r1')).called(1);
  });
}
