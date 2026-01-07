import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/screens/schema_editor/dialogs/edit_kpi_dialog.dart';
import 'package:drivererpapp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    AppTheme.useGoogleFonts = false;
  });
  
  Widget createDialog({KpiCard? kpi}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (context) => EditKpiDialog(kpi: kpi),
                );
              },
              child: const Text('Open Dialog'),
            );
          },
        ),
      ),
    );
  }

  testWidgets('EditKpiDialog renders correctly for new KPI', (WidgetTester tester) async {
    await tester.pumpWidget(createDialog());
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Add KPI Card'), findsOneWidget);
    expect(find.text('Label'), findsOneWidget);
    expect(find.text('Calculation Formula'), findsOneWidget);
    expect(find.text('Format'), findsOneWidget);
  });

  testWidgets('EditKpiDialog renders correctly involved editing', (WidgetTester tester) async {
    final kpi = KpiCard(
      label: 'Total Revenue',
      calculation: 'SUM(amount)',
      format: 'currency',
    );

    await tester.pumpWidget(createDialog(kpi: kpi));
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Edit KPI Card'), findsOneWidget);
    expect(find.text('Total Revenue'), findsOneWidget);
    expect(find.text('SUM(amount)'), findsOneWidget);
    expect(find.text('CURRENCY'), findsOneWidget); // Dropdown shows upper case
  });

  testWidgets('EditKpiDialog returns new KPI on save', (WidgetTester tester) async {
    KpiCard? result;
    
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                result = await showDialog<KpiCard>(
                  context: context,
                  builder: (context) => const EditKpiDialog(),
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

    await tester.enterText(find.widgetWithText(TextField, 'Label'), 'New KPI');
    await tester.enterText(find.widgetWithText(TextField, 'Calculation Formula'), 'COUNT(id)');
    
    // Default format is number, let's keep it

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.label, 'New KPI');
    expect(result!.calculation, 'COUNT(id)');
    expect(result!.format, 'number');
  });

  testWidgets('EditKpiDialog validates inputs', (WidgetTester tester) async {
    await tester.pumpWidget(createDialog());
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Try save empty
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Add KPI Card'), findsOneWidget); // Still open
  });
}
