import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/services/schema_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('cacheConfig and getCachedConfig roundtrip', () async {
    final svc = SchemaService();
    const moduleId = 'm1';
    final config = {
      'settings': {'a': 1},
      'dashboard': {'cards': []},
      'tabs': [{'id': 't1', 'label': 'T1'}]
    };

    await svc.cacheConfig(moduleId, config, fileId: 'fid', modifiedTime: 'mt');

    final got = await svc.getCachedConfig(moduleId);
    expect(got, isNotNull);
    expect(got!['settings'], isNotNull);
    expect((got['tabs'] as List).first['id'], 't1');

    final meta = await svc.getCachedMeta(moduleId);
    expect(meta, isNotNull);
    expect(meta!['fileId'], 'fid');

    await svc.removeCachedConfig(moduleId);
    final removed = await svc.getCachedConfig(moduleId);
    expect(removed, isNull);
  });
}
