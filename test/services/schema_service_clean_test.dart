import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drivererpapp/services/schema_service.dart';
import 'package:drivererpapp/services/drive_service.dart';

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
  });

  test('cacheConfig and meta roundtrip', () async {
    await schemaService.cacheConfig('m1', {'settings': {'a': 1}}, fileId: 'f1', modifiedTime: 't1');
    final cfg = await schemaService.getCachedConfig('m1');
    expect(cfg, isNotNull);
    expect(cfg!['settings']['a'], 1);
    final meta = await schemaService.getCachedMeta('m1');
    expect(meta?['fileId'], 'f1');
  });

  test('tryLoadModuleAsset loads mapped asset', () async {
    final mapJson = jsonEncode({'inv': 'inventory.json'});
    final invJson = jsonEncode({'id': 'inv', 'name': 'Inventory'});
    final bundle = _FakeBundle({
      'assets/erp_modules/module_asset_map.json': mapJson,
      'assets/erp_modules/inventory.json': invJson,
    });
    final loaded = await SchemaService.tryLoadModuleAsset('inv', bundle: bundle);
    expect(loaded, isNotNull);
    expect(loaded, contains('Inventory'));
  });
}
