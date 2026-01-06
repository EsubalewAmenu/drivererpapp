import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;

void main() {
  group('WorkspaceProvider Tests', () {
    test('Initial state should be null', () {
      final provider = WorkspaceProvider();
      expect(provider.currentWorkspace, isNull);
      expect(provider.hasWorkspace, isFalse);
    });

    test('setWorkspace should update state and notify listeners', () {
      final provider = WorkspaceProvider();
      final mockFile = drive.File()..name = 'Test Workspace'..id = '123';
      
      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      provider.setWorkspace(mockFile);

      expect(provider.currentWorkspace, equals(mockFile));
      expect(provider.currentWorkspace?.name, 'Test Workspace');
      expect(provider.hasWorkspace, isTrue);
      expect(notified, isTrue);
    });

    test('clearWorkspace should reset state and notify listeners', () {
      final provider = WorkspaceProvider();
      final mockFile = drive.File()..name = 'Test Workspace'..id = '123';
      provider.setWorkspace(mockFile);
      
      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      provider.clearWorkspace();

      expect(provider.currentWorkspace, isNull);
      expect(provider.hasWorkspace, isFalse);
      expect(notified, isTrue);
    });
  });
}
