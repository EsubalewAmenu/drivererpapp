import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:drivererpapp/providers/drive_provider.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  group('DriveProvider', () {
    test('Initial driveService should be null', () {
      final provider = DriveProvider();
      expect(provider.driveService, isNull);
    });

    test('updateClient with null clears driveService', () {
      final provider = DriveProvider();
      provider.updateClient(MockHttpClient());
      expect(provider.driveService, isNotNull);

      var notified = false;
      provider.addListener(() => notified = true);

      provider.updateClient(null);
      expect(provider.driveService, isNull);
      expect(notified, isTrue);
    });

    test('updateClient with client sets driveService', () {
      final provider = DriveProvider();
      
      var notified = false;
      provider.addListener(() => notified = true);

      provider.updateClient(MockHttpClient());
      expect(provider.driveService, isNotNull);
      expect(notified, isTrue);
    });
  });
}
