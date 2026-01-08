import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/schema_editor_screen.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:drivererpapp/providers/drive_provider.dart';

class MockSchemaProvider extends Mock implements SchemaProvider {}
class MockDriveProvider extends Mock implements DriveProvider {}

void main() {
  late MockSchemaProvider mockSchemaProvider;
  late MockDriveProvider mockDriveProvider;

  setUp(() {
    mockSchemaProvider = MockSchemaProvider();
    mockDriveProvider = MockDriveProvider();
  });

  Widget createEditorScreen(ModuleSchema module) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SchemaProvider>.value(value: mockSchemaProvider),
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
      ],
      child: MaterialApp(
        home: SchemaEditorScreen(module: module),
      ),
    );
  }

  testWidgets('SchemaEditorScreen renders and switches tabs', (WidgetTester tester) async {
    final module = ModuleSchema(
      id: 'mod123',
      name: 'Sales',
      tabs: [
        TabConfig(id: 'tab1', label: 'Orders', columns: [])
      ],
      version: '1.0',
      icon: 'shopping_cart',
      primaryColor: '#3B82F6',
      settings: {},
      dashboard: DashboardConfig(cards: []),
    );

    await tester.pumpWidget(createEditorScreen(module));

    expect(find.text('BLUEPRINT EDITOR'), findsOneWidget);
    expect(find.text('STRUCTURE'), findsOneWidget);
    expect(find.text('DASHBOARD'), findsOneWidget);
    expect(find.text('SETTINGS'), findsOneWidget);

    // Should see the tab from structure
    expect(find.text('Orders'), findsOneWidget);

    // Switch to Dashboard
    await tester.tap(find.text('DASHBOARD'));
    await tester.pumpAndSettle();
    expect(find.text('Add Card'), findsOneWidget);

    // Switch to Settings
    await tester.tap(find.text('SETTINGS'));
    await tester.pumpAndSettle();
    expect(find.text('No settings defined.'), findsOneWidget);
  });
}
