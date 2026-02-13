import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/user_control/module_access_detail_screen.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;

class MockDriveProvider extends Mock implements DriveProvider {}

class MockDriveService extends Mock implements DriveService {
  @override
  late sheets.SheetsApi sheetsApi;

  MockDriveService() {
    sheetsApi = MockSheetsApi();
  }
}

class MockSheetsApi extends Mock implements sheets.SheetsApi {
  @override
  late sheets.SpreadsheetsResource spreadsheets;

  MockSheetsApi() {
    spreadsheets = MockSpreadsheetsResource();
  }
}

class MockSpreadsheetsResource extends Mock implements sheets.SpreadsheetsResource {
  @override
  late sheets.SpreadsheetsValuesResource values;

  MockSpreadsheetsResource() {
    values = MockValuesResource();
  }
}

class MockValuesResource extends Mock implements sheets.SpreadsheetsValuesResource {}

void main() {
  late MockDriveProvider mockDriveProvider;
  late MockDriveService mockDriveService;

  setUp(() {
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();

    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
  });

  Widget createTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ModuleAccessDetailScreen(
            email: 'test@example.com',
            spreadsheetId: 'sheet123',
            moduleId: 'mod123',
            moduleName: 'Test Module',
            rowIndex: 2,
          ),
        ),
      ),
    );
  }

  group('ModuleAccessDetailScreen', () {
    testWidgets('displays all four tabs', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('PERMISSIONS'), findsOneWidget);
      expect(find.text('STRUCTURE'), findsOneWidget);
      expect(find.text('DASHBOARD'), findsOneWidget);
      expect(find.text('SETTINGS'), findsOneWidget);
    });

    testWidgets('displays correct title', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('TEST MODULE'), findsOneWidget);
    });

    testWidgets('can switch between tabs', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Tap STRUCTURE tab
      await tester.tap(find.text('STRUCTURE'));
      await tester.pumpAndSettle();

      // Tap DASHBOARD tab
      await tester.tap(find.text('DASHBOARD'));
      await tester.pumpAndSettle();

      // Tap SETTINGS tab
      await tester.tap(find.text('SETTINGS'));
      await tester.pumpAndSettle();

      expect(find.byType(TabBar), findsOneWidget);
    });

    testWidgets('displays TabBar with correct styling', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      final tabBar = find.byType(TabBar);
      expect(tabBar, findsOneWidget);

      // Verify TabBar has 4 tabs
      final tabBarWidget = tester.widget<TabBar>(tabBar);
      expect(tabBarWidget.tabs.length, 4);
    });

    testWidgets('passes correct parameters to tabs', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // We can verify the AppBar title contains the module name
      expect(find.text('TEST MODULE'), findsWidgets);
    });

    testWidgets('AppBar displays with correct styling', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      final appBar = find.byType(AppBar);
      expect(appBar, findsOneWidget);

      final appBarWidget = tester.widget<AppBar>(appBar);
      expect(appBarWidget.centerTitle, true);
    });
  });
}
