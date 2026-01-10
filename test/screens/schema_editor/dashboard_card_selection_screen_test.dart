import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/screens/schema_editor/dashboard_card_selection_screen.dart';
import 'package:drivererpapp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget createSubject() {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: const DashboardCardSelectionScreen(),
    );
  }

  testWidgets('DashboardCardSelectionScreen renders all 5 options', (WidgetTester tester) async {
    await tester.pumpWidget(createSubject());

    expect(find.text('Simple Counter'), findsOneWidget);
    expect(find.text('Conditional Count'), findsOneWidget);
    expect(find.text('Summation'), findsOneWidget);
    expect(find.text('Average'), findsOneWidget);
    expect(find.text('Status Tracker'), findsOneWidget);
  });

  testWidgets('Tapping on an option returns the correct DashboardCard', (WidgetTester tester) async {
    DashboardCard? result;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DashboardCardSelectionScreen()),
                );
              },
              child: const Text('Go'),
            ),
          );
        },
      ),
    ));

    // Navigate to screen
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();

    // Verify we are on the selection screen
    expect(find.text('SELECT CARD TYPE'), findsOneWidget);

    // Tap "Summation" option
    await tester.tap(find.text('Summation'));
    await tester.pumpAndSettle();

    // Verify result
    expect(result, isNotNull);
    expect(result!.label, equals('Total Value'));
    expect(result!.formula, equals('=SUM(sheet!C:C)'));
    expect(result!.format, equals('currency'));
  });
}
