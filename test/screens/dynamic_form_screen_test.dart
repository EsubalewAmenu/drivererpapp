import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/dynamic_form_screen.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/services/auth_service.dart';

class MockDriveProvider extends Mock implements DriveProvider {}
class MockDriveService extends Mock implements DriveService {}
class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockDriveProvider mockDriveProvider;
  late MockDriveService mockDriveService;
  late MockAuthService mockAuthService;

  setUpAll(() {
    registerFallbackValue(Map<String, dynamic>.from({}));
  });

  setUp(() {
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();
    mockAuthService = MockAuthService();
    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockAuthService.currentUser).thenReturn(null);
  });

  Widget createFormScreen() {
    final tab = TabConfig(
      id: 'tab1',
      label: 'Orders',
      fileId: 'spreadsheet_123',
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
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
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
    
    when(() => mockDriveService.saveRecordBySpreadsheetId(any(), any(), any()))
        .thenAnswer((_) async {});

    await tester.tap(find.text('SAVE'));
    
    // It has a Future.delayed(300ms) inside _saveForm
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    verify(() => mockDriveService.saveRecordBySpreadsheetId('spreadsheet_123', 'tab1', any())).called(1);
  });
}
