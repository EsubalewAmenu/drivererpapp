import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/dynamic_form/dynamic_form_renderer.dart';
import 'package:drivererpapp/models/schema_models.dart';
// Imports for field types to match by type
import 'package:drivererpapp/screens/dynamic_form/fields/text_field.dart';
import 'package:drivererpapp/screens/dynamic_form/fields/boolean_field.dart';

void main() {
  testWidgets('DynamicFormRenderer renders visible fields', (WidgetTester tester) async {
    final columns = [
      ColumnConfig(key: 'name', label: 'Name', type: 'text'),
      ColumnConfig(key: 'active', label: 'Active', type: 'boolean'),
    ];
    final data = <String, dynamic>{
      'name': 'Test',
      'active': true,
    };
    final controllers = <String, TextEditingController>{};

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DynamicFormRenderer(
            columns: columns,
            data: data,
            primaryColor: Colors.blue,
            onFieldChanged: (key, val) => data[key] = val,
            controllers: controllers,
          ),
        ),
      ),
    ));

    expect(find.byType(DynamicTextField), findsOneWidget);
    expect(find.byType(DynamicBooleanField), findsOneWidget);
    expect(find.text('NAME'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets('DynamicFormRenderer respects dependsOn visibility', (WidgetTester tester) async {
    final columns = [
      ColumnConfig(key: 'has_extra', label: 'Has Extra', type: 'boolean'),
      ColumnConfig(key: 'extra_info', label: 'Extra Info', type: 'text', dependsOn: 'has_extra'),
    ];
    
    // Case 1: has_extra = false
    var data = <String, dynamic>{'has_extra': false};
    var controllers = <String, TextEditingController>{};

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DynamicFormRenderer(
            columns: columns,
            data: data,
            primaryColor: Colors.blue,
            onFieldChanged: (_, __) {},
            controllers: controllers,
          ),
        ),
      ),
    ));

    expect(find.byType(DynamicBooleanField), findsOneWidget);
    expect(find.byType(DynamicTextField), findsNothing); // Hidden
    
    // Case 2: has_extra = true
    data = <String, dynamic>{'has_extra': true};
    
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DynamicFormRenderer(
            columns: columns,
            data: data,
            primaryColor: Colors.blue,
            onFieldChanged: (_, __) {},
            controllers: controllers,
          ),
        ),
      ),
    ));
    
    expect(find.byType(DynamicTextField), findsOneWidget); // Visible
  });

  testWidgets('DynamicFormRenderer respects settings visibility', (WidgetTester tester) async {
    final columns = [
      ColumnConfig(key: 'extra_feature', label: 'Extra Feature', type: 'text', dependsOn: 'settings.advanced_mode'),
    ];
    
    // Case 1: advanced_mode disabled
    Map<String, SettingItem> settings = {
        'advanced_mode': SettingItem(value: false, label: 'Adv', type: 'boolean'),
    };
    
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DynamicFormRenderer(
            columns: columns,
            data: {},
            primaryColor: Colors.blue,
            onFieldChanged: (_, __) {},
            controllers: {},
            settings: settings,
          ),
        ),
      ),
    ));

    expect(find.byType(DynamicTextField), findsNothing);
    
    // Case 2: advanced_mode enabled
    settings = {
        'advanced_mode': SettingItem(value: true, label: 'Adv', type: 'boolean'),
    };
    
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DynamicFormRenderer(
            columns: columns,
            data: {},
            primaryColor: Colors.blue,
            onFieldChanged: (_, __) {},
            controllers: {},
            settings: settings,
          ),
        ),
      ),
    ));

    expect(find.byType(DynamicTextField), findsOneWidget);
  });
}
