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

  testWidgets('DashboardCardSelectionScreen renders all 6 options', (WidgetTester tester) async {
    await tester.pumpWidget(createSubject());

    expect(find.text('Number'), findsOneWidget);
    expect(find.text('Trends'), findsOneWidget);
    expect(find.text('Comparison'), findsOneWidget);
    expect(find.text('Distribution'), findsOneWidget);
    
    // Scroll to find bottom elements if necessary
    await tester.drag(find.text('Number'), const Offset(0, -500));
    await tester.pumpAndSettle();
    
    expect(find.text('Goal Status'), findsOneWidget);
    expect(find.text('Leaderboard'), findsOneWidget);
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
    expect(find.text('CHOOSE VISUALIZATION'), findsOneWidget);

    // Tap "Trends" (Line Chart) option
    await tester.tap(find.text('Trends'));
    await tester.pumpAndSettle();

    // Verify result
    expect(result, isNotNull);
    expect(result!.label, equals('Revenue Trend'));
    expect(result!.type, equals('line'));
    expect(result!.formula, equals('=CHART(sheet!A:B)'));
    expect(result!.format, equals('number'));
  });
}
