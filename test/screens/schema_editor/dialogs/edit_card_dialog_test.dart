import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/screens/schema_editor/dialogs/edit_card_dialog.dart';
import 'package:drivererpapp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    AppTheme.useGoogleFonts = false;
  });
  
  Widget createDialog({DashboardCard? card}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (context) => EditCardDialog(card: card),
                );
              },
              child: const Text('Open Dialog'),
            );
          },
        ),
      ),
    );
  }

  testWidgets('EditCardDialog renders correctly for new Card', (WidgetTester tester) async {
    await tester.pumpWidget(createDialog());
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Add Card'), findsOneWidget);
    expect(find.text('Label'), findsOneWidget);
    expect(find.text('Spreadsheet Formula'), findsOneWidget);
    expect(find.text('Format'), findsOneWidget);
  });

  testWidgets('EditCardDialog renders correctly involved editing', (WidgetTester tester) async {
    final card = DashboardCard(
      label: 'Total Revenue',
      formula: 'SUM(amount)',
      format: 'currency',
    );

    await tester.pumpWidget(createDialog(card: card));
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Card'), findsOneWidget);
    expect(find.text('Total Revenue'), findsOneWidget);
    expect(find.text('SUM(amount)'), findsOneWidget);
    expect(find.text('CURRENCY'), findsOneWidget); // Dropdown shows upper case
  });

  testWidgets('EditCardDialog returns new Card on save', (WidgetTester tester) async {
    DashboardCard? result;
    
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                result = await showDialog<DashboardCard>(
                  context: context,
                  builder: (context) => const EditCardDialog(),
                );
              },
              child: const Text('Open Dialog'),
            );
          },
        ),
      ),
    ));

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Label'), 'New Card');
    await tester.enterText(find.widgetWithText(TextField, 'Spreadsheet Formula'), 'COUNT(id)');
    
    // Default format is number, let's keep it

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.label, 'New Card');
    expect(result!.formula, 'COUNT(id)');
    expect(result!.format, 'number');
  });

  testWidgets('EditCardDialog validates inputs', (WidgetTester tester) async {
    await tester.pumpWidget(createDialog());
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Try save empty
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Add Card'), findsOneWidget); // Still open
  });
}
