import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/models/schema_models.dart';

class MockDriveService extends Mock implements DriveService {}

void main() {
  late MockDriveService mockDriveService;
  late SchemaProvider provider;

  setUp(() {
    mockDriveService = MockDriveService();
    provider = SchemaProvider(driveService: mockDriveService);
  });

  test('Initial state is clean', () {
    expect(provider.getFromMemory('mod1'), isNull);
  });

  test('updateMemoryCache ads and removes items', () {
    final schema = ModuleSchema(
      id: 'mod1',
      name: 'Test Module',
      icon: 'icon',
      primaryColor: 'color',
      version: '1.0',
      settings: {},
      dashboard: DashboardConfig(cards: []),
      tabs: [],
    );

    // Test Add
    bool notified = false;
    provider.addListener(() => notified = true);

    provider.updateMemoryCache('mod1', schema);
    
    expect(provider.getFromMemory('mod1'), equals(schema));
    expect(notified, isTrue);

    // Test Remove
    notified = false;
    provider.updateMemoryCache('mod1', null);
    
    expect(provider.getFromMemory('mod1'), isNull);
    expect(notified, isTrue);
  });

  test('notifyUpdate notifies listeners', () {
    bool notified = false;
    provider.addListener(() => notified = true);

    provider.notifyUpdate();

    expect(notified, isTrue);
  });
}
