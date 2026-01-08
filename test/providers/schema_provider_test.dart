import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/models/schema_models.dart';

class MockDriveService extends Mock implements DriveService {}

void main() {
  late SchemaProvider schemaProvider;
  late MockDriveService mockDriveService;

  setUpAll(() {
    registerFallbackValue(ModuleSchema(
      id: 'fallback',
      name: 'Fallback',
      icon: 'help',
      primaryColor: '#000000',
      version: '1.0',
      settings: {},
      dashboard: DashboardConfig(cards: []),
      tabs: [],
    ));
  });

  setUp(() {
    mockDriveService = MockDriveService();
    schemaProvider = SchemaProvider(driveService: mockDriveService, userEmail: 'test@example.com');
  });

  group('SchemaProvider', () {
    final module = ModuleSchema(
      id: 'mod1',
      name: 'Test Module',
      icon: 'edit',
      primaryColor: '#FF5722',
      version: '1.2',
      settings: {},
      dashboard: DashboardConfig(cards: []),
      tabs: [],
    );

    test('updateMemoryCache updates memory and notifies listeners', () {
      bool notified = false;
      schemaProvider.addListener(() {
        notified = true;
      });

      schemaProvider.updateMemoryCache('mod1', module);
      expect(schemaProvider.getFromMemory('mod1'), module);
      expect(notified, isTrue);
    });

    test('saveConfig calls SchemaService (and DriveService) and updates memory', () async {
      // Mock the DriveService calls that SchemaService.saveModuleConfig uses
      when(() => mockDriveService.getOrCreateSubFolder(any(), any()))
          .thenAnswer((_) async => 'folder_id');
      when(() => mockDriveService.getFileId(any(), any()))
          .thenAnswer((_) async => 'file_id');
      when(() => mockDriveService.createModuleConfig(any(), any(), any()))
          .thenAnswer((_) async => 'file_id');
      when(() => mockDriveService.updateModuleConfig(any(), any()))
          .thenAnswer((_) async => {});
      when(() => mockDriveService.getFileModifiedTime(any()))
          .thenAnswer((_) async => DateTime.now());

      final results = await schemaProvider.saveConfig(module);

      expect(results, isTrue);
      expect(schemaProvider.getFromMemory('mod1'), module);
      
      // verify calls - depend on if it exists or not
      // for newly created vs updated
    });
  });
}
