import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/dynamic_form/fields/media_field.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('DynamicMediaField renders image picker', (WidgetTester tester) async {
    final column = ColumnConfig(
      key: 'photo',
      label: 'Photo',
      type: 'image',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DynamicMediaField(
            column: column,
            value: null,
            primaryColor: Colors.blue,
            onChanged: (_) {},
            type: 'image',
          ),
        ),
      ),
    );

    expect(find.text('PHOTO'), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
    expect(find.text('Tap to capture'), findsOneWidget);

    // Tap it
    await tester.tap(find.text('Tap to capture'));
    await tester.pump();
    expect(find.text('Camera integration coming soon'), findsOneWidget);
  });

  testWidgets('DynamicMediaField renders scanner', (WidgetTester tester) async {
    final column = ColumnConfig(
      key: 'barcode',
      label: 'Barcode',
      type: 'scanner',
    );
    String? changedValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DynamicMediaField(
            column: column,
            value: '12345',
            primaryColor: Colors.blue,
            onChanged: (val) => changedValue = val,
            type: 'scanner',
          ),
        ),
      ),
    );

    expect(find.text('BARCODE'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('12345'), findsOneWidget);

    // Test text entry manually (as if scanner filled it)
    await tester.enterText(find.byType(TextFormField), '67890');
    
    expect(changedValue, '67890');
  });
}
