import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:drivererpapp/features/add_module/module_import_service.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:drivererpapp/services/drive_service.dart';

class MockDriveService extends Mock implements DriveService {}
class MockDriveApi extends Mock implements drive.DriveApi {}
class MockDriveFilesResource extends Mock implements drive.FilesResource {}
class MockSheetsApi extends Mock implements sheets.SheetsApi {}
class MockSpreadsheetsResource extends Mock implements sheets.SpreadsheetsResource {}
class MockValuesResource extends Mock implements sheets.SpreadsheetsValuesResource {}
class MockAuthService extends Mock implements AuthService {}
class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

void main() {
  late MockDriveService mockDriveService;
  late MockDriveApi mockDriveApi;
  late MockDriveFilesResource mockFilesResource;
  late MockSheetsApi mockSheetsApi;
  late MockSpreadsheetsResource mockSpreadsheetsResource;
  late MockValuesResource mockValuesResource;
  late MockAuthService mockAuthService;
  late MockGoogleSignInAccount mockUser;
  late WorkspaceProvider workspaceProvider;

  setUpAll(() {
    registerFallbackValue(drive.File());
    registerFallbackValue(sheets.Spreadsheet());
    registerFallbackValue(sheets.ValueRange());
    registerFallbackValue(Uri());
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockDriveService = MockDriveService();
    mockDriveApi = MockDriveApi();
    mockFilesResource = MockDriveFilesResource();
    mockSheetsApi = MockSheetsApi();
    mockSpreadsheetsResource = MockSpreadsheetsResource();
    mockValuesResource = MockValuesResource();
    mockAuthService = MockAuthService();
    mockUser = MockGoogleSignInAccount();

    when(() => mockDriveService.driveApi).thenReturn(mockDriveApi);
    when(() => mockDriveApi.files).thenReturn(mockFilesResource);
    when(() => mockDriveService.sheetsApi).thenReturn(mockSheetsApi);
    when(() => mockSheetsApi.spreadsheets).thenReturn(mockSpreadsheetsResource);
    when(() => mockSpreadsheetsResource.values).thenReturn(mockValuesResource);

    when(() => mockUser.email).thenReturn('user@example.com');
    when(() => mockAuthService.currentUser).thenReturn(mockUser);

    workspaceProvider = WorkspaceProvider();
    workspaceProvider.setWorkspace(drive.File()..id = 'ws1'..name = 'Workspace');
    await workspaceProvider.saveUserAccessSpreadsheetId('ua1');

    when(() => mockFilesResource.get(
      any(),
      $fields: any(named: r'$fields'),
      supportsAllDrives: any(named: 'supportsAllDrives'),
    )).thenAnswer((_) async => drive.File()..id = 'sheet1'..name = 'My Sheet');

    when(() => mockSpreadsheetsResource.get(any())).thenAnswer((_) async {
      final sheetProps = sheets.SheetProperties()..title = 'Sheet1';
      final sheet = sheets.Sheet()..properties = sheetProps;
      return sheets.Spreadsheet()..sheets = [sheet];
    });

    when(() => mockValuesResource.get(any(), any())).thenAnswer((_) async => sheets.ValueRange(values: [
          ['name', 'age']
        ]));

    when(() => mockDriveService.createWorkspace(any(), any())).thenAnswer((_) async => drive.File()..id = 'mod1');
    when(() => mockDriveService.getOrCreateSubFolder(any(), any())).thenAnswer((invocation) async {
      final folderName = invocation.positionalArguments[1] as String;
      if (folderName == 'module_files') return 'mfiles';
      return 'config1';
    });
    when(() => mockDriveService.createModuleConfig(any(), any(), any())).thenAnswer((_) async => {
          'settings': 'sid',
          'dashboard': 'did',
          'tabs': 'tid',
        });
    when(() => mockDriveService.upsertUserAccessModule(any(), any(), any(), any(), any(), any(), any(), moduleType: any(named: 'moduleType')))
      .thenAnswer((_) async {});
  });

  test('imports spreadsheet as module successfully', () async {
    final service = ModuleImportService(
      driveService: mockDriveService,
      workspaceProvider: workspaceProvider,
      authService: mockAuthService,
    );

    final result = await service.importSpreadsheetAsModule('sheet1');

    expect(result.moduleId, 'mod1');
    expect(result.moduleName, 'My Sheet');
    verify(() => mockDriveService.createWorkspace('ws1', 'My Sheet')).called(1);
    verify(() => mockDriveService.getOrCreateSubFolder('mod1', 'module_files')).called(1);
    verify(() => mockDriveService.getOrCreateSubFolder('mod1', 'config')).called(1);
    verify(() => mockDriveService.upsertUserAccessModule('ua1', 'mod1', 'My Sheet', 'did', 'sid', 'tid', 'mfiles', moduleType: 'module')).called(1);
  });

  test('creates default column when header is empty', () async {
    when(() => mockValuesResource.get(any(), any())).thenAnswer((_) async => sheets.ValueRange(values: []));

    final service = ModuleImportService(
      driveService: mockDriveService,
      workspaceProvider: workspaceProvider,
      authService: mockAuthService,
    );

    await service.importSpreadsheetAsModule('sheet1');

    final captured = verify(() => mockDriveService.createModuleConfig(any(), any(), captureAny())).captured;
    final config = captured.first as Map<String, dynamic>;
    final tabs = (config['tabs'] as List).first as Map;
    final columns = (tabs['columns'] as List).cast<Map>();
    expect(columns.length, 1);
    expect(columns.first['key'], 'col_1');
  });

  test('throws when workspace is missing', () async {
    workspaceProvider.clearWorkspace();

    final service = ModuleImportService(
      driveService: mockDriveService,
      workspaceProvider: workspaceProvider,
      authService: mockAuthService,
    );

    expect(() => service.importSpreadsheetAsModule('sheet1'), throwsException);
  });

  test('throws when user access spreadsheet is missing', () async {
    final provider = WorkspaceProvider();
    provider.setWorkspace(drive.File()..id = 'ws1'..name = 'Workspace');
    await provider.saveUserAccessSpreadsheetId(null);

    final service = ModuleImportService(
      driveService: mockDriveService,
      workspaceProvider: provider,
      authService: mockAuthService,
    );

    await expectLater(service.importSpreadsheetAsModule('sheet1'), throwsException);
  });

  test('throws when user email is missing', () async {
    when(() => mockAuthService.currentUser).thenReturn(null);

    final service = ModuleImportService(
      driveService: mockDriveService,
      workspaceProvider: workspaceProvider,
      authService: mockAuthService,
    );

    expect(() => service.importSpreadsheetAsModule('sheet1'), throwsException);
  });
}
