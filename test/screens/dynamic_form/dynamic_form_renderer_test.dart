import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/dynamic_form/dynamic_form_renderer.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('DynamicFormRenderer respects dependsOn and settings', (WidgetTester tester) async {
    final columns = [
      ColumnConfig(key: 'show_extra', label: 'Show Extra', type: 'boolean'),
      ColumnConfig(key: 'extra_field', label: 'Extra Field', type: 'text', dependsOn: 'show_extra'),
      ColumnConfig(key: 'negated_field', label: 'Negated Field', type: 'text', dependsOn: '!show_extra'),
      ColumnConfig(key: 'branded_field', label: 'Branded Field', type: 'text', dependsOn: 'settings.branded'),
    ];

    final Map<String, dynamic> data = {'show_extra': false};
    final Map<String, SettingItem> settings = {
       'branded': SettingItem(label: 'Branded', type: 'switch', value: true),
    };

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DynamicFormRenderer(
            columns: columns,
            data: data,
            primaryColor: Colors.blue,
            onFieldChanged: (k, v) {},
            controllers: {},
            settings: settings,
          ),
        ),
      ),
    ));

    expect(find.text('Show Extra'), findsOneWidget); // Boolean field doesn't uppercase
    expect(find.text('EXTRA FIELD'), findsNothing);
    expect(find.text('NEGATED FIELD'), findsOneWidget);
    expect(find.text('BRANDED FIELD'), findsOneWidget);

    // Update data for second build
    final Map<String, dynamic> data2 = {'show_extra': true};
    final Map<String, SettingItem> settings2 = {
       'branded': SettingItem(label: 'Branded', type: 'switch', value: false),
    };

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DynamicFormRenderer(
            columns: columns,
            data: data2,
            primaryColor: Colors.blue,
            onFieldChanged: (k, v) {},
            controllers: {},
            settings: settings2,
          ),
        ),
      ),
    ));

    expect(find.text('EXTRA FIELD'), findsOneWidget);
    expect(find.text('NEGATED FIELD'), findsNothing);
    expect(find.text('BRANDED FIELD'), findsNothing);
  });
}
