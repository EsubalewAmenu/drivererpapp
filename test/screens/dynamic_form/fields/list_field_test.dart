import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/dynamic_form/fields/list_field.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('DynamicListField adds and removes items', (WidgetTester tester) async {
    final column = ColumnConfig(key: 'tags', label: 'Tags', type: 'list');
    List<String>? result;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DynamicListField(
          column: column,
          value: ['Tag1'],
          primaryColor: Colors.blue,
          onChanged: (val) => result = val,
        ),
      ),
    ));

    expect(find.text('TAGS'), findsOneWidget);
    expect(find.text('Tag1'), findsOneWidget);

    // Remove Tag1
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(result, isEmpty);

    // Add Tag2
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Tag2');
    await tester.tap(find.text('Add').last);
    await tester.pumpAndSettle();

    expect(result, contains('Tag2'));
  });
}
