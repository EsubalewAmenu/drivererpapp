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

void main() {
  late WorkspaceProvider workspaceProvider;
  late MockDriveService mockDriveService;
  late MockDriveApi mockDriveApi;
  late MockFilesResource mockFilesResource;

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
  });
}
