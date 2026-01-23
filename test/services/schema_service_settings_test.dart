import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drivererpapp/services/schema_service.dart';
import 'package:drivererpapp/services/drive_service.dart';

class MockDriveService extends Mock implements DriveService {}
class MapStringDynamicFake extends Fake implements Map<String, dynamic> {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
    registerFallbackValue(MapStringDynamicFake());
  });

  group('SchemaService.saveSettingsPart', () {
    late MockDriveService mockDrive;
    late SchemaService svc;

    setUp(() {
      mockDrive = MockDriveService();
      svc = SchemaService(driveService: mockDrive, userEmail: 'user@example.com');
      SharedPreferences.setMockInitialValues({});
    });

    test('writes directly when settingsId provided and caches', () async {
      when(() => mockDrive.writeSettingsById('s1', any())).thenAnswer((_) async => null);
      when(() => mockDrive.getFileModifiedTime('s1')).thenAnswer((_) async => DateTime.utc(2025));

      await svc.saveSettingsPart('mod1', {'a': 1}, settingsId: 's1');

      verify(() => mockDrive.writeSettingsById('s1', any())).called(1);
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('module_config_mod1_settings');
      expect(cached, isNotNull);
      expect(cached!.contains('"a":1'), isTrue);
    });

    test('resolves existing settings file and writes', () async {
      when(() => mockDrive.getOrCreateSubFolder('mod2', 'config')).thenAnswer((_) async => 'cfg2');
      when(() => mockDrive.getFileId('cfg2', 'user@example.com_settings')).thenAnswer((_) async => 'resolved2');
      when(() => mockDrive.writeSettingsById('resolved2', any())).thenAnswer((_) async => null);
      when(() => mockDrive.getFileModifiedTime('resolved2')).thenAnswer((_) async => DateTime.utc(2025));

      await svc.saveSettingsPart('mod2', {'b': 2});

      verify(() => mockDrive.writeSettingsById('resolved2', any())).called(1);
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('module_config_mod2_settings');
      expect(cached, isNotNull);
      expect(cached!.contains('"b":2'), isTrue);
    });

    test('creates module config when no existing settings file found', () async {
      when(() => mockDrive.getOrCreateSubFolder('mod3', 'config')).thenAnswer((_) async => 'cfg3');
      when(() => mockDrive.getFileId('cfg3', 'user@example.com_settings')).thenAnswer((_) async => null);
      when(() => mockDrive.createModuleConfig('cfg3', 'user@example.com_settings', any())).thenAnswer((_) async => 'created3');
      when(() => mockDrive.getFileModifiedTime('created3')).thenAnswer((_) async => DateTime.utc(2025));

      await svc.saveSettingsPart('mod3', {'c': 3});

      verify(() => mockDrive.createModuleConfig('cfg3', 'user@example.com_settings', any())).called(1);
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('module_config_mod3_settings');
      expect(cached, isNotNull);
      expect(cached!.contains('"c":3'), isTrue);
    });
  });
}
