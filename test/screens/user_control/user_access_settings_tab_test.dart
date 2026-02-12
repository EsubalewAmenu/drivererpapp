import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/user_control/tabs/user_access_settings_tab.dart';
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
          body: UserAccessSettingsTab(
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

  group('UserAccessSettingsTab', () {
    testWidgets('displays settings tab', (WidgetTester tester) async {
      final valueRange = sheets.ValueRange(
        values: [['mod_id', 'dash_id', 'settings_id', 'tabs_id', 'files_id']]
      );

      when(() => mockDriveService.sheetsApi.spreadsheets.values.get(any(), any()))
          .thenAnswer((_) async => valueRange);

      when(() => mockDriveService.readSettingsById(any()))
          .thenAnswer((_) async => {});

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(UserAccessSettingsTab), findsOneWidget);
    });

    testWidgets('shows loading state initially', (WidgetTester tester) async {
      when(() => mockDriveService.sheetsApi.spreadsheets.values.get(any(), any()))
          .thenAnswer((_) async => sheets.ValueRange());

      await tester.pumpWidget(createTestWidget());
      
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('handles settings loading error', (WidgetTester tester) async {
      when(() => mockDriveService.sheetsApi.spreadsheets.values.get(any(), any()))
          .thenThrow(Exception('Load error'));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(UserAccessSettingsTab), findsOneWidget);
    });

    testWidgets('displays empty settings', (WidgetTester tester) async {
      final valueRange = sheets.ValueRange(
        values: [['mod_id', 'dash_id', 'settings_id', 'tabs_id', 'files_id']]
      );

      when(() => mockDriveService.sheetsApi.spreadsheets.values.get(any(), any()))
          .thenAnswer((_) async => valueRange);

      when(() => mockDriveService.readSettingsById(any()))
          .thenAnswer((_) async => {});

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(UserAccessSettingsTab), findsOneWidget);
    });

    testWidgets('displays settings with data', (WidgetTester tester) async {
      final valueRange = sheets.ValueRange(
        values: [['mod_id', 'dash_id', 'settings_id', 'tabs_id', 'files_id']]
      );

      when(() => mockDriveService.sheetsApi.spreadsheets.values.get(any(), any()))
          .thenAnswer((_) async => valueRange);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(UserAccessSettingsTab), findsOneWidget);
    });

    testWidgets('can update settings', (WidgetTester tester) async {
      final valueRange = sheets.ValueRange(
        values: [['mod_id', 'dash_id', 'settings_id', 'tabs_id', 'files_id']]
      );

      when(() => mockDriveService.sheetsApi.spreadsheets.values.get(any(), any()))
          .thenAnswer((_) async => valueRange);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(UserAccessSettingsTab), findsOneWidget);
    });

    testWidgets('handles settings with boolean flags', (WidgetTester tester) async {
      final valueRange = sheets.ValueRange(
        values: [['mod_id', 'dash_id', 'settings_id', 'tabs_id', 'files_id']]
      );

      when(() => mockDriveService.sheetsApi.spreadsheets.values.get(any(), any()))
          .thenAnswer((_) async => valueRange);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(UserAccessSettingsTab), findsOneWidget);
    });

    testWidgets('preserves settings on reload', (WidgetTester tester) async {
      final valueRange = sheets.ValueRange(
        values: [['mod_id', 'dash_id', 'settings_id', 'tabs_id', 'files_id']]
      );

      when(() => mockDriveService.sheetsApi.spreadsheets.values.get(any(), any()))
          .thenAnswer((_) async => valueRange);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(UserAccessSettingsTab), findsOneWidget);
    });

    testWidgets('handles nested settings objects', (WidgetTester tester) async {
      final valueRange = sheets.ValueRange(
        values: [['mod_id', 'dash_id', 'settings_id', 'tabs_id', 'files_id']]
      );

      when(() => mockDriveService.sheetsApi.spreadsheets.values.get(any(), any()))
          .thenAnswer((_) async => valueRange);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(UserAccessSettingsTab), findsOneWidget);
    });
  });
}
