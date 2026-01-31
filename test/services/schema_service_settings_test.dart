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
      when(() => mockDrive.writeSettingsById('s1', any())).thenAnswer((_) async {});
      when(() => mockDrive.getFileModifiedTime('s1')).thenAnswer((_) async => DateTime.utc(2025));

      await svc.saveSettingsPart('mod1', {'a': 1}, settingsId: 's1');

      verify(() => mockDrive.writeSettingsById('s1', any())).called(1);
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('module_config_mod1_settings');
      expect(cached, isNotNull);
      expect(cached!.contains('"a":1'), isTrue);
    });

  });
}
