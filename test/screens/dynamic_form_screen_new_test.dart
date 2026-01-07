import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/dynamic_form_screen_new.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/theme/app_theme.dart';

class MockDriveProvider extends Mock implements DriveProvider {}
class MockDriveService extends Mock implements DriveService {}

void main() {
  late MockDriveProvider mockDriveProvider;
  late MockDriveService mockDriveService;
  late TabConfig testTab;
  late ModuleSchema testModule;

  setUp(() {
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();

    testTab = TabConfig(
      id: 'tab1',
      label: 'Test Tab',
      columns: [
        ColumnConfig(key: 'name', label: 'Name', type: 'text', isRequired: true),
        ColumnConfig(key: 'age', label: 'Age', type: 'number', defaultValue: '25'),
      ],
    );

    testModule = ModuleSchema(
      id: 'mod1',
      name: 'Test Module',
      icon: 'star',
      primaryColor: '#000000',
      version: '1',
      settings: {},
      tabs: [testTab],
      dashboard: DashboardConfig(kpiCards: []),
    );

    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockDriveService.saveRecord(any(), any(), any(), any())).thenAnswer((_) async {});
  });

  Widget createWidgetUnderTest() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DynamicFormScreen(
                        tab: testTab,
                        primaryColor: Colors.blue,
                        module: testModule,
                      ),
                    ),
                  );
                },
                child: const Text('OPEN FORM'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('DynamicFormScreen renders fields correctly', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.tap(find.text('OPEN FORM'));
    await tester.pumpAndSettle();

    // Labels are UPPERCASE
    expect(find.text('NAME'), findsOneWidget);
    expect(find.text('AGE'), findsOneWidget);
    
    // Check default value '25'
    expect(find.text('25'), findsOneWidget);
  });

  testWidgets('DynamicFormScreen validates required fields', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.tap(find.text('OPEN FORM'));
    await tester.pumpAndSettle();

    // Tap Save without entering Name
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    // Verify saveRecord was NOT called
    verifyNever(() => mockDriveService.saveRecord(any(), any(), any(), any()));
  });

  testWidgets('DynamicFormScreen saves valid data', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.tap(find.text('OPEN FORM'));
    await tester.pumpAndSettle();

    // Enter Name
    final nameField = find.byType(TextFormField).first;
    await tester.enterText(nameField, 'John Doe');
    await tester.pumpAndSettle();

    // Tap Save
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    // Verify Save call
    verify(() => mockDriveService.saveRecord(
      'mod1', 
      'Test Module', 
      'tab1', 
      any(that: isA<Map<String, dynamic>>()
        .having((m) => m['name'], 'name', 'John Doe')
        .having((m) => m['age'].toString(), 'age', '25')
      ),
    )).called(1);

    // Should have popped back to home
    expect(find.text('OPEN FORM'), findsOneWidget);
  });
}
