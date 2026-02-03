import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/services/drive_service.dart';

class MockDriveService extends Mock implements DriveService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  
  late SchemaProvider schemaProvider;
  late MockDriveService mockDriveService;

  setUp(() {
    mockDriveService = MockDriveService();
    schemaProvider = SchemaProvider(driveService: mockDriveService, userEmail: 'test@example.com');
  });

  group('SchemaProvider Tests', () {
    test('updateMemoryCache updates and notifies', () {
      final module = ModuleSchema(
        id: 'm1',
        name: 'test',
        icon: 'i',
        primaryColor: 'c',
        version: '1',
        settings: {},
        tabs: [],
        dashboard: DashboardConfig(cards: []),
      );

      bool notified = false;
      schemaProvider.addListener(() {
        notified = true;
      });

      schemaProvider.updateMemoryCache('m1', module);
      expect(schemaProvider.getFromMemory('m1'), module);
      expect(notified, isTrue);

      schemaProvider.updateMemoryCache('m1', null);
      expect(schemaProvider.getFromMemory('m1'), isNull);
    });

    test('saveConfig success', () async {
      final module = ModuleSchema(
        id: 'm1',
        name: 'test',
        icon: 'i',
        primaryColor: 'c',
        version: '1',
        settings: {},
        tabs: [],
        dashboard: DashboardConfig(cards: []),
      );

      when(() => mockDriveService.getOrCreateSubFolder(any(), any())).thenAnswer((_) async => 'folder123');
      when(() => mockDriveService.getFileId(any(), any())).thenAnswer((_) async => null);
      when(() => mockDriveService.createModuleConfig(any(), any(), any())).thenAnswer((_) async => {'settings': 'new_file_id', 'dashboard': 'd_id', 'tabs': 't_id'});
      when(() => mockDriveService.getFileModifiedTime(any())).thenAnswer((_) async => DateTime.now());
      when(() => mockDriveService.updateModuleConfig(any(), any())).thenAnswer((_) async => {});
      when(() => mockDriveService.writeDashboardById(any(), any())).thenAnswer((_) async => {});
      when(() => mockDriveService.writeTabsById(any(), any())).thenAnswer((_) async => {});
      
      final result = await schemaProvider.saveConfig(module, settingsId: 'new_file_id');
      expect(result, isTrue);
      expect(schemaProvider.getFromMemory('m1'), module);
    });

    test('saveConfig failure returns false', () async {
      when(() => mockDriveService.getOrCreateSubFolder(any(), any())).thenThrow(Exception('fail'));
      final module = ModuleSchema(id: 'm1', name: 't', icon: 'i', primaryColor: 'c', version: '1', settings: {}, tabs: [], dashboard: DashboardConfig(cards: []));
      final result = await schemaProvider.saveConfig(module);
      expect(result, isFalse);
    });

    test('notifyUpdate notifies listeners', () {
      bool notified = false;
      schemaProvider.addListener(() {
        notified = true;
      });
      schemaProvider.notifyUpdate();
      expect(notified, isTrue);
    });
  });
}
