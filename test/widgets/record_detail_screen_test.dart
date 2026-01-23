import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/record_detail_screen.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('RecordDetailScreen respects conditional title logic and image URL resolution', (tester) async {
    final data = {'active': true, 'name': 'Hello', 'photo': 'http://example.com/p.jpg'};
    final cols = <ColumnConfig>[];
    final detail = DetailTemplateConfig(template: 'modern', titleLogic: ConditionalLogic(conditionKey: 'active', truthyKey: 'name', falsyKey: ''), imageKey: 'photo');

    await tester.pumpWidget(MaterialApp(
      home: RecordDetailScreen(data: data, columns: cols, primaryColor: Colors.blue, title: 'Details', tab: TabConfig(id: 't', label: 'L', columns: []), detailTemplate: detail),
    ));

    await tester.pumpAndSettle();

    // Title should resolve to 'Hello' via logic
    expect(find.text('Hello'), findsOneWidget);

    // Modern header uses Image.network with provided http url
    expect(find.byType(Image), findsWidgets);
  });
}
