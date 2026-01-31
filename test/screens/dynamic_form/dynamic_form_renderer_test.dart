import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/dynamic_form/dynamic_form_renderer.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/screens/dynamic_form/fields/date_field.dart';
import 'package:drivererpapp/screens/dynamic_form/fields/dropdown_field.dart';

void main() {
  testWidgets('DynamicFormRenderer renders various fields and handles dependencies', (WidgetTester tester) async {
    final columns = [
      ColumnConfig(key: 't1', label: 'Text Field', type: 'text'),
      ColumnConfig(key: 't2', label: 'Hidden Field', type: 'text', hidden: true),
      ColumnConfig(key: 't3', label: 'Dependent Field', type: 'text', dependsOn: 'show_t3'),
      ColumnConfig(key: 't4', label: 'Not Dependent Field', type: 'text', dependsOn: '!show_t3'),
      ColumnConfig(key: 't5', label: 'Setting Dependent', type: 'text', dependsOn: 'settings.active'),
      ColumnConfig(key: 't6', label: 'Number', type: 'number'),
      ColumnConfig(key: 't7', label: 'Boolean', type: 'boolean'),
      ColumnConfig(key: 't8', label: 'Date', type: 'date'),
      ColumnConfig(key: 't9', label: 'Formula', type: 'formula'),
      ColumnConfig(key: 't10', label: 'Select', type: 'select', options: ['A', 'B']),
      ColumnConfig(key: 't11', label: 'Image', type: 'image'),
      ColumnConfig(key: 't12', label: 'Relation', type: 'relation', options: 'm2.name'),
      ColumnConfig(key: 't13', label: 'Table', type: 'table', columns: [
        ColumnConfig(key: 'sub1', label: 'Sub Text', type: 'text'),
      ]),
    ];

    final data = {
      't1': 'Hello',
      'show_t3': true,
      't6': '123',
      't7': true,
    };

    final settings = {
      'active': SettingItem(label: 'Active', type: 'boolean', value: true),
    };

    final controllers = {
      't1': TextEditingController(),
      't6': TextEditingController(),
      't9': TextEditingController(),
    };

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DynamicFormRenderer(
            columns: columns,
            data: data,
            primaryColor: Colors.blue,
            onFieldChanged: (k, v) {},
            controllers: controllers,
            settings: settings,
          ),
        ),
      ),
    ));

    expect(find.text('TEXT FIELD'), findsOneWidget);
    expect(find.text('HIDDEN FIELD'), findsNothing);
    expect(find.text('DEPENDENT FIELD'), findsOneWidget);
    expect(find.text('NOT DEPENDENT FIELD'), findsNothing);
    expect(find.text('SETTING DEPENDENT'), findsOneWidget);
    expect(find.text('NUMBER'), findsOneWidget);
    expect(find.text('Boolean'), findsOneWidget);
    expect(find.text('DATE'), findsOneWidget);
    expect(find.text('FORMULA'), findsOneWidget);
    expect(find.text('SELECT'), findsOneWidget);
    expect(find.text('IMAGE'), findsOneWidget);
  });

  testWidgets('DynamicFormRenderer handles list and table fields', (WidgetTester tester) async {
    final columns = [
      ColumnConfig(key: 'list1', label: 'List Field', type: 'list'),
      ColumnConfig(key: 'list2', label: 'List JSON', type: 'list'),
      ColumnConfig(key: 'table', label: 'Table Field', type: 'table', columns: [
        ColumnConfig(key: 'sub1', label: 'Sub1', type: 'text'),
      ]),
      ColumnConfig(key: 'unsupported', label: 'Unsupported', type: 'unknown'),
    ];

    final data = {
      'list1': ['Item A', 'Item B'],
      'list2': '["Item C", "Item D"]',
      'table': [{'sub1': 'Val1'}],
    };

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DynamicFormRenderer(
          columns: columns,
          data: data,
          primaryColor: Colors.blue,
          onFieldChanged: (k, v) {},
          controllers: const {},
        ),
      ),
    ));

    expect(find.text('LIST FIELD'), findsOneWidget);
    expect(find.text('LIST JSON'), findsOneWidget);
    expect(find.text('TABLE FIELD'), findsOneWidget);
    expect(find.text('Unsupported field type: unknown'), findsOneWidget);
  });

  testWidgets('DynamicFormRenderer handles more types and edge cases', (WidgetTester tester) async {
    final columns = [
      ColumnConfig(key: 'c1', label: 'Currency', type: 'currency'),
      ColumnConfig(key: 'e1', label: 'Email', type: 'email'),
      ColumnConfig(key: 'p1', label: 'Phone', type: 'phone'),
      ColumnConfig(key: 'sign', label: 'Signature', type: 'signature'),
      ColumnConfig(key: 'scan', label: 'Scanner', type: 'scanner'),
      ColumnConfig(key: 'list_err', label: 'List Err', type: 'list'),
      ColumnConfig(key: 'table_null', label: 'Table Null', type: 'table'),
    ];

    final data = {
      'list_err': 'invalid json',
    };

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DynamicFormRenderer(
            columns: columns,
            data: data,
            primaryColor: Colors.blue,
            onFieldChanged: (k, v) {},
            controllers: const {},
          ),
        ),
      ),
    ));

    expect(find.text('CURRENCY'), findsOneWidget);
    expect(find.text('EMAIL'), findsOneWidget);
    expect(find.text('PHONE'), findsOneWidget);
    expect(find.text('SIGNATURE'), findsOneWidget);
    expect(find.text('SCANNER'), findsOneWidget);
    expect(find.text('LIST ERR'), findsOneWidget);
    expect(find.text('TABLE NULL'), findsOneWidget);
  });

  testWidgets('DynamicFormRenderer handles dependency edge cases', (WidgetTester tester) async {
    final columns = [
      ColumnConfig(key: 'd1', label: 'Dep String', type: 'text', dependsOn: 'str_val'),
      ColumnConfig(key: 'd2', label: 'Dep Null', type: 'text', dependsOn: 'null_val'),
      ColumnConfig(key: 'd3', label: 'Dep Setting False', type: 'text', dependsOn: 'settings.inactive'),
      ColumnConfig(key: 'd4', label: 'Dep Setting Missing', type: 'text', dependsOn: 'settings.missing'),
    ];

    final data = {
      'str_val': 'something',
      'null_val': null,
    };

    final settings = {
      'inactive': SettingItem(label: 'L', type: 'b', value: false),
    };

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DynamicFormRenderer(
          columns: columns,
          data: data,
          primaryColor: Colors.blue,
          onFieldChanged: (k, v) {},
          controllers: const {},
          settings: settings,
        ),
      ),
    ));

    expect(find.text('DEP STRING'), findsOneWidget);
    expect(find.text('DEP NULL'), findsNothing);
    expect(find.text('DEP SETTING FALSE'), findsNothing);
    expect(find.text('DEP SETTING MISSING'), findsNothing);
  });

  testWidgets('DynamicFormRenderer triggers onFieldChanged', (WidgetTester tester) async {
    final columns = [
      ColumnConfig(key: 't1', label: 'T1', type: 'text'),
      ColumnConfig(key: 'b1', label: 'B1', type: 'boolean'),
    ];

    String? lastKey;
    dynamic lastValue;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DynamicFormRenderer(
          columns: columns,
          data: const {},
          primaryColor: Colors.blue,
          onFieldChanged: (k, v) {
            lastKey = k;
            lastValue = v;
          },
          controllers: {'t1': TextEditingController()},
        ),
      ),
    ));

    await tester.enterText(find.byType(TextField).first, 'New Val');
    expect(lastKey, 't1');
    expect(lastValue, 'New Val');

    await tester.tap(find.byType(Switch).first);
    expect(lastKey, 'b1');
    expect(lastValue, true);

    // Date change
    final dateFinder = find.byType(DynamicDateField);
    if (dateFinder.evaluate().isNotEmpty) {
      final dateWidget = tester.widget<DynamicDateField>(dateFinder);
      dateWidget.onChanged('2023-01-01');
      expect(lastKey, 'date');
    }

    // Select change
    final selectFinder = find.byType(DynamicDropdownField);
    if (selectFinder.evaluate().isNotEmpty) {
      final selectWidget = tester.widget<DynamicDropdownField>(selectFinder);
      selectWidget.onChanged('X');
      expect(lastKey, 'sel');
    }
  });

  testWidgets('DynamicFormRenderer handles more dependency cases', (WidgetTester tester) async {
    final columns = [
      ColumnConfig(key: 'd5', label: 'Dep Bool False', type: 'text', dependsOn: 'bool_false'),
      ColumnConfig(key: 'd6', label: 'Dep Empty Str', type: 'text', dependsOn: 'empty_str'),
    ];

    final data = {
      'bool_false': false,
      'empty_str': '',
    };

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DynamicFormRenderer(
          columns: columns,
          data: data,
          primaryColor: Colors.blue,
          onFieldChanged: (k, v) {},
          controllers: const {},
        ),
      ),
    ));

    expect(find.text('DEP BOOL FALSE'), findsNothing);
    expect(find.text('DEP EMPTY STR'), findsNothing);
  });

  testWidgets('DynamicFormRenderer handles more field types and edge cases', (WidgetTester tester) async {
    final columns = [
      ColumnConfig(key: 'c1', label: 'Currency', type: 'currency'),
      ColumnConfig(key: 'e1', label: 'Email', type: 'email'),
      ColumnConfig(key: 'p1', label: 'Phone', type: 'phone'),
      ColumnConfig(key: 's1', label: 'Signature', type: 'signature'),
      ColumnConfig(key: 'sc1', label: 'Scanner', type: 'scanner'),
      ColumnConfig(key: 'l1', label: 'Invalid List', type: 'list'),
      ColumnConfig(key: 'dep1', label: 'DepSettingMissing', type: 'text', dependsOn: 'settings.missing'),
      ColumnConfig(key: 'dep2', label: 'DepFieldMissing', type: 'text', dependsOn: 'missing_field'),
      ColumnConfig(key: 'dep3', label: 'DepFieldEmpty', type: 'text', dependsOn: 'empty_field'),
      ColumnConfig(key: 'table2', label: 'Empty Table', type: 'table'),
    ];

    final data = {
      'l1': 'invalid_json',
      'empty_field': '',
    };

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DynamicFormRenderer(
            columns: columns,
            data: data,
            primaryColor: Colors.blue,
            onFieldChanged: (k, v) {},
            controllers: const {},
          ),
        ),
      ),
    ));

    expect(find.text('CURRENCY'), findsOneWidget);
    expect(find.text('EMAIL'), findsOneWidget);
    expect(find.text('PHONE'), findsOneWidget);
    expect(find.text('SIGNATURE'), findsOneWidget);
    expect(find.text('SCANNER'), findsOneWidget);
    
    // Dependencies
    expect(find.text('DEPSETTINGMISSING'), findsNothing); // Setting missing (null == true is false)
    expect(find.text('DEPFIELDMISSING'), findsNothing); // Field missing (null is falsey)
    expect(find.text('DEPFIELDEMPTY'), findsNothing); // Field empty string (is falsey)

    // Extra truthy checks
    final columns4 = [
      ColumnConfig(key: 'dep4', label: 'DepInt', type: 'text', dependsOn: 'int_field'),
      ColumnConfig(key: 'dep5', label: 'DepMap', type: 'text', dependsOn: 'map_field'),
    ];
    final data4 = {
      'int_field': 123,
      'map_field': {'a': 1},
    };
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DynamicFormRenderer(
          columns: columns4,
          data: data4,
          primaryColor: Colors.blue,
          onFieldChanged: (k, v) {},
          controllers: const {},
        ),
      ),
    ));
    expect(find.text('DEPINT'), findsOneWidget);
    expect(find.text('DEPMAP'), findsOneWidget);

    // Invalid list type (neither list nor string)
    final columns3 = [
      ColumnConfig(key: 'l2', label: 'Map List', type: 'list'),
      ColumnConfig(key: 't2', label: 'Null Table', type: 'table'),
    ];
    final data3 = {
      'l2': {'not': 'a list'},
      't2': null,
    };

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DynamicFormRenderer(
          columns: columns3,
          data: data3,
          primaryColor: Colors.blue,
          onFieldChanged: (k, v) {},
          controllers: const {},
        ),
      ),
    ));
    expect(find.text('MAP LIST'), findsOneWidget);
    expect(find.text('NULL TABLE'), findsOneWidget);

    // Negation for settings
    final columns2 = [
      ColumnConfig(key: 'n1', label: 'NegSettingTrue', type: 'text', dependsOn: '!settings.active'),
      ColumnConfig(key: 'n2', label: 'NegSettingFalse', type: 'text', dependsOn: '!settings.inactive'),
    ];
    final settings2 = {
      'active': SettingItem(label: 'Active', type: 'boolean', value: true),
      'inactive': SettingItem(label: 'Inactive', type: 'boolean', value: false),
    };

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DynamicFormRenderer(
          columns: columns2,
          data: const {},
          primaryColor: Colors.blue,
          onFieldChanged: (k, v) {},
          controllers: const {},
          settings: settings2,
        ),
      ),
    ));

    expect(find.text('NEGSETTINGTRUE'), findsNothing);
    expect(find.text('NEGSETTINGFALSE'), findsOneWidget);
  });

  testWidgets('DynamicFormRenderer triggers onFieldChanged for various types', (WidgetTester tester) async {
    String? lastKey;
    dynamic lastValue;

    final columns = [
      ColumnConfig(key: 'bool', label: 'Bool', type: 'boolean'),
      ColumnConfig(key: 'date', label: 'Date', type: 'date'),
      ColumnConfig(key: 'sel', label: 'Select', type: 'select', options: ['X', 'Y']),
      ColumnConfig(key: 'media', label: 'Media', type: 'image'),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DynamicFormRenderer(
            columns: columns,
            data: const {},
            primaryColor: Colors.blue,
            onFieldChanged: (k, v) {
              lastKey = k;
              lastValue = v;
            },
            controllers: const {},
          ),
        ),
      ),
    ));

    // Trigger boolean change
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(lastKey, 'bool');
    expect(lastValue, true);
  });
}
