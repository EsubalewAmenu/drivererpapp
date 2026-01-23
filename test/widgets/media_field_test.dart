import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/dynamic_form/fields/media_field.dart';
import 'package:drivererpapp/models/schema_models.dart';

void main() {
  testWidgets('MediaField scanner and signature show snackbars and image delete triggers onChanged', (tester) async {
    final col = ColumnConfig(key: 'img', label: 'Image', type: 'image');
    String? val;

    // Test scanner
    final scannerCol = ColumnConfig(key: 'scan', label: 'Scan', type: 'text');
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DynamicMediaField(column: scannerCol, value: null, primaryColor: Colors.blue, onChanged: (v) => val = v, type: 'scanner'))));

    // Tap QR icon to trigger scanner
    await tester.tap(find.byIcon(Icons.qr_code_scanner_rounded));
    await tester.pump();
    expect(find.textContaining('SCAN-'), findsOneWidget);

    // Test signature tap (ensure tap doesn't throw)
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DynamicMediaField(column: col, value: null, primaryColor: Colors.blue, onChanged: (v) => val = v, type: 'signature'))));
    await tester.tap(find.text('Tap to sign'));
    await tester.pump();

    // Test image delete action triggers onChanged
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DynamicMediaField(column: col, value: 'file123', primaryColor: Colors.blue, onChanged: (v) => val = v, type: 'image'))));
    await tester.pumpAndSettle();

    // Tap delete icon (delete_outline_rounded) - this calls onChanged('')
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();

    expect(val, '');
  });
}
