import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drivererpapp/services/schema_service.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/models/schema_models.dart';

class MockDriveService extends Mock implements DriveService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SchemaService schemaService;
  late MockDriveService mockDriveService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockDriveService = MockDriveService();
    schemaService = SchemaService(driveService: mockDriveService, userEmail: 'test@example.com');

    // Default mocks for folder creation/lookup to avoid MissingStubError
    when(() => mockDriveService.getOrCreateSubFolder(any(), any())).thenAnswer((_) async => 'config_folder_id');
    // Generic fallback stubs to ensure async-returning methods return Futures even if specific tests don't stub them
    when(() => mockDriveService.getFileId(any(), any())).thenAnswer((_) async => null);
    when(() => mockDriveService.getFileModifiedTime(any())).thenAnswer((_) async => null);
    when(() => mockDriveService.createModuleConfig(any(), any(), any())).thenAnswer((_) async => 'new_file_id');
    when(() => mockDriveService.updateModuleConfig(any(), any())).thenAnswer((_) async => {});
    when(() => mockDriveService.ensureUserAccessFolder(any())).thenAnswer((_) async => 'ua_folder');
    when(() => mockDriveService.ensureUserAccessSpreadsheet(any(), any())).thenAnswer((_) async => 'ua_sheet');
    when(() => mockDriveService.upsertUserAccessModule(any(), any(), any(), any(), any(), any())).thenAnswer((_) async => {});
  });

  group('SchemaService', () {
    test('loadModules from assets', () async {
      // Mock rootBundle
      final testSchema = {
        'id': 'inventory',
        'name': 'Inventory',
        'icon': 'inventory',
        'primaryColor': '#F59E0B',
        'version': '1.0.0',
        'settings': {},
        'tabs': [],
        'dashboard': {'cards': []}
      };

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        (ByteData? message) async {
          final Uint8List encoded = utf8.encoder.convert(jsonEncode(testSchema));
          return encoded.buffer.asByteData();
        },
      );

      final modules = await schemaService.loadModules();
      expect(modules.length, 1);
      expect(modules[0].id, 'inventory');
    });

    test('getCachedConfig returns null when nothing is cached', () async {
      final config = await schemaService.getCachedConfig('mod1');
      expect(config, isNull);
    });

    test('cacheConfig and getCachedConfig work correctly', () async {
      final testConfig = {'tabs': [], 'settings': {}};
      await schemaService.cacheConfig('mod1', testConfig);
      
      final cached = await schemaService.getCachedConfig('mod1');
      expect(cached, equals(testConfig));
    });

    test('cacheConfig with meta stores metadata', () async {
      final testConfig = {'tabs': []};
      final modifiedTime = DateTime.utc(2024, 1, 1).toIso8601String();
      await schemaService.cacheConfig('mod1', testConfig, fileId: 'file123', modifiedTime: modifiedTime);
      
      final meta = await schemaService.getCachedMeta('mod1');
      expect(meta?['fileId'], equals('file123'));
      expect(meta?['modifiedTime'], equals(modifiedTime));
    });

    test('syncConfig returns null if remote file not found', () async {
      when(() => mockDriveService.getFileId('config_folder_id', 'test@example.com_settings')).thenAnswer((_) async => null);
      
      final result = await schemaService.syncConfig('mod1');
      expect(result, isNull);
    });

    test('syncConfig returns null if local meta matches remote', () async {
      final testConfig = {'tabs': []};
      final modifiedTime = DateTime.utc(2024, 1, 1);
      
      // Setup local cache
      await schemaService.cacheConfig('mod1', testConfig, fileId: 'file123', modifiedTime: modifiedTime.toIso8601String());
      
      // Setup remote mock (Finding in new location)
      when(() => mockDriveService.getFileId('config_folder_id', 'test@example.com_settings')).thenAnswer((_) async => 'file123');
      when(() => mockDriveService.getFileModifiedTime('file123')).thenAnswer((_) async => modifiedTime);
      
      final result = await schemaService.syncConfig('mod1');
      expect(result, isNull);
      verifyNever(() => mockDriveService.readModuleConfig(any()));
    });

    test('syncConfig returns new config and updates cache if remote changed', () async {
      final oldConfig = {'settings': {'v': 1}};
      final oldTime = DateTime.utc(2024, 1, 1).toIso8601String();
      
      final newConfig = {'settings': {'v': 2}};
      final newTime = DateTime.utc(2024, 1, 2);
      
      // Setup local cache
      await schemaService.cacheConfig('mod1', oldConfig, fileId: 'file123', modifiedTime: oldTime);
      
      // Setup remote mock (finding in new location)
      when(() => mockDriveService.getFileId('config_folder_id', 'test@example.com_settings')).thenAnswer((_) async => 'file123');
      when(() => mockDriveService.getFileModifiedTime('file123')).thenAnswer((_) async => newTime);
      when(() => mockDriveService.readModuleConfig('file123')).thenAnswer((_) async => newConfig);
      
      final result = await schemaService.syncConfig('mod1');
      
      expect(result, equals(newConfig));
      
      // Verify cache updated
      final cached = await schemaService.getCachedConfig('mod1');
      expect(cached, equals(newConfig));
      
      final meta = await schemaService.getCachedMeta('mod1');
      expect(meta?['modifiedTime'], equals(newTime.toIso8601String()));
    });

    test('saveModuleConfig updates existing remote config', () async {
      final module = ModuleSchema(
        id: 'mod1', name: 'M1', icon: 'i', primaryColor: '#0', version: '1', settings: {},
        tabs: [], dashboard: DashboardConfig(cards: [])
      );
      final modifiedTime = DateTime.now();

      when(() => mockDriveService.getFileId('config_folder_id', 'test@example.com_settings')).thenAnswer((_) async => 'file123');
      when(() => mockDriveService.updateModuleConfig(any(), any())).thenAnswer((_) async => {});
      when(() => mockDriveService.getFileModifiedTime('file123')).thenAnswer((_) async => modifiedTime);

      await schemaService.saveModuleConfig('mod1', module);

      verify(() => mockDriveService.updateModuleConfig('file123', any())).called(1);
      final cached = await schemaService.getCachedConfig('mod1');
      expect(cached, isNotNull);
      expect(cached?['settings'], equals({}));
    });

    test('saveModuleConfig creates new remote config if not exists', () async {
       final module = ModuleSchema(
        id: 'mod1', name: 'M1', icon: 'i', primaryColor: '#0', version: '1', settings: {},
        tabs: [], dashboard: DashboardConfig(cards: [])
      );
      
      when(() => mockDriveService.getFileId('config_folder_id', 'test@example.com_settings')).thenAnswer((_) async => null);
      when(() => mockDriveService.createModuleConfig(any(), any(), any())).thenAnswer((_) async => 'new_file_id');
      when(() => mockDriveService.getFileModifiedTime('new_file_id')).thenAnswer((_) async => DateTime.now());

      await schemaService.saveModuleConfig('mod1', module);

      verify(() => mockDriveService.createModuleConfig('config_folder_id', 'test@example.com_settings', any())).called(1);
    });
  });
}
