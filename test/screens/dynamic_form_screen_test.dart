import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/dynamic_form_screen.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';

class MockDriveProvider extends Mock implements DriveProvider {}
class MockDriveService extends Mock implements DriveService {}

void main() {
  late MockDriveProvider mockDriveProvider;
  late MockDriveService mockDriveService;

  setUpAll(() {
    registerFallbackValue(Map<String, dynamic>.from({}));
  });

  setUp(() {
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();
    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
  });

  Widget createFormScreen() {
    final tab = TabConfig(
      id: 'tab1',
      label: 'Orders',
      columns: [
        ColumnConfig(key: 'customer', label: 'Customer', type: 'text', isRequired: true),
      ],
    );
    
    final module = ModuleSchema(
      id: 'mod123',
      name: 'Sales',
      tabs: [tab],
      version: '1.0',
      icon: 'shopping_cart',
      primaryColor: '#3B82F6',
      settings: {},
      dashboard: DashboardConfig(cards: []),
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
      ],
      child: MaterialApp(
        home: DynamicFormScreen(
          tab: tab,
          module: module,
          primaryColor: Colors.blue,
        ),
      ),
    );
  }

  testWidgets('DynamicFormScreen validates and saves', (WidgetTester tester) async {
    await tester.pumpWidget(createFormScreen());

    expect(find.text('NEW ORDERS'), findsOneWidget);

    // Try saving without data
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    expect(find.text('This field is required'), findsOneWidget);

    // Enter data
    await tester.enterText(find.byType(TextFormField), 'John Doe');
    
    when(() => mockDriveService.saveRecord(any(), any(), any(), any()))
        .thenAnswer((_) async {});

    await tester.tap(find.text('SAVE'));
    
    // It has a Future.delayed(300ms) inside _saveForm
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    verify(() => mockDriveService.saveRecord('mod123', 'Sales', 'tab1', any())).called(1);
  });
}
