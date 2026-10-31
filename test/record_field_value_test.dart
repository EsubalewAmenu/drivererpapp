import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/screens/record_detail/record_field_value.dart';

void main() {
  Future<void> show(
    WidgetTester tester,
    FieldDefinition field,
    dynamic value,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: RecordFieldValue(field: field, value: value),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'multiple phones and emails render as readable values without JSON',
    (tester) async {
      await show(
        tester,
        FieldDefinition(
          key: 'phone_nos',
          label: 'Phones',
          type: 'table',
          fields: [
            FieldDefinition(key: 'phone', label: 'Phone', type: 'phone'),
          ],
        ),
        [
          {'phone': '5550100123'},
          {'phone': '5550100456'},
        ],
      );
      expect(find.text('5550100123'), findsOneWidget);
      expect(find.text('5550100456'), findsOneWidget);
      expect(find.textContaining('"phone"'), findsNothing);
      await show(
        tester,
        FieldDefinition(
          key: 'emails',
          label: 'Emails',
          type: 'table',
          fields: [
            FieldDefinition(key: 'email', label: 'Email', type: 'email'),
          ],
        ),
        [
          {'email': 'qa@example.com'},
        ],
      );
      expect(find.text('qa@example.com'), findsOneWidget);
    },
  );
  testWidgets(
    'nested item rows use labels, typed values and hidden-field rules',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final field = FieldDefinition(
        key: 'items',
        label: 'Items',
        type: 'table',
        fields: [
          FieldDefinition(
            key: 'description',
            label: 'Description',
            type: 'text',
          ),
          FieldDefinition(
            key: 'price',
            label: 'Unit price',
            type: 'currency',
            currencySymbol: r'$',
          ),
          FieldDefinition(key: 'done', label: 'Complete', type: 'boolean'),
          FieldDefinition(
            key: 'secret',
            label: 'Internal',
            type: 'text',
            hidden: true,
          ),
          FieldDefinition(
            key: 'serials',
            label: 'Serial numbers',
            type: 'table',
            fields: [
              FieldDefinition(key: 'serial', label: 'Serial', type: 'text'),
            ],
          ),
        ],
      );
      await show(tester, field, [
        {
          'description': 'Desk',
          'price': 12.5,
          'done': true,
          'secret': 'Hidden value',
          'serials': [
            {'serial': 'SN-123'},
          ],
        },
      ]);
      expect(find.text('Description'), findsOneWidget);
      expect(find.text(r'$12.50'), findsOneWidget);
      expect(find.text('Yes'), findsOneWidget);
      expect(find.text('SN-123'), findsOneWidget);
      expect(find.text('Hidden value'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('simple lists, empty rows and unknown objects remain readable', (
    tester,
  ) async {
    await show(
      tester,
      FieldDefinition(key: 'tags', label: 'Tags', type: 'list'),
      ['Priority', 'Local'],
    );
    expect(find.text('Priority'), findsOneWidget);
    expect(find.text('Local'), findsOneWidget);
    await show(
      tester,
      FieldDefinition(key: 'meta', label: 'Metadata', type: 'text'),
      {'custom_label': 'Value'},
    );
    expect(find.text('Value'), findsOneWidget);
    await show(
      tester,
      FieldDefinition(key: 'items', label: 'Items', type: 'table'),
      [],
    );
    expect(find.text('No items'), findsOneWidget);
  });
}
