import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/record_detail/list_field_view.dart';

void main() {
  testWidgets('ListFieldView shows placeholder when value is null or empty', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ListFieldView(label: 'Tags', value: null, primaryColor: Colors.blue))));
    expect(find.text('N/A'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ListFieldView(label: 'Tags', value: '', primaryColor: Colors.blue))));
    expect(find.text('N/A'), findsOneWidget);
  });

  testWidgets('ListFieldView renders list items from JSON string', (tester) async {
    final jsonStr = '["x","y"]';
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ListFieldView(label: 'Tags', value: jsonStr, primaryColor: Colors.green))));
    await tester.pumpAndSettle();
    expect(find.text('x'), findsOneWidget);
    expect(find.text('y'), findsOneWidget);
  });
}
