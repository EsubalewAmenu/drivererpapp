import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:drivererpapp/providers/sync_provider.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';

class MockDriveProvider extends Mock implements DriveProvider {}
class MockDriveService extends Mock implements DriveService {}

void main() {
  late SyncProvider syncProvider;
  late MockDriveProvider mockDriveProvider;
  late MockDriveService mockDriveService;

  setUp(() {
    syncProvider = SyncProvider();
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();

    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    syncProvider.updateDriveProvider(mockDriveProvider);
  });

  tearDown(() {
    syncProvider.dispose();
  });

  test('Initial state is empty', () {
    expect(syncProvider.queue, isEmpty);
    expect(syncProvider.isSyncing, isFalse);
    expect(syncProvider.pendingCount, 0);
  });

  test('addToQueue adds item and triggers sync', () async {
    when(() => mockDriveService.saveRecord(any(), any(), any(), any()))
        .thenAnswer((_) async {});

    syncProvider.addToQueue('mod1', 'ModuleName', 'tab1', {'key': 'value'});

    expect(syncProvider.queue.length, 1);
    expect(syncProvider.pendingCount, 1);
    
    // Process queue
    await Future.delayed(Duration.zero); 
    
    verify(() => mockDriveService.saveRecord(
      'mod1', 
      'ModuleName', 
      'tab1', 
      {'key': 'value'}
    )).called(1);
    
    // Should be removed after successful sync
    expect(syncProvider.queue, isEmpty);
  });

  test('Retry on failure', () async {
    when(() => mockDriveService.saveRecord(any(), any(), any(), any()))
        .thenThrow(Exception('Sync failed'));

    syncProvider.addToQueue('mod1', 'ModuleName', 'tab1', {'key': 'value'});
    
    // Process queue
    await Future.delayed(Duration.zero);

    verify(() => mockDriveService.saveRecord(any(), any(), any(), any())).called(1);
    
    // Should stay in queue
    expect(syncProvider.queue.length, 1);
    expect(syncProvider.queue.first.retryCount, 1);
  });
}
