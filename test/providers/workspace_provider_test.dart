import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/models/company_model.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mocktail/mocktail.dart';

class MockDriveService extends Mock implements DriveService {}
class MockDriveApi extends Mock implements drive.DriveApi {}
class MockFilesResource extends Mock implements drive.FilesResource {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    registerFallbackValue(Company(id: '', name: '', folderId: ''));
  });

  group('WorkspaceProvider Tests', () {
    test('Initial state should be null', () {
      final provider = WorkspaceProvider();
      expect(provider.currentWorkspace, isNull);
      expect(provider.hasWorkspace, isFalse);
    });

    test('setWorkspace should update state, save to prefs, and notify listeners', () async {
      final provider = WorkspaceProvider();
      final mockFile = drive.File()..name = 'Test Workspace'..id = '123';
      
      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      provider.setWorkspace(mockFile);

      expect(provider.currentWorkspace, equals(mockFile));
      expect(provider.currentWorkspace?.name, 'Test Workspace');
      expect(provider.hasWorkspace, isTrue);
      expect(notified, isTrue);
      
      // Wait for async SharedPreferences save
      await Future.delayed(Duration.zero);
      final savedId = await WorkspaceProvider.getLastWorkspaceId();
      expect(savedId, '123');
    });

    test('loadCompanies should fetch companies from DriveService', () async {
      final provider = WorkspaceProvider(driveService: mockDriveService);
      final mockCompanies = <Company>[
        Company(id: '1', name: 'Co 1', folderId: 'f1'),
      ];

      when(() => mockDriveService.ensureCompanyRegistry(any()))
          .thenAnswer((_) async => 'registry_id');
      when(() => mockDriveService.getCompanies(any()))
          .thenAnswer((_) async => mockCompanies);

      await provider.loadCompanies('root_id');

      expect(provider.companies, mockCompanies);
      expect(provider.isLoading, isFalse);
      verify(() => mockDriveService.ensureCompanyRegistry('root_id')).called(1);
      verify(() => mockDriveService.getCompanies('root_id')).called(1);
    });

    test('registerNewCompany should update state and call DriveService', () async {
      final provider = WorkspaceProvider(driveService: mockDriveService);
      final newCo = Company(id: '2', name: 'New Co', folderId: 'f2');

      when(() => mockDriveService.registerCompany(any(), any()))
          .thenAnswer((_) async {});

      await provider.registerNewCompany('root_id', newCo);

      expect(provider.companies.contains(newCo), isTrue);
      verify(() => mockDriveService.registerCompany('root_id', newCo)).called(1);
    });

    test('restorePreviousSession should use registry data if available', () async {
      SharedPreferences.setMockInitialValues({'last_workspace_id': 'f1'});
      final provider = WorkspaceProvider(driveService: mockDriveService);
      
      final mockCompanies = <Company>[
        Company(id: '1', name: 'Registry Name', folderId: 'f1'),
      ];

      when(() => mockDriveService.checkRootFolder()).thenAnswer((_) async => 'root_id');
      when(() => mockDriveService.getCompanies('root_id')).thenAnswer((_) async => mockCompanies);

      final result = await provider.restorePreviousSession();

      expect(result, isTrue);
      expect(provider.currentWorkspace?.id, 'f1');
      expect(provider.currentWorkspace?.name, 'Registry Name');
    });

    test('restorePreviousSession should fallback to Drive API lookup if not in registry', () async {
      SharedPreferences.setMockInitialValues({'last_workspace_id': 'f2'});
      final provider = WorkspaceProvider(driveService: mockDriveService);
      
      final driveFile = drive.File()..id = 'f2'..name = 'Drive Name';

      when(() => mockDriveService.checkRootFolder()).thenAnswer((_) async => 'root_id');
      when(() => mockDriveService.getCompanies('root_id')).thenAnswer((_) async => []);
      when(() => mockFilesResource.get(any(), $fields: any(named: r'$fields')))
          .thenAnswer((_) async => driveFile);

      final result = await provider.restorePreviousSession();

      expect(result, isTrue);
      expect(provider.currentWorkspace?.id, 'f2');
      expect(provider.currentWorkspace?.name, 'Drive Name');
    });

    test('clearWorkspace should reset state and notify listeners', () {
      final provider = WorkspaceProvider();
      final mockFile = drive.File()..name = 'Test Workspace'..id = '123';
      provider.setWorkspace(mockFile);
      
      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      provider.clearWorkspace();

      expect(provider.currentWorkspace, isNull);
      expect(provider.hasWorkspace, isFalse);
      expect(notified, isTrue);
    });
  });
}
