import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drivererpapp/services/schema_service.dart';
import 'package:drivererpapp/services/drive_service.dart';

class MockDriveService extends Mock implements DriveService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SchemaService schemaService;
  late MockDriveService mockDriveService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockDriveService = MockDriveService();
    schemaService = SchemaService(driveService: mockDriveService);
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
      when(() => mockDriveService.getFileId('mod1', 'config')).thenAnswer((_) async => null);
      
      final result = await schemaService.syncConfig('mod1');
      expect(result, isNull);
    });

    test('syncConfig returns null if local meta matches remote', () async {
      final testConfig = {'tabs': []};
      final modifiedTime = DateTime.utc(2024, 1, 1);
      
      // Setup local cache
      await schemaService.cacheConfig('mod1', testConfig, fileId: 'file123', modifiedTime: modifiedTime.toIso8601String());
      
      // Setup remote mock
      when(() => mockDriveService.getFileId('mod1', 'config')).thenAnswer((_) async => 'file123');
      when(() => mockDriveService.getFileModifiedTime('file123')).thenAnswer((_) async => modifiedTime);
      
      final result = await schemaService.syncConfig('mod1');
      expect(result, isNull);
      verifyNever(() => mockDriveService.readModuleConfig(any()));
    });

    test('syncConfig returns new config and updates cache if remote changed', () async {
      final oldConfig = {'v': 1};
      final oldTime = DateTime.utc(2024, 1, 1).toIso8601String();
      
      final newConfig = {'v': 2};
      final newTime = DateTime.utc(2024, 1, 2);
      
      // Setup local cache
      await schemaService.cacheConfig('mod1', oldConfig, fileId: 'file123', modifiedTime: oldTime);
      
      // Setup remote mock
      when(() => mockDriveService.getFileId('mod1', 'config')).thenAnswer((_) async => 'file123');
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
  });
}
