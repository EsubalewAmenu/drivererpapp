import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/module/widgets/module_status_views.dart';

void main() {
  testWidgets('ModuleErrorView displays message and retry button', (WidgetTester tester) async {
    bool retryCalled = false;
    
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ModuleErrorView(
          message: 'Connection failed',
          primaryColor: Colors.red,
          onRetry: () => retryCalled = true,
        ),
      ),
    ));

    expect(find.text('Connection failed'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    
    await tester.tap(find.text('Retry'));
    expect(retryCalled, isTrue);
  });

  testWidgets('ModuleEmptyView displays empty state message', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ModuleEmptyView(),
      ),
    ));

    expect(find.text('No items found'), findsOneWidget);
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
  });
}
