import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/models/company_model.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';

class MockDriveService extends Mock implements DriveService {}
class MockDriveApi extends Mock implements drive.DriveApi {}
class MockFilesResource extends Mock implements drive.FilesResource {}
class FakeCompany extends Fake implements Company {}

void main() {
  late WorkspaceProvider workspaceProvider;
  late MockDriveService mockDriveService;
  late MockDriveApi mockDriveApi;
  late MockFilesResource mockFilesResource;

  setUpAll(() {
    registerFallbackValue(FakeCompany());
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockDriveService = MockDriveService();
    mockDriveApi = MockDriveApi();
    mockFilesResource = MockFilesResource();

    when(() => mockDriveService.driveApi).thenReturn(mockDriveApi);
    when(() => mockDriveApi.files).thenReturn(mockFilesResource);

    workspaceProvider = WorkspaceProvider(driveService: mockDriveService);
  });

  group('WorkspaceProvider', () {
    test('initial state is correct', () {
      expect(workspaceProvider.currentWorkspace, isNull);
      expect(workspaceProvider.companies, isEmpty);
      expect(workspaceProvider.isLoading, isFalse);
    });

    test('loadCompanies updates state correctly', () async {
      final companies = [
        Company(id: '1', name: 'Test Co', folderId: 'folder1'),
      ];

      when(() => mockDriveService.ensureCompanyRegistry(any()))
          .thenAnswer((_) async => 'registry_id');
      when(() => mockDriveService.getCompanies(any()))
          .thenAnswer((_) async => companies);

      await workspaceProvider.loadCompanies('rootId');

      expect(workspaceProvider.companies, companies);
      expect(workspaceProvider.isLoading, isFalse);
      verify(() => mockDriveService.ensureCompanyRegistry('rootId')).called(1);
      verify(() => mockDriveService.getCompanies('rootId')).called(1);
    });

    test('setWorkspace updates state and saves id', () async {
      final file = drive.File()..id = 'ws1'..name = 'My Workspace';
      
      workspaceProvider.setWorkspace(file);

      expect(workspaceProvider.currentWorkspace, file);
      expect(workspaceProvider.hasWorkspace, isTrue);

      // Give it a moment to save to SharedPreferences
      await Future.delayed(Duration.zero);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_workspace_id'), 'ws1');
    });

    test('clearWorkspace updates state and removes id', () async {
      final file = drive.File()..id = 'ws1'..name = 'My Workspace';
      workspaceProvider.setWorkspace(file);
      await Future.delayed(Duration.zero);
      
      workspaceProvider.clearWorkspace();
      await Future.delayed(Duration.zero);

      expect(workspaceProvider.currentWorkspace, isNull);
      expect(workspaceProvider.hasWorkspace, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('last_workspace_id'), isFalse);
    });

    test('registerNewCompany updates state and calls service', () async {
      final company = Company(id: 'c1', name: 'New Co', folderId: 'f1');
      when(() => mockDriveService.registerCompany(any(), any()))
          .thenAnswer((_) async {});

      await workspaceProvider.registerNewCompany('rootId', company);

      expect(workspaceProvider.companies.contains(company), isTrue);
      expect(workspaceProvider.isLoading, isFalse);
      verify(() => mockDriveService.registerCompany('rootId', company)).called(1);
    });

    test('registerNewCompany handles error', () async {
      final company = Company(id: 'c1', name: 'New Co', folderId: 'f1');
      when(() => mockDriveService.registerCompany(any(), any()))
          .thenThrow(Exception('API error'));

      expect(() => workspaceProvider.registerNewCompany('rootId', company),
          throwsA(isA<Exception>()));
      expect(workspaceProvider.isLoading, isFalse);
    });

    test('restorePreviousSession returns false if no lastId', () async {
      final success = await workspaceProvider.restorePreviousSession();
      expect(success, isFalse);
    });

    test('restorePreviousSession successfully restores via registry', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_workspace_id', 'ws123');

      final companies = [
        Company(id: '1', name: 'Registry Co', folderId: 'ws123'),
      ];

      when(() => mockDriveService.checkRootFolder()).thenAnswer((_) async => 'rootId');
      when(() => mockDriveService.getCompanies('rootId')).thenAnswer((_) async => companies);

      final success = await workspaceProvider.restorePreviousSession();

      expect(success, isTrue);
      expect(workspaceProvider.currentWorkspace?.id, 'ws123');
      expect(workspaceProvider.currentWorkspace?.name, 'Registry Co');
    });

    test('restorePreviousSession falls back to Drive API if registry fails', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_workspace_id', 'ws123');

      final driveFile = drive.File()..id = 'ws123'..name = 'Drive Co';

      when(() => mockDriveService.checkRootFolder()).thenAnswer((_) async => 'rootId');
      when(() => mockDriveService.getCompanies('rootId')).thenThrow(Exception('Registry fail'));
      when(() => mockFilesResource.get(
            any(),
            $fields: any(named: r'$fields'),
            supportsAllDrives: any(named: 'supportsAllDrives'),
          )).thenAnswer((_) async => driveFile);

      final success = await workspaceProvider.restorePreviousSession();

      expect(success, isTrue);
      expect(workspaceProvider.currentWorkspace?.id, 'ws123');
      expect(workspaceProvider.currentWorkspace?.name, 'Drive Co');
    });

    test('restorePreviousSession returns false on total failure', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_workspace_id', 'ws123');

      when(() => mockDriveService.checkRootFolder()).thenAnswer((_) async => 'rootId');
      when(() => mockDriveService.getCompanies('rootId')).thenThrow(Exception('Fail'));
      when(() => mockFilesResource.get(any(), $fields: any(named: r'$fields')))
          .thenThrow(Exception('Critical fail'));

      final success = await workspaceProvider.restorePreviousSession();

      expect(success, isFalse);
    });

    test('loadCompanies handles error gracefully', () async {
      when(() => mockDriveService.ensureCompanyRegistry(any()))
          .thenThrow(Exception('API Fail'));

      await workspaceProvider.loadCompanies('rootId');

      expect(workspaceProvider.isLoading, isFalse);
      expect(workspaceProvider.companies, isEmpty);
    });

    test('methods return early if _driveService is null', () async {
      final nullServiceProv = WorkspaceProvider(driveService: null);
      
      await nullServiceProv.loadCompanies('id');
      expect(nullServiceProv.isLoading, isFalse);

      final restored = await nullServiceProv.restorePreviousSession();
      expect(restored, isFalse);

      await expectLater(nullServiceProv.registerNewCompany('id', Company(id: '1', name: 'X', folderId: 'Y')), 
          completes);
    });

    test('currentCompany returns matching company or null', () async {
      final companies = [
        Company(id: 'c1', name: 'Co 1', folderId: 'f1'),
        Company(id: 'c2', name: 'Co 2', folderId: 'f2'),
      ];
      
      // Inject companies
      when(() => mockDriveService.ensureCompanyRegistry(any())).thenAnswer((_) async => 'reg');
      when(() => mockDriveService.getCompanies(any())).thenAnswer((_) async => companies);
      
      await workspaceProvider.loadCompanies('root');
      
      // No workspace set
      expect(workspaceProvider.currentCompany, isNull);

      // Set workspace matching f2
      workspaceProvider.setWorkspace(drive.File()..id = 'f2'..name = 'Co 2');
      expect(workspaceProvider.currentCompany?.id, 'c2');

      // Set workspace with no match
      workspaceProvider.setWorkspace(drive.File()..id = 'f3');
      expect(workspaceProvider.currentCompany, isNull);
    });

    test('updateCompanyName updates registry and currentWorkspace', () async {
      final initialCompany = Company(id: 'c1', name: 'Old', folderId: 'f1');
      
      // Setup mock state manually
      when(() => mockDriveService.ensureCompanyRegistry(any())).thenAnswer((_) async => 'reg');
      when(() => mockDriveService.getCompanies(any())).thenAnswer((_) async => [initialCompany]);
      await workspaceProvider.loadCompanies('rootId');
      
      workspaceProvider.setWorkspace(drive.File()..id = 'f1'..name = 'Old');

      when(() => mockDriveService.updateCompany(any(), any())).thenAnswer((_) async {});

      await workspaceProvider.updateCompanyName('New Name');

      expect(workspaceProvider.companies.first.name, 'New Name');
      expect(workspaceProvider.currentWorkspace?.name, 'New Name');
      verify(() => mockDriveService.updateCompany('rootId', any(that: isA<Company>().having((c) => c.name, 'name', 'New Name')))).called(1);
    });

    test('updateCompanyLogo updates registry and fetches new URL', () async {
      final initialCompany = Company(id: 'c1', name: 'My Co', folderId: 'f1', logoUrl: 'old');
      
      when(() => mockDriveService.ensureCompanyRegistry(any())).thenAnswer((_) async => 'reg');
      when(() => mockDriveService.getCompanies(any())).thenAnswer((_) async => [initialCompany]);
      await workspaceProvider.loadCompanies('rootId');
      
      workspaceProvider.setWorkspace(drive.File()..id = 'f1'..name = 'My Co');

      when(() => mockDriveService.updateCompanyLogo(any(), any(), any(), any()))
          .thenAnswer((_) async => 'new_logo_url');

      await workspaceProvider.updateCompanyLogo([1, 2], 'png');

      expect(workspaceProvider.companies.first.logoUrl, 'new_logo_url');
      verify(() => mockDriveService.updateCompanyLogo('rootId', 'c1', [1, 2], 'png')).called(1);
    });
  });
}
