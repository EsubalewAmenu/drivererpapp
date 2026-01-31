import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/dynamic_form/fields/relation_field.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('Relation field shows snackbar when options missing', (tester) async {
    final col = ColumnConfig(key: 'rel', label: 'Rel', type: 'relation');
    String? changed;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: DynamicRelationField(column: col, value: null, module: null, onChanged: (v) => changed = v, data: const {})),
    ));

    await tester.tap(find.byType(InkWell));
    await tester.pump();

    // Expect a SnackBar telling about missing configuration
    expect(find.text('Entity lookup configuration missing'), findsOneWidget);
  });
}
