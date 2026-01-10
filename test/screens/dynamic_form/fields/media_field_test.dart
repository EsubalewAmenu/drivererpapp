import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/dynamic_form/fields/media_field.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('DynamicMediaField handles image type', (WidgetTester tester) async {
    final column = ColumnConfig(key: 'img', label: 'Photo', type: 'image');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DynamicMediaField(
          column: column,
          value: null,
          primaryColor: Colors.blue,
          onChanged: (val) {},
          type: 'image',
        ),
      ),
    ));

    expect(find.text('PHOTO'), findsOneWidget);
    expect(find.byIcon(Icons.add_a_photo_rounded), findsOneWidget);
    
    await tester.tap(find.text('Tap to pick or capture image'));
    await tester.pumpAndSettle();
    
    expect(find.text('Select Image Source'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
  });

  testWidgets('DynamicMediaField handles scanner type', (WidgetTester tester) async {
    final column = ColumnConfig(key: 'barcode', label: 'Barcode', type: 'scanner');
    String? newValue;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DynamicMediaField(
          column: column,
          value: 'OLD-VALUE',
          primaryColor: Colors.blue,
          onChanged: (val) => newValue = val,
          type: 'scanner',
        ),
      ),
    ));

    expect(find.text('BARCODE'), findsOneWidget);
    expect(find.text('OLD-VALUE'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.qr_code_scanner_rounded));
    await tester.pump();
    
    expect(newValue, startsWith('SCAN-'));
  });

  testWidgets('DynamicMediaField handles signature type', (WidgetTester tester) async {
    final column = ColumnConfig(key: 'sig', label: 'Signature', type: 'signature');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DynamicMediaField(
          column: column,
          value: null,
          primaryColor: Colors.blue,
          onChanged: (val) {},
          type: 'signature',
        ),
      ),
    ));

    expect(find.text('SIGNATURE'), findsOneWidget);
    expect(find.text('Tap to sign'), findsOneWidget);
  });
}
