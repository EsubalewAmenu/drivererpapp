import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/dynamic_form/dynamic_form_renderer.dart';
import 'package:drivererpapp/models/schema_models.dart';

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
}
