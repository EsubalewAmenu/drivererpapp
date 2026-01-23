import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drivererpapp/services/schema_service.dart';
import 'package:drivererpapp/services/drive_service.dart';

class MockDriveService extends Mock implements DriveService {}

void main() {
  late MockDriveService mockDrive;
  setUp(() {
    mockDrive = MockDriveService();
    SharedPreferences.setMockInitialValues({});
  });

  test('cacheConfig and getCachedConfig roundtrip', () async {
    final svc = SchemaService(driveService: null, userEmail: null);
    final modId = 'm_round';
    final config = {
      'settings': {'a': {'value': 1}},
      'dashboard': {'cards': []},
      'tabs': []
    };

    await svc.cacheConfig(modId, config, fileId: 'fid', modifiedTime: 't');
    final loaded = await svc.getCachedConfig(modId);
    expect(loaded, isNotNull);
    expect(loaded!['settings'], isA<Map>());
    expect(loaded['dashboard'], isA<Map>());
    expect(loaded['tabs'], isA<List>());
  });

  test('syncConfig returns null without driveService or userEmail', () async {
    final svc = SchemaService(driveService: null, userEmail: null);
    final res = await svc.syncConfig('any');
    expect(res, isNull);
  });

  test('syncConfig uses user-specific file when present', () async {
    // Arrange: mock DriveService to return folder id, file id, modified time and module config
    when(() => mockDrive.getOrCreateSubFolder(any(), any())).thenAnswer((_) async => 'folder1');
    when(() => mockDrive.getFileId('folder1', 'me_settings')).thenAnswer((_) async => 'file123');
    when(() => mockDrive.getFileModifiedTime('file123')).thenAnswer((_) async => DateTime.utc(2020));
    when(() => mockDrive.readModuleConfig('file123')).thenAnswer((_) async => {'settings': {'x': 1}});

    final svc = SchemaService(driveService: mockDrive, userEmail: 'me');
    final res = await svc.syncConfig('m1');

    expect(res, isNotNull);
    expect(res!['settings']['x'], 1);

    // verify caching occurred by reading cached meta
    final meta = await svc.getCachedMeta('m1');
    expect(meta, isNotNull);
    expect(meta!['fileId'], 'file123');
  });

  test('saveSettingsPart writes by id when provided', () async {
    when(() => mockDrive.getFileModifiedTime('sid')).thenAnswer((_) async => DateTime.utc(2021));
    when(() => mockDrive.writeSettingsById('sid', any())).thenAnswer((_) async => {});

    final svc = SchemaService(driveService: mockDrive, userEmail: 'me');
    await svc.saveSettingsPart('m2', {'a': 1}, settingsId: 'sid');

    // Expect cached settings exist
    final cached = await svc.getCachedConfig('m2');
    expect(cached, isNotNull);
    expect((cached!['settings'] as Map)['a'], 1);
  });

  test('saveDashboardPart writes to provided dashboardId', () async {
    when(() => mockDrive.writeDashboardById('did', any())).thenAnswer((_) async => {});
    when(() => mockDrive.getFileModifiedTime('sid')).thenAnswer((_) async => DateTime.utc(2022));

    final svc = SchemaService(driveService: mockDrive, userEmail: 'me');
    await svc.saveDashboardPart('m3', {'cards': []}, dashboardId: 'did', settingsId: 'sid');

    final cached = await svc.getCachedConfig('m3');
    expect(cached, isNotNull);
    expect(cached!['dashboard'], isA<Map>());
  });

  test('saveTabsPart writes to provided tabsId', () async {
    when(() => mockDrive.writeTabsById('tid', any())).thenAnswer((_) async => {});
    when(() => mockDrive.getFileModifiedTime('sid')).thenAnswer((_) async => DateTime.utc(2023));

    final svc = SchemaService(driveService: mockDrive, userEmail: 'me');
    await svc.saveTabsPart('m4', [], tabsId: 'tid', settingsId: 'sid');

    final cached = await svc.getCachedConfig('m4');
    expect(cached, isNotNull);
    expect(cached!['tabs'], isA<List>());
  });
}
