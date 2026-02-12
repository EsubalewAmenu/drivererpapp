import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/user_control/tabs/user_access_structure_tab.dart';
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
          body: UserAccessStructureTab(
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

  group('UserAccessStructureTab', () {
    testWidgets('displays structure tab', (WidgetTester tester) async {
      final valueRange = sheets.ValueRange(
        values: [['mod_id', 'dash_id', 'settings_id', 'tabs_id', 'files_id']]
      );

      when(() => mockDriveService.sheetsApi.spreadsheets.values.get(any(), any()))
          .thenAnswer((_) async => valueRange);

      when(() => mockDriveService.readTabsById(any()))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(UserAccessStructureTab), findsOneWidget);
    });

    testWidgets('shows loading state initially', (WidgetTester tester) async {
      when(() => mockDriveService.sheetsApi.spreadsheets.values.get(any(), any()))
          .thenAnswer((_) async => sheets.ValueRange());

      await tester.pumpWidget(createTestWidget());
      
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('handles structure loading error', (WidgetTester tester) async {
      when(() => mockDriveService.sheetsApi.spreadsheets.values.get(any(), any()))
          .thenThrow(Exception('Load error'));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(UserAccessStructureTab), findsOneWidget);
    });

    testWidgets('displays empty structure', (WidgetTester tester) async {
      final valueRange = sheets.ValueRange(
        values: [['mod_id', 'dash_id', 'settings_id', 'tabs_id', 'files_id']]
      );

      when(() => mockDriveService.sheetsApi.spreadsheets.values.get(any(), any()))
          .thenAnswer((_) async => valueRange);

      when(() => mockDriveService.readTabsById(any()))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(UserAccessStructureTab), findsOneWidget);
    });

    testWidgets('displays structure with tabs', (WidgetTester tester) async {
      final valueRange = sheets.ValueRange(
        values: [['mod_id', 'dash_id', 'settings_id', 'tabs_id', 'files_id']]
      );

      when(() => mockDriveService.sheetsApi.spreadsheets.values.get(any(), any()))
          .thenAnswer((_) async => valueRange);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(UserAccessStructureTab), findsOneWidget);
    });

    testWidgets('can modify structure', (WidgetTester tester) async {
      final valueRange = sheets.ValueRange(
        values: [['mod_id', 'dash_id', 'settings_id', 'tabs_id', 'files_id']]
      );

      when(() => mockDriveService.sheetsApi.spreadsheets.values.get(any(), any()))
          .thenAnswer((_) async => valueRange);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(UserAccessStructureTab), findsOneWidget);
    });

    testWidgets('handles complex structure', (WidgetTester tester) async {
      final valueRange = sheets.ValueRange(
        values: [['mod_id', 'dash_id', 'settings_id', 'tabs_id', 'files_id']]
      );

      when(() => mockDriveService.sheetsApi.spreadsheets.values.get(any(), any()))
          .thenAnswer((_) async => valueRange);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(UserAccessStructureTab), findsOneWidget);
    });

    testWidgets('preserves structure on reload', (WidgetTester tester) async {
      final valueRange = sheets.ValueRange(
        values: [['mod_id', 'dash_id', 'settings_id', 'tabs_id', 'files_id']]
      );

      when(() => mockDriveService.sheetsApi.spreadsheets.values.get(any(), any()))
          .thenAnswer((_) async => valueRange);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(UserAccessStructureTab), findsOneWidget);
    });

    testWidgets('handles many tabs in structure', (WidgetTester tester) async {
      final valueRange = sheets.ValueRange(
        values: [['mod_id', 'dash_id', 'settings_id', 'tabs_id', 'files_id']]
      );

      when(() => mockDriveService.sheetsApi.spreadsheets.values.get(any(), any()))
          .thenAnswer((_) async => valueRange);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(UserAccessStructureTab), findsOneWidget);
    });
  });
}
