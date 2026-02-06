import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drivererpapp/services/schema_service.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/models/schema_models.dart';

class MockDriveService extends Mock implements DriveService {}

class _FakeBundle extends CachingAssetBundle {
  final Map<String, String> _assets;
  _FakeBundle(this._assets);

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (!_assets.containsKey(key)) throw Exception('Unable to load asset: $key');
    return _assets[key]!;
  }

  @override
  Future<ByteData> load(String key) async {
    final val = _assets[key];
    if (val == null) throw Exception('Unable to load asset: $key');
    final bytes = utf8.encode(val);
    final uint8 = Uint8List.fromList(bytes);
    return ByteData.view(uint8.buffer);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SchemaService schemaService;
  late MockDriveService mockDriveService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockDriveService = MockDriveService();
    schemaService = SchemaService(driveService: mockDriveService, userEmail: 'test@example.com');

    when(() => mockDriveService.getOrCreateSubFolder(any(), any())).thenAnswer((_) async => 'config_folder_id');
    when(() => mockDriveService.getFileId(any(), any())).thenAnswer((_) async => null);
    when(() => mockDriveService.getFileModifiedTime(any())).thenAnswer((_) async => null);
    when(() => mockDriveService.createModuleConfig(any(), any(), any())).thenAnswer((_) async => {'settings': 'new_file_id', 'dashboard': 'd_id', 'tabs': 't_id'});
    when(() => mockDriveService.updateModuleConfig(any(), any())).thenAnswer((_) async => {});
    when(() => mockDriveService.readSettingsById(any())).thenAnswer((_) async => null);
    when(() => mockDriveService.readDashboardById(any())).thenAnswer((_) async => null);
    when(() => mockDriveService.readTabsById(any())).thenAnswer((_) async => null);
    when(() => mockDriveService.upsertUserAccessModule(any(), any(), any(), any(), any(), any())).thenAnswer((_) async => {});
  });

  test('getCachedConfig returns null when nothing is cached', () async {
    final config = await schemaService.getCachedConfig('mod1');
    expect(config, isNull);
  });

  test('cacheConfig and getCachedConfig work correctly', () async {
    final testConfig = {'tabs': [], 'settings': {}};
    await schemaService.cacheConfig('mod1', testConfig);

    final cached = await schemaService.getCachedConfig('mod1');
    expect(cached, isNotNull);
    expect(cached!['settings'], isA<Map>());
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

    final result = await schemaService.syncConfig('mod1', settingsId: 'missing');
    expect(result, isNull);
  });

  test('syncConfig returns new config and updates cache if remote changed', () async {
    final oldConfig = {'settings': {'v': 1}};
    final oldTime = DateTime.utc(2024, 1, 1).toIso8601String();

    final newConfig = {'settings': {'v': 2}};
    final newTime = DateTime.utc(2024, 1, 2);

    await schemaService.cacheConfig('mod1', oldConfig, fileId: 'file123', modifiedTime: oldTime);

    when(() => mockDriveService.getFileId('config_folder_id', 'test@example.com_settings')).thenAnswer((_) async => 'file123');
    when(() => mockDriveService.getFileModifiedTime('file123')).thenAnswer((_) async => newTime);
    when(() => mockDriveService.readSettingsById(any())).thenAnswer((_) async => newConfig['settings']);

    final result = await schemaService.syncConfig('mod1', settingsId: 'file123');

    expect(result, equals(newConfig));

    final cached = await schemaService.getCachedConfig('mod1');
    expect(cached, equals(newConfig));

    final meta = await schemaService.getCachedMeta('mod1');
    expect(meta?['modifiedTime'], equals(newTime.toIso8601String()));
  });

  test('saveModuleConfig updates remote config if settingsId provided', () async {
    final module = ModuleSchema(
      id: 'mod1', name: 'M1', icon: 'i', primaryColor: '#0', version: '1', settings: {},
      tabs: [], dashboard: DashboardConfig(cards: [])
    );

    when(() => mockDriveService.getFileModifiedTime('sid123')).thenAnswer((_) async => DateTime.now());

    await schemaService.saveModuleConfig('mod1', module, settingsId: 'sid123');

    verify(() => mockDriveService.updateModuleConfig('sid123', any())).called(1);
    // Verified that createModuleConfig is NOT called as a fallback anymore
    verifyNever(() => mockDriveService.createModuleConfig(any(), any(), any()));
  });

  test('tryLoadModuleAsset returns mapped asset content and null on missing', () async {
    final mapJson = jsonEncode({'inv': 'inventory.json', 'crm': 'crm.json'});
    final invJson = jsonEncode({'id': 'inventory', 'name': 'Inventory'});

    final bundle = _FakeBundle({
      'assets/erp_modules/module_asset_map.json': mapJson,
      'assets/erp_modules/inventory.json': invJson,
    });

    final loaded = await SchemaService.tryLoadModuleAsset('inv', bundle: bundle);
    expect(loaded, isNotNull);
    expect(loaded, contains('Inventory'));

    final missing = await SchemaService.tryLoadModuleAsset('notfound', bundle: bundle);
    expect(missing, isNull);
  });
}
