import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/module_details_screen.dart';

void main() {
  testWidgets('ModuleDetailsScreen displays module name and key benefits', (tester) async {
    final info = {'id': 'inv', 'name': 'Inventory', 'desc': 'Test desc', 'icon': 'inventory', 'color': '#2196F3'};

    await tester.pumpWidget(MaterialApp(home: ModuleDetailsScreen(moduleInfo: Map<String,String>.from(info))));
    await tester.pumpAndSettle();

    expect(find.text('INVENTORY'), findsOneWidget);
    expect(find.text('KEY BENEFITS'), findsOneWidget);
  });
}
